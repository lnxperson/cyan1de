import QtQuick
import QtQuick.Layouts

// Hyprland look & feel. Written to ui_overrides.lua (loaded last).
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Appearance"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Wallpaper and Hyprland look & feel. Window values apply with the Apply button."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    WallpaperPage {
        Layout.fillWidth: true
        app: root.app
    }

    SectionCard {
        Layout.fillWidth: true
        title: "WINDOW BORDERS"

        ColorField {
            Layout.fillWidth: true
            label: "Active border"
            value: root.app.hyprBorder1
            presets: ["#0292e3", "#01d6be", "#7cc7f5", "#c6a0e8", "#e78a8a", "#e6c384"]
            onEdited: value => root.app.hyprBorder1 = value
        }

        ColorField {
            Layout.fillWidth: true
            label: "Gradient end"
            value: root.app.hyprBorder2
            presets: ["#01d6be", "#0292e3", "#68e0c8", "#b9e6ff", "#c6a0e8"]
            onEdited: value => root.app.hyprBorder2 = value
        }

        ColorField {
            Layout.fillWidth: true
            label: "Inactive border"
            value: root.app.hyprInactive
            presets: ["#0f3246", "#1a202b", "#232a37", "#2b3547", "#3a4a63"]
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
            onMoved: value => root.app.hyprGapsOut = Math.round(value)
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

        Text {
            text: "hyprland/ui_overrides.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }
}
