import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Autostart"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Commands run when Hyprland starts. Written to autostart.lua on Apply."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "COMMANDS"
        subtitle: "These run on hyprland.start. Keep the Quickshell daemons and lockscreen lines."

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
                        onTextEdited: root.app.setAutostart(autoRow.index, text)
                        onEditingFinished: root.app.setAutostart(autoRow.index, text)
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
            text: "hyprland/autostart.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }
}
