import QtQuick
import QtQuick.Layouts

// Keyboard / pointer / touchpad / gesture settings from input.lua.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Input"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Keyboard, mouse and touchpad settings from ~/.config/hypr/hyprland/input.lua."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "KEYBOARD"

        TextFieldRow {
            Layout.fillWidth: true
            label: "Layout"
            value: root.app.inKbLayout
            placeholder: "us"
            onEdited: value => root.app.inKbLayout = value
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Variant"
            value: root.app.inKbVariant
            placeholder: ""
            onEdited: value => root.app.inKbVariant = value
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Model"
            value: root.app.inKbModel
            placeholder: ""
            onEdited: value => root.app.inKbModel = value
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Options"
            value: root.app.inKbOptions
            placeholder: "e.g. caps:swapescape"
            onEdited: value => root.app.inKbOptions = value
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Rules"
            value: root.app.inKbRules
            placeholder: ""
            onEdited: value => root.app.inKbRules = value
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "POINTER"

        SliderField {
            Layout.fillWidth: true
            label: "Follow mouse"
            from: 0
            to: 2
            value: root.app.inFollowMouse
            onMoved: value => root.app.inFollowMouse = Math.round(value)
        }

        SliderField {
            Layout.fillWidth: true
            label: "Sensitivity"
            from: -1
            to: 1
            stepSize: 0.05
            decimals: 2
            value: root.app.inSensitivity
            onMoved: value => root.app.inSensitivity = Math.round(value * 100) / 100
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Accel profile"
            value: root.app.inAccelProfile
            placeholder: "flat"
            onEdited: value => root.app.inAccelProfile = value
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Disable acceleration"
            hint: "force_no_accel"
            checked: root.app.inForceNoAccel
            onToggled: value => root.app.inForceNoAccel = value
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "TOUCHPAD"

        ToggleRow {
            Layout.fillWidth: true
            label: "Natural scrolling"
            hint: "touchpad.natural_scroll"
            checked: root.app.inNaturalScroll
            onToggled: value => root.app.inNaturalScroll = value
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "GESTURES"

        TextFieldRow {
            Layout.fillWidth: true
            label: "Fingers"
            value: String(root.app.gestureFingers)
            placeholder: "3"
            onEdited: value => root.app.gestureFingers = parseInt(value, 10) || 3
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Direction"
            value: root.app.gestureDirection
            placeholder: "horizontal"
            onEdited: value => root.app.gestureDirection = value
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Action"
            value: root.app.gestureAction
            placeholder: "workspace"
            onEdited: value => root.app.gestureAction = value
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "PER-DEVICE OVERRIDE"
        subtitle: "Optional sensitivity override for a named device."

        TextFieldRow {
            Layout.fillWidth: true
            label: "Device name"
            value: root.app.deviceName
            placeholder: "epic-mouse-v1"
            onEdited: value => root.app.deviceName = value
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Sensitivity"
            value: String(root.app.deviceSensitivity)
            placeholder: "-0.5"
            onEdited: value => root.app.deviceSensitivity = parseFloat(value) || 0
        }
    }
}
