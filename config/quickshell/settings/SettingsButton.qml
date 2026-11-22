import QtQuick
import QtQuick.Controls.Basic

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property string tooltip: ""
    property bool primary: false
    property bool danger: false
    property real press: 0

    signal clicked()

    activeFocusOnTab: true

    implicitWidth: label.implicitWidth + 26
    implicitHeight: 30
    radius: 8
    color: primary
        ? (mouse.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent)
        : (danger
            ? (mouse.containsMouse ? "#2a181b" : "#1e1416")
            : (mouse.containsMouse ? Theme.hover : Theme.surfaceAlt))
    border.width: root.activeFocus ? 2 : 1
    border.color: root.activeFocus
        ? Theme.accent
        : (primary ? Theme.accent : (danger ? "#4a2a2e" : Theme.border))
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

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Text {
            visible: root.text !== ""
            text: root.text
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: root.primary ? Font.DemiBold : Font.Normal
            color: root.primary ? Theme.bg : (root.danger ? Theme.red : Theme.text)
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressedChanged: root.press = containsPress ? 1 : 0
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    ToolTip {
        visible: root.tooltip !== "" && (mouse.containsMouse || root.activeFocus)
        text: root.tooltip
        delay: 250
    }
}
