import QtQuick
import QtQuick.Layouts

// Labelled on/off switch used across the Hyprland config pages.
RowLayout {
    id: root

    property string label: ""
    property bool checked: false
    property int labelWidth: 150
    property string hint: ""

    signal toggled(bool value)

    spacing: 10

    ColumnLayout {
        Layout.preferredWidth: root.labelWidth
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.subtext
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: root.hint !== ""
            text: root.hint
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.dim
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        id: toggleTrack

        Layout.preferredWidth: 44
        Layout.preferredHeight: 24
        radius: 12
        color: root.checked ? Theme.accent : Theme.bg
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.border
        scale: 1 - 0.04 * (toggleMouse.containsPress ? 1 : 0)

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionFast
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            y: 3
            width: 18
            height: 18
            radius: 9
            color: root.checked ? Theme.bg : Theme.subtext

            Behavior on x {
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(!root.checked)
        }
    }

    Item { Layout.fillWidth: true }
}
