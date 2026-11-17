import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color accent: Theme.text
    property bool danger: false

    signal clicked()

    implicitHeight: 64
    radius: 10
    color: mouse.containsMouse
        ? (danger ? "#2a181b" : Theme.hover)
        : Theme.surfaceAlt
    border.width: 1
    border.color: danger ? "#4a2a2e" : Theme.border

    Behavior on color { ColorAnimation { duration: 120 } }

    Column {
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            font.family: Theme.font
            font.pixelSize: 19
            color: root.danger ? Theme.red : root.accent
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 10
            color: root.danger ? Theme.red : Theme.text
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
