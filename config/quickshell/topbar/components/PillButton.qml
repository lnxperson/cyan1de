import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color accent: Theme.accent
    property bool danger: false
    property real press: 0
    property bool keyboardFocused: false

    activeFocusOnTab: true

    signal clicked()

    implicitWidth: row.implicitWidth + 22
    implicitHeight: 30
    radius: 8
    color: mouse.containsMouse
        ? (danger ? "#2a181b" : Theme.hover)
        : (danger ? "#1e1416" : Theme.surfaceAlt)
    border.width: root.activeFocus || root.keyboardFocused ? 2 : 1
    border.color: root.activeFocus || root.keyboardFocused
        ? Theme.accentSoft
        : (danger ? "#4a2a2e" : Theme.border)
    scale: 1 - 0.025 * root.press
    opacity: 1 - 0.06 * root.press

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Easing.OutCubic
        }
    }

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
