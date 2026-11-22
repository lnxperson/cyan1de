import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color accent: Theme.text
    property bool danger: false
    property real press: 0
    property bool keyboardFocused: false

    activeFocusOnTab: true

    signal clicked()

    implicitHeight: 64
    radius: 10
    color: mouse.containsMouse
        ? (danger ? "#2a181b" : Theme.hover)
        : Theme.surfaceAlt
    border.width: root.activeFocus || root.keyboardFocused ? 2 : 1
    border.color: root.activeFocus || root.keyboardFocused
        ? Theme.accentSoft
        : (danger ? "#4a2a2e" : Theme.border)
    scale: 1 - 0.03 * root.press

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Easing.OutCubic
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 5

        Text {
            id: iconText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            font.family: Theme.font
            font.pixelSize: 19
            color: root.danger ? Theme.red : root.accent

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Text {
            id: labelText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 10
            color: root.danger ? Theme.red : Theme.text

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressedChanged: root.press = containsPress ? 1 : 0
        onClicked: root.clicked()
    }

    function keyboardActivate() { root.clicked(); }

    Keys.onReturnPressed: {
        event.accepted = true;
        root.clicked();
    }

    Keys.onSpacePressed: {
        event.accepted = true;
        root.clicked();
    }
}
