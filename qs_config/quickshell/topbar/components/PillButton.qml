import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color accent: Theme.accent
    property bool danger: false

    signal clicked()

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 30
    radius: 8
    color: mouse.containsMouse
        ? (danger ? "#2a181b" : Theme.hover)
        : (danger ? "#1e1416" : Theme.surfaceAlt)
    border.width: 1
    border.color: danger ? "#4a2a2e" : Theme.border

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.icon !== "" && root.label !== "" ? 6 : 0

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
            color: root.danger ? Theme.red : root.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.label !== ""
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 12
            color: root.danger ? Theme.red : Theme.text
            anchors.verticalCenter: parent.verticalCenter
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
