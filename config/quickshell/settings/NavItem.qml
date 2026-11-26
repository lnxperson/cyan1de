import QtQuick

// Navigation entry in the settings sidebar.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool hovered: false
    property bool swapping: false
    property real press: 0

    signal clicked()

    activeFocusOnTab: true

    implicitHeight: 36
    radius: Theme.controlRadius
    // The sliding highlight is the only fill during a swap. Hover must not
    // cover it on the row being left, or that row looks like it briefly goes
    // transparent as the highlight slides away.
    //
    // A transparent Rectangle with border properties hits QTBUG-137166 and
    // punches a hole through the window. When the focus ring is on, use the
    // opaque surface that is already behind the row so the fill stays solid.
    color: root.activeFocus
        ? (active ? Theme.active : (hovered ? Theme.hover : Theme.surface))
        : (active || !hovered || swapping ? "transparent" : Theme.hover)
    border.width: root.activeFocus ? 1 : 0
    border.color: Theme.accent
    scale: 1 - 0.02 * root.press

    Behavior on color {
        enabled: !root.activeFocus
        ColorAnimation { duration: Theme.motionFast }
    }
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
