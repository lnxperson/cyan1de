import QtQuick

Item {
    id: root

    property string icon: ""
    property string badgeText: ""
    property string label: ""
    property bool active: false
    property bool muted: false
    property bool vertical: false
    property string tooltip: ""
    property real press: 0
    readonly property Item activeIconItem: root.vertical ? verticalIcon : horizontalIcon

    FontMetrics {
        id: iconMetrics
        font.family: Theme.font
        font.pixelSize: Theme.iconSize + 1
    }

    // Nerd Font glyphs have asymmetric side bearings. Centre on the painted
    // glyph instead of the Text item's advance box so the popup indicator lines
    // up with what the user actually sees.
    function iconVisualCenterX() {
        const target = root.activeIconItem;
        if (!target)
            return root.width / 2;
        const ink = iconMetrics.tightBoundingRect(root.icon);
        const center = ink.width > 0
            ? ink.x + ink.width / 2
            : target.width / 2;
        return target.mapToItem(root, center, 0).x;
    }

    function iconVisualWidth() {
        const target = root.activeIconItem;
        const ink = iconMetrics.tightBoundingRect(root.icon);
        if (ink.width > 0)
            return Math.round(Math.min(18, Math.max(8, ink.width)));
        return target ? Math.round(Math.min(18, Math.max(10, target.width - 2))) : 10;
    }

    signal clicked()

    implicitWidth: root.vertical ? 26 : content.implicitWidth + 18
    implicitHeight: 26
    opacity: muted ? 0.55 : 1.0
    scale: 1 - 0.03 * root.press

    Behavior on scale {
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: root.active
            ? Theme.active
            : (mouse.containsMouse ? Theme.hover : "transparent")

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    // Horizontal edges show the icon and label side by side.
    Row {
        id: content
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: ((root.icon !== "" && root.badgeText === "")
                    || root.badgeText !== "") && root.label !== "" ? 6 : 0

        Behavior on spacing {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: horizontalBadge

            width: root.badgeText !== "" ? 18 : 0
            height: 18
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.badgeText !== "" ? 1 : 0
            scale: root.badgeText !== "" ? 1 : Theme.motionEnterScale

            Behavior on width {
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: root.active ? Theme.active : Theme.surfaceAlt
                border.width: 1
                border.color: root.active ? Theme.accent : Theme.border

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
            }

            Text {
                anchors.centerIn: parent
                text: root.badgeText
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: root.active ? Theme.accentSoft : Theme.text

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }
        }

        Text {
            id: horizontalIcon
            visible: root.icon !== "" && root.badgeText === ""
            text: root.icon
            font.family: Theme.font
            font.pixelSize: Theme.iconSize + 1
            color: root.active ? Theme.accent : Theme.text
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Text {
            id: horizontalLabel
            visible: root.label !== ""
            text: root.label
            font.family: Theme.mono
            font.pixelSize: Theme.barFontSize
            color: root.active ? Theme.accentSoft : Theme.text
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }
    }

    // Vertical edges stay compact and icon/badge-only.
    Rectangle {
        id: verticalBadge

        visible: root.vertical
        width: 18
        height: 18
        anchors.centerIn: parent
        radius: width / 2
        color: root.active ? Theme.active : Theme.surfaceAlt
        border.width: 1
        border.color: root.active ? Theme.accent : Theme.border
        opacity: root.badgeText !== "" ? 1 : 0
        scale: root.badgeText !== "" ? 1 : Theme.motionEnterScale

        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.badgeText
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: root.active ? Theme.accentSoft : Theme.text

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
    }

    Text {
        id: verticalIcon
        visible: root.vertical && root.icon !== "" && root.badgeText === ""
        anchors.centerIn: parent
        text: root.icon
        font.family: Theme.font
        font.pixelSize: Theme.iconSize + 1
        color: root.active ? Theme.accent : Theme.text

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressedChanged: root.press = containsPress ? 1 : 0
        onClicked: root.clicked()
    }
}
