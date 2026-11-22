import QtQuick
import QtQuick.Layouts

// Animation and blur settings. These affect Hyprland and Alacritty rather than
// the shell itself, so they get their own page instead of a hidden tab.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Effects"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Animations and blur. Press Apply to write hyprland/animations.lua and the blur configs."
    }

    SectionCard {
        Layout.fillWidth: true
        title: "ANIMATIONS"
        subtitle: "Built-in Hyprland styles and curves only. Speed scales every animation. Press Apply to write hyprland/animations.lua."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Window open"
            }

            OptionCombo {
                options: root.app.windowAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animWindowOpen
                onPicked: value => root.app.animWindowOpen = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Window close"
            }

            OptionCombo {
                options: root.app.windowAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animWindowClose
                onPicked: value => root.app.animWindowClose = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Workspace switch"
            }

            OptionCombo {
                options: root.app.workspaceAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animWorkspace
                onPicked: value => root.app.animWorkspace = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Layer / popup"
            }

            OptionCombo {
                options: root.app.layerAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animLayer
                onPicked: value => root.app.animLayer = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Open easing"
            }

            OptionCombo {
                options: root.app.animCurves
                labels: root.app.animCurveLabels
                selected: root.app.animOpenCurve
                onPicked: value => root.app.animOpenCurve = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Close easing"
            }

            OptionCombo {
                options: root.app.animCurves
                labels: root.app.animCurveLabels
                selected: root.app.animCloseCurve
                onPicked: value => root.app.animCloseCurve = value
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Animation speed"
            from: 1
            to: 20
            value: root.app.animSpeed
            suffix: ""
            onMoved: value => root.app.animSpeed = Math.round(value)
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "BLUR"

        ToggleRow {
            Layout.fillWidth: true
            label: "Hyprland blur"
            hint: "Blur behind transparent windows"
            checked: root.app.hyprBlur
            onToggled: value => {
                root.app.hyprBlur = value
                root.app.queueSave()
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Alacritty blur"
            hint: "Transparent terminal shows the desktop blur"
            checked: root.app.alacrittyBlur
            onToggled: value => {
                root.app.alacrittyBlur = value
                root.app.queueSave()
            }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Alacritty blur strength"
            from: 0
            to: 100
            value: root.app.alacrittyBlurStrength
            suffix: "%"
            enabled: root.app.alacrittyBlur
            opacity: enabled ? 1 : 0.45
            onMoved: value => {
                root.app.alacrittyBlurStrength = Math.round(value)
                root.app.queueSave()
            }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Hyprland blur radius"
            from: 1
            to: 20
            value: root.app.hyprBlurSize
            suffix: "px"
            enabled: root.app.hyprBlur
            opacity: enabled ? 1 : 0.45
            onMoved: value => {
                root.app.hyprBlurSize = Math.round(value)
                root.app.queueSave()
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

        Text {
            text: "hyprland/ui_overrides.lua + animations.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }

        SettingsButton {
            icon: "󰄬"
            text: "Apply all settings"
            primary: true
            onClicked: root.app.applyAll()
        }
    }
}
