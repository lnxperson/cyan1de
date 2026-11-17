import QtQuick
import QtQuick.Layouts

// Navigation entry in the settings sidebar.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool hovered: false

    signal clicked()

    implicitHeight: 40
    radius: 9
    color: active ? Theme.active : (hovered ? Theme.hover : "transparent")

    Behavior on color { ColorAnimation { duration: 110 } }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 10

        Text {
            text: root.icon
            font.family: Theme.font
            font.pixelSize: 16
            color: root.active ? Theme.accent : Theme.subtext
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 12
            font.weight: root.active ? Font.DemiBold : Font.Normal
            color: root.active ? Theme.accentSoft : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.hovered = containsMouse
        onClicked: root.clicked()
    }
}
