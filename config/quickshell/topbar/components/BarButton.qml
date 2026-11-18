import QtQuick

Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool muted: false
    property string tooltip: ""

    signal clicked()

    implicitWidth: content.implicitWidth + 18
    implicitHeight: 26
    opacity: muted ? 0.55 : 1.0

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: root.active
            ? Theme.active
            : (mouse.containsMouse ? Theme.hover : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: root.icon !== "" && root.label !== "" ? 6 : 0

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.font
            font.pixelSize: Theme.iconSize + 1
            color: root.active ? Theme.accent : Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.label !== ""
            text: root.label
            font.family: Theme.mono
            font.pixelSize: Theme.barFontSize
            color: root.active ? Theme.accentSoft : Theme.text
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
