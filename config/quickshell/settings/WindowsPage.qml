import QtQuick
import QtQuick.Layouts

// Hyprland window decoration settings. These describe the windows themselves,
// so they live here rather than being buried under shell appearance.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Windows"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Borders, corner rounding and gaps. Press Apply to write the Hyprland look and feel."
    }

    SectionCard {
        Layout.fillWidth: true
        title: "WINDOW BORDERS"

        ColorField {
            Layout.fillWidth: true
            app: root.app
            label: "Active border"
            value: root.app.hyprBorder1
            onEdited: value => root.app.hyprBorder1 = value
        }

        ColorField {
            Layout.fillWidth: true
            app: root.app
            label: "Gradient end"
            value: root.app.hyprBorder2
            onEdited: value => root.app.hyprBorder2 = value
        }

        ColorField {
            Layout.fillWidth: true
            app: root.app
            label: "Inactive border"
            value: root.app.hyprInactive
            onEdited: value => root.app.hyprInactive = value
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Gradient border"
            checked: root.app.hyprGradient
            onToggled: value => root.app.hyprGradient = value
        }

        SliderField {
            Layout.fillWidth: true
            label: "Gradient angle"
            from: 0
            to: 90
            value: root.app.hyprAngle
            suffix: "°"
            enabled: root.app.hyprGradient
            opacity: enabled ? 1 : 0.45
            onMoved: value => root.app.hyprAngle = Math.round(value)
        }

        SliderField {
            Layout.fillWidth: true
            label: "Border size"
            from: 0
            to: 5
            value: root.app.hyprBorderSize
            suffix: "px"
            onMoved: value => root.app.hyprBorderSize = Math.round(value)
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "WINDOW SHAPE & GAPS"

        SliderField {
            Layout.fillWidth: true
            label: "Corner rounding"
            from: 0
            to: 20
            value: root.app.hyprRounding
            suffix: "px"
            onMoved: value => root.app.hyprRounding = Math.round(value)
        }

        SliderField {
            Layout.fillWidth: true
            label: "Inner gaps"
            from: 0
            to: 20
            value: root.app.hyprGapsIn
            suffix: "px"
            onMoved: value => root.app.hyprGapsIn = Math.round(value)
        }

        SliderField {
            Layout.fillWidth: true
            label: "Outer gaps"
            from: 0
            to: 20
            value: root.app.hyprGapsOut
            suffix: "px"
            onMoved: value => {
                root.app.hyprGapsOut = Math.round(value);
                root.app.queueManaged()
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
