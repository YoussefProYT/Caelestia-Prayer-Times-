pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

Item {
    id: root

    function t(arabic: string, english: string): string {
        return PrayerService.uiLanguage === "en" ? english : arabic;
    }

    property bool settingsOpen: false
    property bool iqamaSettingsOpen: false
    readonly property list<MenuItem> madhabOptions: [
        MenuItem { text: PrayerService.uiLanguage === "en" ? "Shafi'i, Maliki and Hanbali (standard)" : "الشافعي والمالكي والحنبلي (قياسي)" },
        MenuItem { text: PrayerService.uiLanguage === "en" ? "Hanafi" : "الحنفي" }
    ]
    readonly property list<MenuItem> languageOptions: [
        MenuItem { text: "العربية" },
        MenuItem { text: "English" }
    ]
    readonly property list<MenuItem> timeFormatOptions: [
        MenuItem { text: root.t("اتّباع إعدادات الشِل", "Follow shell") },
        MenuItem { text: root.t("24 ساعة", "24-hour") },
        MenuItem { text: root.t("12 ساعة", "12-hour") }
    ]
    readonly property var iqamaPrayerOptions: [
        { key: "Fajr", label: root.t("الفجر", "Fajr") },
        { key: "Dhuhr", label: root.t("الظهر", "Dhuhr") },
        { key: "Asr", label: root.t("العصر", "Asr") },
        { key: "Maghrib", label: root.t("المغرب", "Maghrib") },
        { key: "Isha", label: root.t("العشاء", "Isha") }
    ]

    implicitWidth: 840
    implicitHeight: content.implicitHeight

    Component.onCompleted: {
        locationField.text = PrayerService.configuredLocation;
        PrayerService.reload();
    }

    Connections {
        target: PrayerService

        function onConfiguredLocationChanged(): void {
            locationField.text = PrayerService.configuredLocation;
        }
    }

    ColumnLayout {
        id: content

        width: parent.width
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large

            ColumnLayout {
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    text: root.t("مواقيت الصلاة", "Prayer times")
                    font: Tokens.font.body.builders.large.size(28).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: PrayerService.locationLabel || root.t("جارٍ تحديد الموقع...", "Finding location...")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: new Date().toLocaleDateString(PrayerService.uiLanguage === "en" ? Qt.locale("en_US") : Qt.locale("ar_EG"), "dddd, MMMM d")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    visible: PrayerService.hijriDate.length > 0
                    text: PrayerService.hijriDate ? root.t("هجري %1", "Hijri %1").arg(PrayerService.hijriDate) : ""
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }
            }

            IconButton {
                icon: root.settingsOpen ? "close" : "settings"
                type: IconButton.Tonal
                padding: Tokens.padding.small
                onClicked: root.settingsOpen = !root.settingsOpen
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            visible: root.settingsOpen
            spacing: Tokens.spacing.extraSmall

            SectionHeader {
                text: root.t("إعدادات الصلاة", "Prayer settings")
            }

            StyledTextField {
                id: locationField

                Layout.fillWidth: true
                placeholderText: root.t("المدينة، الدولة، أو خط العرض,خط الطول", "City, country, or latitude,longitude")
                leadingIcon: "location_on"
                supportingText: root.t("اتركه فارغًا للموقع التلقائي. البحث عن المدينة يحتاج الإنترنت؛ الإحداثيات تعمل دون اتصال.", "Leave empty for automatic location. City search needs internet; coordinates work offline.")
                onEditingFinished: PrayerService.setLocation(text)
            }

            SelectRow {
                first: true
                label: root.t("تنسيق الوقت", "Time format")
                subtext: root.t("اختر طريقة عرض مواقيت الصلاة", "Choose how prayer times are displayed")
                menuItems: root.timeFormatOptions
                active: root.timeFormatOptions[
                    PrayerService.timeFormat === "12h" ? 2 : PrayerService.timeFormat === "24h" ? 1 : 0
                ]
                onSelected: item => {
                    const index = root.timeFormatOptions.indexOf(item);
                    PrayerService.setTimeFormat(index === 2 ? "12h" : index === 1 ? "24h" : "system");
                }
            }

            SelectRow {
                label: root.t("المذهب", "Madhab")
                subtext: root.t("الشافعي والمالكي والحنبلي (قياسي) أو الحنفي", "Shafi'i, Maliki and Hanbali (standard), or Hanafi")
                menuItems: root.madhabOptions
                active: root.madhabOptions[PrayerService.madhab === "hanafi" ? 1 : 0]
                onSelected: item => PrayerService.setMadhab(root.madhabOptions.indexOf(item) === 1 ? "hanafi" : "standard")
            }

            SelectRow {
                label: root.t("لغة الإضافة", "Addon language")
                subtext: root.t("العربية أو الإنجليزية", "Arabic or English")
                menuItems: root.languageOptions
                active: root.languageOptions[PrayerService.uiLanguage === "en" ? 1 : 0]
                onSelected: item => PrayerService.setLanguage(root.languageOptions.indexOf(item) === 1 ? "en" : "ar")
            }

            RowLayout {
                Layout.fillWidth: true
                SectionHeader {
                    Layout.fillWidth: true
                    text: root.t("تأخير الإقامة بعد الأذان", "Iqama delay after adhan")
                }
                IconButton {
                    icon: root.iqamaSettingsOpen ? "expand_less" : "timer"
                    type: IconButton.Tonal
                    padding: Tokens.padding.small
                    onClicked: root.iqamaSettingsOpen = !root.iqamaSettingsOpen
                }
            }

            ColumnLayout {
                visible: root.iqamaSettingsOpen
                Layout.fillWidth: true

                Repeater {
                    model: root.iqamaPrayerOptions

                    delegate: StepperRow {
                    required property var modelData
                    required property int index

                    first: index === 0
                    last: index === root.iqamaPrayerOptions.length - 1
                    label: modelData.label
                    subtext: root.t("دقائق بعد الأذان", "Minutes after adhan")
                    value: Number(PrayerService.iqamaDelays[modelData.key] ?? (modelData.key === "Maghrib" ? 5 : 15))
                    from: 0
                    to: 60
                    stepSize: 5
                        onMoved: value => PrayerService.setIqamaDelay(modelData.key, value)
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.large
            Layout.rightMargin: Tokens.padding.large
            visible: PrayerService.nextPrayerName.length > 0
            implicitHeight: 92
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHigh

            Item {
                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium

                MaterialIcon {
                    id: countdownIcon

                    text: "schedule"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3primary
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                ColumnLayout {
                    anchors.left: countdownIcon.right
                    anchors.leftMargin: Tokens.spacing.medium
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        text: root.t("الصلاة القادمة", "Next prayer")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        text: PrayerService.nextPrayerName
                        font: Tokens.font.body.builders.large.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
                    }
                }

                ColumnLayout {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: PrayerService.nextPrayerEventType === "iqama"
                            ? root.t("الوقت المتبقي للإقامة", "Time until iqama")
                            : root.t("الوقت المتبقي للأذان", "Time until adhan")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: PrayerService.nextPrayerCountdown
                        font: Tokens.font.body.builders.large.size(24).weight(Font.Bold).build()
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignRight
                        text: PrayerService.nextPrayerEventType === "iqama"
                            ? root.t("الإقامة %1%2", "Iqama %1%2").arg(PrayerService.nextPrayerIqamaTime).arg(PrayerService.nextPrayerIsTomorrow ? root.t(" · غدًا", " · tomorrow") : "")
                            : root.t("الأذان %1 · الإقامة %2%3", "Adhan %1 · Iqama %2%3").arg(PrayerService.nextPrayerAdhanTime).arg(PrayerService.nextPrayerIqamaTime).arg(PrayerService.nextPrayerIsTomorrow ? root.t(" · غدًا", " · tomorrow") : "")
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: PrayerService.timings !== null
            implicitHeight: prayerGrid.implicitHeight + Tokens.padding.medium * 2
            radius: Tokens.rounding.extraLarge
            color: Colours.tPalette.m3surfaceContainer

            GridLayout {
                id: prayerGrid

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                columns: 3
                rowSpacing: Tokens.spacing.medium
                columnSpacing: Tokens.spacing.medium

                Repeater {
                    model: PrayerService.prayerRows

                    delegate: StyledRect {
                        id: prayerCard

                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: Tokens.rounding.large
                        color: Colours.palette.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.rightMargin: Tokens.padding.medium
                            spacing: Tokens.spacing.medium

                            MaterialIcon {
                                text: prayerCard.modelData.icon
                                fontStyle: Tokens.font.icon.large
                                color: Colours.palette.m3primary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall

                                StyledText {
                                    text: prayerCard.modelData.label
                                    font: Tokens.font.body.medium
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    readonly property string rawTime: String(PrayerService.timings?.[prayerCard.modelData.key] ?? "--:--")
                                    text: rawTime.split(" ")[0]
                                    font: Tokens.font.body.builders.large.weight(Font.DemiBold).build()
                                    color: Colours.palette.m3onSurface
                                }
                            }
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            visible: PrayerService.loading || PrayerService.error.length > 0
            implicitHeight: statusText.implicitHeight + Tokens.padding.large
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            StyledText {
                id: statusText

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.large * 2
                text: PrayerService.error || root.t("جارٍ تحميل مواقيت الصلاة...", "Loading prayer times...")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
