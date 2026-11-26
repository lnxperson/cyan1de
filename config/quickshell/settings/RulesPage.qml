import QtQuick
import QtQuick.Layouts

// Read-only overview of window rules. Rules are advanced and edited in the file.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Window Rules"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Window matching, floating and position overrides from rules.lua. These are shown read-only — edit the file directly for advanced rules."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "ACTIVE RULES"

        Column {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.app.rules

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    implicitHeight: ruleCol.implicitHeight + 16
                    radius: Theme.controlRadius
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        id: ruleCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            font.family: Theme.mono
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.accentSoft
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.match
                            font.family: Theme.mono
                            font.pixelSize: 9
                            color: Theme.subtext
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "SOURCE"

        Text {
            Layout.fillWidth: true
            text: root.app.rulesText
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.subtext
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            maximumLineCount: 12
            elide: Text.ElideRight
            clip: true
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

        SettingsButton {
            icon: "󰄬"
            text: "Edit rules.lua"
            onClicked: root.app.openFile(root.app.hyprDir + "/rules.lua")
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "hyprland/rules.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }
}
