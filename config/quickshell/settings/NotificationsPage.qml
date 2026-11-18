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

    Text {
        text: "Popup behaviour and appearance. Changes are saved automatically."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
    }

    SectionCard {
        Layout.fillWidth: true
        title: "BEHAVIOUR"

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Position"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
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
