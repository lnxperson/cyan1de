import QtQuick

// Navigation entry in the settings sidebar.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool hovered: false
    property bool outgoing: false
    property real press: 0

    signal clicked()

    activeFocusOnTab: true

    implicitHeight: 36
    radius: Theme.controlRadius
    // Keep both ends of the slide filled: the clicked row until the highlight
    // arrives, and the row being left until it moves away.
    color: outgoing ? Theme.active
        : active
            ? (hovered ? Theme.active : "transparent")
            : (hovered ? Theme.hover : "transparent")
    border.width: root.activeFocus ? 1 : 0
    border.color: Theme.accent
    scale: 1 - 0.02 * root.press

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.width { NumberAnimation { duration: Theme.motionFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Easing.OutCubic
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 10

        Text {
            id: iconText
            text: root.icon
            font.family: Theme.font
            font.pixelSize: 16
            color: root.active ? Theme.accent : Theme.subtext
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Text {
            id: labelText
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 12
            font.weight: root.active ? Font.DemiBold : Font.Normal
            color: root.active ? Theme.accentSoft : Theme.text
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: root.hovered = containsMouse
        onPressedChanged: root.press = containsPress ? 1 : 0
        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
}
