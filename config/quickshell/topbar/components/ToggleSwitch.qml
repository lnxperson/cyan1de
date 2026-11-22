import QtQuick

Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 40
    implicitHeight: 22
    radius: 11
    color: root.checked ? Theme.accent : Theme.surfaceAlt
    border.width: 1
    border.color: root.checked ? Theme.accent : Theme.border
    scale: 1 - 0.03 * (toggleArea.containsPress ? 1 : 0)

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 1.5
        x: root.checked ? root.width - width - 2 : 2
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
        id: toggleArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
