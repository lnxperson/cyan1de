import QtQuick
import QtQuick.Layouts
import Quickshell

// Notification daemon settings. Written to settings.json and picked up live by
// the notifications config through its Theme singleton.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Notifications"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Popup behaviour and appearance. Changes are saved automatically."
    }

    SectionCard {
        Layout.fillWidth: true
        title: "BEHAVIOUR"

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Position"
            }

            OptionCombo {
                options: ["top-left", "top-right", "bottom-left", "bottom-right"]
                selected: root.app.notifyPosition
                onPicked: value => { root.app.notifyPosition = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Display time"
            from: 1000
            to: 15000
            stepSize: 500
            value: root.app.notifyTimeout
            suffix: "ms"
            onMoved: value => { root.app.notifyTimeout = Math.round(value); root.app.queueSave() }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Max popups"
            from: 1
            to: 8
            stepSize: 1
            value: root.app.notifyMaxVisible
            onMoved: value => { root.app.notifyMaxVisible = Math.round(value); root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Pause on hover"
            hint: "Keep a popup visible while the pointer is over it"
            checked: root.app.notifyPauseOnHover
            onToggled: value => { root.app.notifyPauseOnHover = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Persistent popups"
            hint: "Never auto-expire — dismiss manually"
            checked: root.app.notifyPersistent
            onToggled: value => { root.app.notifyPersistent = value; root.app.queueSave() }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "LOW BATTERY"

        ToggleRow {
            Layout.fillWidth: true
            label: "Low battery warning"
            hint: "Notify once per discharge cycle on laptops"
            checked: root.app.lowBatteryEnabled
            onToggled: value => { root.app.lowBatteryEnabled = value; root.app.queueSave() }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Warn at"
            from: 5
            to: 50
            stepSize: 1
            suffix: "%"
            value: root.app.lowBatteryThreshold
            onMoved: value => { root.app.lowBatteryThreshold = Math.round(value); root.app.queueSave() }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "CALENDAR"
        subtitle: "What appears inside the calendar pop-up and where it goes."

        ToggleRow {
            Layout.fillWidth: true
            label: "Notification history"
            hint: "Show recent notifications beside the calendar"
            checked: root.app.calendarNotifications
            onToggled: value => { root.app.calendarNotifications = value; root.app.queueSave() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Notifications"
            }

            OptionCombo {
                options: ["right", "left"]
                labels: ({ "right": "Right", "left": "Left" })
                selected: root.app.calendarNotificationsSide
                onPicked: value => { root.app.calendarNotificationsSide = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Media controls"
            hint: "Show media player controls"
            checked: root.app.calendarMedia
            onToggled: value => { root.app.calendarMedia = value; root.app.queueSave() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Media position"
            }

            OptionCombo {
                options: ["bottom", "top"]
                labels: ({ "bottom": "Bottom", "top": "Top" })
                selected: root.app.calendarMediaPosition
                onPicked: value => { root.app.calendarMediaPosition = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Popup width"
            from: 380
            to: 1100
            stepSize: 10
            value: root.app.calendarWidth
            suffix: "px"
            onMoved: value => { root.app.calendarWidth = Math.round(value); root.app.queueSave() }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "APPEARANCE"

        ToggleRow {
            Layout.fillWidth: true
            label: "Show app icon"
            checked: root.app.notifyShowAppIcon
            onToggled: value => { root.app.notifyShowAppIcon = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Show app name"
            checked: root.app.notifyShowAppName
            onToggled: value => { root.app.notifyShowAppName = value; root.app.queueSave() }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SettingsButton {
            icon: "󰅐"
            text: "Send test notification"
            primary: true
            onClicked: Quickshell.execDetached([
                "notify-send", "-a", "Settings", "-i", "dialog-information",
                "Test notification", "Popups are working."
            ])
        }

        SettingsButton {
            icon: "󰅖"
            text: "Clear popups"
            onClicked: Quickshell.execDetached([
                "qs", "ipc", "-c", "notifications", "call", "notifications", "clear"
            ])
        }

        Item { Layout.fillWidth: true }
    }
}
