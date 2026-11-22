import QtQuick
import QtQuick.Layouts

// Idle dimming and screen lock. This is session behaviour, not display
// geometry, so it lives separately from the Monitors page.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Session"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Idle dimming and screen lock. Press Apply to rewrite hypridle.conf."
    }

    SectionCard {
        Layout.fillWidth: true
        title: "IDLE & LOCK"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            ToggleRow {
                Layout.fillWidth: true
                label: "Auto dim and lock"
                hint: "Generate ~/.config/hypr/hypridle.conf on Apply"
                checked: root.app.idleEnabled
                onToggled: value => { root.app.idleEnabled = value; root.app.queueSave() }
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Dim screen"
                hint: "Lower brightness when idle"
                checked: root.app.idleDimEnabled
                onToggled: value => { root.app.idleDimEnabled = value; root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Dim after"
                from: 30
                to: 900
                stepSize: 30
                suffix: "s"
                value: root.app.idleDimTimeout
                onMoved: value => { root.app.idleDimTimeout = Math.round(value); root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Dim brightness"
                from: 1
                to: 50
                stepSize: 1
                suffix: "%"
                value: root.app.idleDimLevel
                onMoved: value => { root.app.idleDimLevel = Math.round(value); root.app.queueSave() }
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Lock screen"
                hint: "Lock the session when idle"
                checked: root.app.idleLockEnabled
                onToggled: value => { root.app.idleLockEnabled = value; root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Lock after"
                from: 60
                to: 1800
                stepSize: 30
                suffix: "s"
                value: root.app.idleLockTimeout
                onMoved: value => { root.app.idleLockTimeout = Math.round(value); root.app.queueSave() }
            }

            Text {
                Layout.fillWidth: true
                text: "Display-off (330s) and suspend (900s) are kept as power-saving follow-ups. Press Apply to rewrite hypridle.conf."
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.dim
                wrapMode: Text.WordWrap
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SettingsButton {
            icon: "󰉋"
            text: "Open config folder"
            onClicked: root.app.openHyprFolder()
        }

        Item { Layout.fillWidth: true }

        SettingsButton {
            icon: "󰄬"
            text: "Apply all settings"
            primary: true
            onClicked: root.app.applyAll()
        }
    }
}
