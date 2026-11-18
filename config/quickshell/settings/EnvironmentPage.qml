import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Environment"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Variables exported into the Hyprland session. Written to env.lua on Apply."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "VARIABLES"

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
                        onTextEdited: root.app.setEnv(envRow.index, "key", text)
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
                        onTextEdited: root.app.setEnv(envRow.index, "value", text)
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
                    root.app.addEnv(envKeyInput.text, envValueInput.text);
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
            text: "hyprland/env.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }
}
