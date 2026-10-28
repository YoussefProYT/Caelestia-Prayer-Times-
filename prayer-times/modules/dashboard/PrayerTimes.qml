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

    property bool settingsOpen: false
    readonly property list<MenuItem> timeFormatOptions: [
        MenuItem { text: qsTr("Follow shell") },
        MenuItem { text: qsTr("24-hour") },
        MenuItem { text: qsTr("12-hour") }
    ]
    readonly property var iqamaPrayerOptions: [
        { key: "Fajr", label: qsTr("الفجر") },
        { key: "Dhuhr", label: qsTr("الظهر") },
        { key: "Asr", label: qsTr("العصر") },
        { key: "Maghrib", label: qsTr("المغرب") },
        { key: "Isha", label: qsTr("العشاء") }
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
                    text: qsTr("Prayer times")
                    font: Tokens.font.body.builders.large.size(28).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: PrayerService.locationLabel || qsTr("Finding location...")
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
                    text: new Date().toLocaleDateString(Qt.locale(), "dddd, MMMM d")
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    visible: PrayerService.hijriDate.length > 0
                    text: PrayerService.hijriDate ? qsTr("Hijri %1").arg(PrayerService.hijriDate) : ""
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
                text: qsTr("Prayer settings")
            }

            StyledTextField {
                id: locationField

                Layout.fillWidth: true
                placeholderText: qsTr("City, country, or latitude,longitude")
                leadingIcon: "location_on"
                supportingText: qsTr("Leave empty for automatic location. City search needs internet; coordinates work offline.")
                onEditingFinished: PrayerService.setLocation(text)
            }

            SelectRow {
                first: true
                label: qsTr("Time format")
                subtext: qsTr("Choose how prayer times are displayed")
                menuItems: root.timeFormatOptions
                active: root.timeFormatOptions[
                    PrayerService.timeFormat === "12h" ? 2 : PrayerService.timeFormat === "24h" ? 1 : 0
                ]
                onSelected: item => {
                    const index = root.timeFormatOptions.indexOf(item);
                    PrayerService.setTimeFormat(index === 2 ? "12h" : index === 1 ? "24h" : "system");
                }
            }

            SectionHeader {
                text: qsTr("Iqama delay after adhan")
            }

            Repeater {
                model: root.iqamaPrayerOptions

                delegate: StepperRow {
                    required property var modelData
                    required property int index

                    first: index === 0
                    last: index === root.iqamaPrayerOptions.length - 1
                    label: modelData.label
                    subtext: qsTr("Minutes after adhan")
                    value: Number(PrayerService.iqamaDelays[modelData.key] ?? (modelData.key === "Maghrib" ? 5 : 15))
                    from: 0
                    to: 60
                    stepSize: 5
                    onMoved: value => PrayerService.setIqamaDelay(modelData.key, value)
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
                        text: qsTr("الصلاة القادمة")
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
                            ? qsTr("الوقت المتبقي للإقامة")
                            : qsTr("الوقت المتبقي للأذان")
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
                            ? qsTr("الإقامة %1%2").arg(PrayerService.nextPrayerIqamaTime).arg(PrayerService.nextPrayerIsTomorrow ? qsTr(" · غدًا") : "")
                            : qsTr("الأذان %1 · الإقامة %2%3").arg(PrayerService.nextPrayerAdhanTime).arg(PrayerService.nextPrayerIqamaTime).arg(PrayerService.nextPrayerIsTomorrow ? qsTr(" · غدًا") : "")
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
                text: PrayerService.error || qsTr("Loading prayer times...")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
}
