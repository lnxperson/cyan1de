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

    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 1.5
        x: root.checked ? root.width - width - 2 : 2
        color: root.checked ? Theme.bg : Theme.subtext

        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
