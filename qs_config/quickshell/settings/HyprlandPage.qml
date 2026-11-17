import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Hyprland look & feel plus autostart / environment management.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Hyprland"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Look & feel is applied with Apply. Autostart and environment changes are written to "
            + "~/.config/hypr/hyprland and take effect on the next login."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // ---- Borders ------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: borderColumn.implicitHeight + 28
        radius: 12
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: borderColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                text: "WINDOW BORDERS"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

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

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.preferredWidth: 132
                    text: "Gradient border"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.subtext
                }

                Rectangle {
                    width: 44
                    height: 24
                    radius: 12
                    color: root.app.hyprGradient ? Theme.accent : Theme.bg
                    border.width: 1
                    border.color: root.app.hyprGradient ? Theme.accent : Theme.border

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        x: root.app.hyprGradient ? parent.width - width - 3 : 3
                        y: 3
                        width: 18
                        height: 18
                        radius: 9
                        color: root.app.hyprGradient ? Theme.bg : Theme.subtext

                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.app.hyprGradient = !root.app.hyprGradient
                    }
                }

                Item { Layout.fillWidth: true }
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
    }

    // ---- Shape & gaps -------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: shapeColumn.implicitHeight + 28
        radius: 12
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: shapeColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                text: "WINDOW SHAPE & GAPS"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

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
    }

    // ---- Autostart ----------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: autoColumn.implicitHeight + 28
        radius: 12
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: autoColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                text: "AUTOSTART"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

            Column {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.app.autostart

                    delegate: RowLayout {
                        id: autoRow

                        required property int index
                        required property string modelData

                        width: parent.width
                        spacing: 8

                        TextField {
                            id: autoCmdField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            text: autoRow.modelData
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 10
                            selectByMouse: true
                            leftPadding: 8
                            rightPadding: 8
                            background: Rectangle {
                                color: Theme.bg
                                radius: 6
                                border.width: 1
                                border.color: autoCmdField.activeFocus ? Theme.accent : Theme.border
                            }
                            onEditingFinished: root.app.setAutostart(index, text)
                        }

                        SettingsButton {
                            icon: "󰅖"
                            danger: true
                            onClicked: root.app.removeAutostart(autoRow.index)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: autoInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    placeholderText: "command to run at login…"
                    placeholderTextColor: Theme.dim
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 10
                    selectByMouse: true
                    leftPadding: 8
                    rightPadding: 8
                    background: Rectangle {
                        color: Theme.bg
                        radius: 6
                        border.width: 1
                        border.color: autoInput.activeFocus ? Theme.accent : Theme.border
                    }
                    onAccepted: {
                        root.app.addAutostart(text);
                        text = "";
                    }
                }

                SettingsButton {
                    icon: "󰐕"
                    text: "Add"
                    onClicked: {
                        root.app.addAutostart(autoInput.text);
                        autoInput.text = "";
                    }
                }
            }
        }
    }

    // ---- Environment --------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: envColumn.implicitHeight + 28
        radius: 12
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: envColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                text: "ENVIRONMENT VARIABLES"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

            Column {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.app.envVars

                    delegate: RowLayout {
                        id: envRow

                        required property int index
                        required property var modelData

                        width: parent.width
                        spacing: 8

                        TextField {
                            id: envKeyField
                            Layout.preferredWidth: 220
                            Layout.preferredHeight: 28
                            text: envRow.modelData.key
                            color: Theme.accentSoft
                            font.family: Theme.mono
                            font.pixelSize: 10
                            selectByMouse: true
                            leftPadding: 8
                            rightPadding: 8
                            background: Rectangle {
                                color: Theme.bg
                                radius: 6
                                border.width: 1
                                border.color: envKeyField.activeFocus ? Theme.accent : Theme.border
                            }
                            onEditingFinished: root.app.setEnv(envRow.index, "key", text)
                        }

                        TextField {
                            id: envValueField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            text: envRow.modelData.value
                            color: Theme.text
                            font.family: Theme.mono
                            font.pixelSize: 10
                            selectByMouse: true
                            leftPadding: 8
                            rightPadding: 8
                            background: Rectangle {
                                color: Theme.bg
                                radius: 6
                                border.width: 1
                                border.color: envValueField.activeFocus ? Theme.accent : Theme.border
                            }
                            onEditingFinished: root.app.setEnv(envRow.index, "value", text)
                        }

                        SettingsButton {
                            icon: "󰅖"
                            danger: true
                            onClicked: root.app.removeEnv(envRow.index)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                TextField {
                    id: envKeyInput
                    Layout.preferredWidth: 220
                    Layout.preferredHeight: 28
                    placeholderText: "VARIABLE"
                    placeholderTextColor: Theme.dim
                    color: Theme.accentSoft
                    font.family: Theme.mono
                    font.pixelSize: 10
                    selectByMouse: true
                    leftPadding: 8
                    rightPadding: 8
                    background: Rectangle {
                        color: Theme.bg
                        radius: 6
                        border.width: 1
                        border.color: envKeyInput.activeFocus ? Theme.accent : Theme.border
                    }
                }

                TextField {
                    id: envValueInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    placeholderText: "value"
                    placeholderTextColor: Theme.dim
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 10
                    selectByMouse: true
                    leftPadding: 8
                    rightPadding: 8
                    background: Rectangle {
                        color: Theme.bg
                        radius: 6
                        border.width: 1
                        border.color: envValueInput.activeFocus ? Theme.accent : Theme.border
                    }
                    onAccepted: {
                        root.app.addEnv(envKeyInput.text, text);
                        envKeyInput.text = "";
                        text = "";
                    }
                }

                SettingsButton {
                    icon: "󰐕"
                    text: "Add"
                    onClicked: {
                        root.app.addEnv(envKeyInput.text, envValueInput.text);
                        envKeyInput.text = "";
                        envValueInput.text = "";
                    }
                }
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
            text: "hyprland/autostart.lua · env.lua · ui_overrides.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }

}
