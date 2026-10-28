pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.utils
import qs.services
import "Adhan.js" as AdhanLib

Singleton {
    id: root

    property var timings: null
    property string locationLabel: ""
    property string hijriDate: ""
    property string error: ""
    property bool loading: false
    property bool settingsLoaded: false
    property string configuredLocation: ""
    property string resolvedCityQuery: ""
    property var resolvedCityCoordinates: null
    property string resolvedCityLabel: ""
    property int calculationMethod: 5
    property int asrSchool: 0
    property string timeFormat: "system"
    property var iqamaDelays: ({ Fajr: 15, Dhuhr: 15, Asr: 15, Maghrib: 5, Isha: 15 })
    property int requestSerial: 0
    property var rawPrayerTimes: null
    property var todayPrayerSchedule: []
    property var tomorrowPrayerSchedule: []
    property string nextPrayerName: ""
    property string nextPrayerTime: ""
    property string nextPrayerCountdown: ""
    property string nextPrayerEventType: "adhan"
    property string nextPrayerAdhanTime: ""
    property string nextPrayerIqamaTime: ""
    property bool nextPrayerIsTomorrow: false

    readonly property var prayerRows: [
        { key: "Fajr", label: "الفجر", icon: "dark_mode" },
        { key: "Sunrise", label: "الشروق", icon: "wb_twilight" },
        { key: "Dhuhr", label: "الظهر", icon: "light_mode" },
        { key: "Asr", label: "العصر", icon: "wb_sunny" },
        { key: "Maghrib", label: "المغرب", icon: "wb_twilight" },
        { key: "Isha", label: "العشاء", icon: "nights_stay" }
    ]

    function parseCoordinates(value: string): var {
        const parts = value.split(",");
        if (parts.length !== 2)
            return null;

        const latitude = Number(parts[0].trim());
        const longitude = Number(parts[1].trim());
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180)
            return null;

        return { latitude, longitude };
    }

    function fail(message: string): void {
        loading = false;
        error = message;
        timings = null;
        rawPrayerTimes = null;
        todayPrayerSchedule = [];
        tomorrowPrayerSchedule = [];
        nextPrayerName = "";
        nextPrayerTime = "";
        nextPrayerCountdown = "";
        nextPrayerAdhanTime = "";
        nextPrayerIqamaTime = "";
        nextPrayerIsTomorrow = false;
    }

    function loadSettings(value: string): void {
        let settings = {};
        try {
            settings = JSON.parse(value || "{}") || {};
        } catch (parseError) {
            console.warn(lc, `Unable to parse prayer-times.json: ${parseError}`);
        }

        const previousLocation = configuredLocation;
        const previousMethod = calculationMethod;
        const previousAsrSchool = asrSchool;
        const previousTimeFormat = timeFormat;
        const wasLoaded = settingsLoaded;
        configuredLocation = String(settings.location ?? "").trim();
        const savedResolved = settings.resolvedLocation;
        const savedCoordinates = savedResolved && String(savedResolved.query ?? "") === configuredLocation
            ? parseCoordinates(`${savedResolved.latitude},${savedResolved.longitude}`)
            : null;
        resolvedCityQuery = savedCoordinates ? configuredLocation : "";
        resolvedCityCoordinates = savedCoordinates;
        resolvedCityLabel = savedCoordinates ? String(savedResolved.label ?? configuredLocation) : "";
        const method = Number(settings.calculationMethod);
        calculationMethod = Number.isInteger(method) && method >= 0 && method <= 23 ? method : 5;
        asrSchool = Number(settings.asrSchool) === 1 ? 1 : 0;
        timeFormat = ["system", "12h", "24h"].includes(settings.timeFormat) ? settings.timeFormat : "system";
        const savedDelays = settings.iqamaDelays && typeof settings.iqamaDelays === "object" ? settings.iqamaDelays : {};
        const defaults = { Fajr: 15, Dhuhr: 15, Asr: 15, Maghrib: 5, Isha: 15 };
        const delays = {};
        for (const key of Object.keys(defaults)) {
            const value = Number(savedDelays[key]);
            delays[key] = Number.isFinite(value) ? Math.max(0, Math.min(60, Math.round(value / 5) * 5)) : defaults[key];
        }
        iqamaDelays = delays;
        settingsLoaded = true;
        if (!wasLoaded || previousLocation !== configuredLocation || previousMethod !== calculationMethod || previousAsrSchool !== asrSchool) {
            reload();
        } else {
            if (previousTimeFormat !== timeFormat)
                updateFormattedPrayerTimes();
            updateNextPrayer();
        }
    }

    function saveSettings(): void {
        const settings = {
            location: configuredLocation,
            calculationMethod: calculationMethod,
            asrSchool: asrSchool,
            timeFormat: timeFormat,
            iqamaDelays: iqamaDelays,
            resolvedLocation: resolvedCityQuery === configuredLocation && resolvedCityCoordinates
                ? {
                    query: resolvedCityQuery,
                    latitude: resolvedCityCoordinates.latitude,
                    longitude: resolvedCityCoordinates.longitude,
                    label: resolvedCityLabel
                }
                : null
        };
        preferencesFile.setText(JSON.stringify(settings, null, 2) + "\n");
    }

    function setTimeFormat(format: string): void {
        if (!["system", "12h", "24h"].includes(format) || timeFormat === format)
            return;
        timeFormat = format;
        saveSettings();
        updateFormattedPrayerTimes();
        updateNextPrayer();
    }

    function setIqamaDelay(key: string, minutes: real): void {
        if (!["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"].includes(key))
            return;
        const delay = Math.max(0, Math.min(60, Math.round(Number(minutes) / 5) * 5));
        if (iqamaDelays[key] === delay)
            return;
        const updated = Object.assign({}, iqamaDelays);
        updated[key] = delay;
        iqamaDelays = updated;
        saveSettings();
        updateNextPrayer();
    }

    function setLocation(value: string): void {
        const location = String(value).trim();
        if (configuredLocation === location)
            return;
        configuredLocation = location;
        resolvedCityQuery = "";
        resolvedCityCoordinates = null;
        resolvedCityLabel = "";
        saveSettings();
        reload();
    }

    function reload(): void {
        if (!settingsLoaded)
            return;

        const serial = ++requestSerial;
        loading = true;
        error = "";

        const configuredLocation = root.configuredLocation;
        if (configuredLocation) {
            const coordinates = parseCoordinates(configuredLocation);
            if (coordinates) {
                locationWait.stop();
                requestTimings(coordinates, configuredLocation, serial);
            } else if (resolvedCityQuery === configuredLocation && resolvedCityCoordinates) {
                locationWait.stop();
                requestTimings(resolvedCityCoordinates, resolvedCityLabel || configuredLocation, serial);
            } else {
                lookupCity(configuredLocation, serial);
            }
            return;
        }

        if (!Weather.loc) {
            locationLabel = "";
            error = qsTr("Waiting for automatic location. Enter a city or coordinates in Prayer settings to set it manually.");
            Weather.reload();
            locationWait.restart();
            return;
        }

        const coordinates = parseCoordinates(Weather.loc);
        if (!coordinates) {
            fail(qsTr("Unable to determine coordinates. Enter a city or coordinates in Prayer settings."));
            return;
        }

        locationWait.stop();
        requestTimings(coordinates, Weather.city || Weather.loc, serial);
    }

    function lookupCity(city: string, serial: int): void {
        // City names need one network lookup to resolve them to coordinates.
        // Enter latitude,longitude to calculate prayer times with no network access.
        const lang = /[\u0600-\u06FF\u0750-\u077F]/.test(city)
            ? "ar"
            : (Qt.locale().name.split("_")[0] || "en");
        const searchCity = city.replace(/،/g, ",").trim();
        const url = `https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(searchCity)}&count=1&language=${lang}&format=json`;

        Requests.get(url, text => {
            if (serial !== requestSerial)
                return;

            let response;
            try {
                response = JSON.parse(text);
            } catch (parseError) {
                fail(qsTr("Could not read the city search response."));
                return;
            }

            const result = response?.results?.[0];
            if (!result || !Number.isFinite(Number(result.latitude)) || !Number.isFinite(Number(result.longitude))) {
                fail(qsTr("City not found. Enter a city name or latitude,longitude."));
                return;
            }

            const label = [result.name, result.country].filter(Boolean).join(", ");
            root.resolvedCityQuery = city;
            root.resolvedCityCoordinates = { latitude: Number(result.latitude), longitude: Number(result.longitude) };
            root.resolvedCityLabel = label || city;
            root.saveSettings();
            requestTimings(root.resolvedCityCoordinates, root.resolvedCityLabel, serial);
        }, errorText => {
            if (serial === requestSerial)
                fail(qsTr("City lookup needs an internet connection. Enter latitude,longitude for offline calculation."));
            console.warn(lc, `City lookup failed: ${errorText}`);
        });
    }

    function parametersForMethod(methodId: int): var {
        const library = AdhanLib.Adhan;
        switch (methodId) {
        case 0: // Shia Ithna-Ashari / Jafari
            return new library.CalculationParameters("Other", 16, 14, 0, 4);
        case 1: // Karachi
            return library.CalculationMethod.Karachi();
        case 2: // ISNA
            return library.CalculationMethod.NorthAmerica();
        case 3: // Muslim World League
            return library.CalculationMethod.MuslimWorldLeague();
        case 4: // Umm al-Qura
            return library.CalculationMethod.UmmAlQura();
        case 5: // Egyptian General Authority of Survey
            return library.CalculationMethod.Egyptian();
        case 7: // Tehran
            return library.CalculationMethod.Tehran();
        case 8: // Gulf Region
            return new library.CalculationParameters("Other", 18.2, 18.2);
        case 9:
            return library.CalculationMethod.Kuwait();
        case 10:
            return library.CalculationMethod.Qatar();
        case 11:
            return library.CalculationMethod.Singapore();
        case 12: // France
            return new library.CalculationParameters("Other", 12, 12);
        case 13: // Turkey / Diyanet
            return library.CalculationMethod.Turkey();
        case 14: // Russia
            return new library.CalculationParameters("Other", 16, 15);
        case 15: // Moonsighting Committee
            return library.CalculationMethod.MoonsightingCommittee();
        case 16: // Dubai
            return library.CalculationMethod.Dubai();
        case 17: // Malaysia / JAKIM
            return new library.CalculationParameters("Other", 20, 18);
        case 18: // Tunisia
            return new library.CalculationParameters("Other", 18, 18);
        case 19: // Algeria
            return new library.CalculationParameters("Other", 18, 17);
        case 20: // Indonesia / Kemenag
            return new library.CalculationParameters("Other", 20, 18);
        case 21: // Morocco
            return new library.CalculationParameters("Other", 19, 17);
        case 22: { // Portugal
            const portugal = new library.CalculationParameters("Other", 18, 0, 77);
            portugal.methodAdjustments.maghrib = 3;
            return portugal;
        }
        case 23: // Jordan
            return new library.CalculationParameters("Other", 18, 18);
        default:
            // Keep the documented default aligned with the Egyptian method.
            return library.CalculationMethod.Egyptian();
        }
    }

    function formatLocalTime(date: var): string {
        const twelveHour = root.timeFormat === "12h"
            || (root.timeFormat === "system" && GlobalConfig.services.useTwelveHourClock);
        return Qt.formatDateTime(date, twelveHour ? "h:mm AP" : "HH:mm");
    }

    function updateFormattedPrayerTimes(): void {
        if (!rawPrayerTimes)
            return;
        timings = {
            Fajr: formatLocalTime(rawPrayerTimes.Fajr),
            Sunrise: formatLocalTime(rawPrayerTimes.Sunrise),
            Dhuhr: formatLocalTime(rawPrayerTimes.Dhuhr),
            Asr: formatLocalTime(rawPrayerTimes.Asr),
            Maghrib: formatLocalTime(rawPrayerTimes.Maghrib),
            Isha: formatLocalTime(rawPrayerTimes.Isha)
        };
    }

    function prayerScheduleFor(calculated: var): var {
        return [
            { key: "Fajr", name: qsTr("الفجر"), at: calculated.fajr },
            { key: "Dhuhr", name: qsTr("الظهر"), at: calculated.dhuhr },
            { key: "Asr", name: qsTr("العصر"), at: calculated.asr },
            { key: "Maghrib", name: qsTr("المغرب"), at: calculated.maghrib },
            { key: "Isha", name: qsTr("العشاء"), at: calculated.isha }
        ];
    }

    function updateNextPrayer(): void {
        if (!todayPrayerSchedule.length || !tomorrowPrayerSchedule.length)
            return;

        const now = new Date();
        const schedule = todayPrayerSchedule.concat(tomorrowPrayerSchedule);
        let upcoming = null;
        for (let index = 0; index < schedule.length; index++) {
            const prayer = schedule[index];
            const nextPrayer = schedule[index + 1];
            const delay = Number(iqamaDelays[prayer.key] ?? 15);
            const iqamaAt = new Date(prayer.at.getTime() + delay * 60000);

            if (prayer.at.getTime() > now.getTime()) {
                upcoming = { prayer, type: "adhan", at: prayer.at, iqamaAt };
                break;
            }

            // Do not keep counting toward an iqama after the next adhan has arrived.
            if (delay > 0 && iqamaAt.getTime() > now.getTime()
                    && (!nextPrayer || iqamaAt.getTime() < nextPrayer.at.getTime())) {
                upcoming = { prayer, type: "iqama", at: iqamaAt, iqamaAt };
                break;
            }
        }

        if (!upcoming) {
            nextPrayerName = "";
            nextPrayerTime = "";
            nextPrayerCountdown = "";
            nextPrayerAdhanTime = "";
            nextPrayerIqamaTime = "";
            return;
        }

        nextPrayerName = upcoming.prayer.name;
        nextPrayerEventType = upcoming.type;
        nextPrayerTime = formatLocalTime(upcoming.at);
        nextPrayerAdhanTime = formatLocalTime(upcoming.prayer.at);
        nextPrayerIqamaTime = formatLocalTime(upcoming.iqamaAt);
        nextPrayerIsTomorrow = upcoming.prayer.at.getFullYear() !== now.getFullYear()
            || upcoming.prayer.at.getMonth() !== now.getMonth()
            || upcoming.prayer.at.getDate() !== now.getDate();

        const secondsLeft = Math.max(0, Math.floor((upcoming.at.getTime() - now.getTime()) / 1000));
        const hours = Math.floor(secondsLeft / 3600);
        const minutes = Math.floor((secondsLeft % 3600) / 60);
        const seconds = secondsLeft % 60;
        nextPrayerCountdown = [hours, minutes, seconds].map(value => String(value).padStart(2, "0")).join(":");
    }

    function requestTimings(coordinates: var, label: string, serial: int): void {
        if (serial !== requestSerial)
            return;

        try {
            const library = AdhanLib.Adhan;
            const methodId = Number(root.calculationMethod);
            const parameters = parametersForMethod(Number.isInteger(methodId) ? methodId : 5);
            parameters.madhab = root.asrSchool === 1 ? library.Madhab.Hanafi : library.Madhab.Shafi;
            parameters.polarCircleResolution = library.PolarCircleResolution.AqrabBalad;

            // Adhan calculates locally from coordinates and the machine's local date/timezone.
            const date = new Date();
            const calculated = new library.PrayerTimes(
                new library.Coordinates(coordinates.latitude, coordinates.longitude),
                date,
                parameters
            );
            const tomorrowDate = new Date(date);
            tomorrowDate.setDate(tomorrowDate.getDate() + 1);
            const calculatedTomorrow = new library.PrayerTimes(
                new library.Coordinates(coordinates.latitude, coordinates.longitude),
                tomorrowDate,
                parameters
            );
            rawPrayerTimes = {
                Fajr: calculated.fajr,
                Sunrise: calculated.sunrise,
                Dhuhr: calculated.dhuhr,
                Asr: calculated.asr,
                Maghrib: calculated.maghrib,
                Isha: calculated.isha
            };

            if (Object.values(rawPrayerTimes).some(value => !value || isNaN(value.getTime()))) {
                fail(qsTr("The local calculator could not resolve times for these coordinates."));
                return;
            }

            updateFormattedPrayerTimes();
            todayPrayerSchedule = prayerScheduleFor(calculated);
            tomorrowPrayerSchedule = prayerScheduleFor(calculatedTomorrow);
            hijriDate = ""; // No online Hijri-date service is used by the local calculator.
            locationLabel = label;
            error = "";
            loading = false;
            updateNextPrayer();
        } catch (calculationError) {
            console.warn(lc, `Local prayer calculation failed: ${calculationError}`);
            fail(qsTr("Local calculation failed. Check the coordinates and calculation method."));
        }
    }

    Connections {
        target: Weather

        function onLocChanged(): void {
            if (!root.configuredLocation)
                root.reload();
        }

        function onCityChanged(): void {
            if (!root.configuredLocation && root.timings)
                root.locationLabel = Weather.city;
        }
    }

    Connections {
        target: GlobalConfig.services

        function onUseTwelveHourClockChanged(): void {
            if (root.timeFormat === "system")
                root.updateFormattedPrayerTimes();
        }
    }

    Timer {
        interval: 3600000
        running: true
        repeat: true
        onTriggered: root.reload()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.updateNextPrayer()
    }

    Timer {
        id: locationWait

        interval: 60000
        repeat: false
        onTriggered: {
            if (!Weather.loc && !root.configuredLocation)
                root.fail(qsTr("Automatic location is unavailable. Enter a city or coordinates in Prayer settings."));
        }
    }

    FileView {
        id: preferencesFile

        path: `${Paths.config}/prayer-times.json`
        watchChanges: true
        printErrors: false
        onFileChanged: preferencesFile.reload()
        onLoaded: root.loadSettings(text())
        onLoadFailed: error => {
            root.loadSettings("{}");
            if (error !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load prayer-times.json: ${error}`);
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.prayer-times"
        defaultLogLevel: LoggingCategory.Info
    }
}
