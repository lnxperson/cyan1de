import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property bool primary: false
    property bool danger: false

    signal clicked()

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 30
    radius: 8
    color: primary
        ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
        : (danger
            ? (mouse.containsMouse ? "#2a181b" : "#1e1416")
            : (mouse.containsMouse ? Theme.hover : Theme.surfaceAlt))
    border.width: 1
    border.color: primary ? Theme.accent : (danger ? "#4a2a2e" : Theme.border)

    Behavior on color { ColorAnimation { duration: 100 } }

    Row {
        id: label
        anchors.centerIn: parent
        spacing: root.icon !== "" && root.text !== "" ? 6 : 0

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.font
            font.pixelSize: 13
            color: root.primary ? Theme.bg : (root.danger ? Theme.red : Theme.accent)
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.text !== ""
            text: root.text
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: root.primary ? Font.DemiBold : Font.Normal
            color: root.primary ? Theme.bg : (root.danger ? Theme.red : Theme.text)
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
