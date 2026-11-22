import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

ColumnLayout {
    id: root

    property string icon: ""
    property string label: ""
    property real value: 0
    property bool muted: false
    property bool showMute: true
    property color accent: Theme.accent

    signal moved(real value)
    signal committed(real value)
    signal muteToggled()

    spacing: 6

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: root.icon
            font.family: Theme.font
            font.pixelSize: Theme.iconSize + 1
            color: root.muted ? Theme.dim : Theme.text

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Text {
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 12
            color: Theme.subtext
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.muted ? "muted" : Math.round(root.value * 100) + "%"
            font.family: Theme.mono
            font.pixelSize: 12
            color: root.muted ? Theme.red : Theme.text

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Item {
            implicitWidth: 24
            implicitHeight: 24
            visible: root.showMute
            property bool keyboardFocused: false
            activeFocusOnTab: root.showMute

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: muteMouse.containsMouse || parent.activeFocus
                    || parent.keyboardFocused ? Theme.hover : "transparent"
                border.width: parent.activeFocus || parent.keyboardFocused ? 1 : 0
                border.color: Theme.accentSoft

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }

            Text {
                anchors.centerIn: parent
                text: root.muted ? "󰖁" : "󰕾"
                font.family: Theme.font
                font.pixelSize: Theme.iconSize
                color: root.muted ? Theme.red : Theme.subtext

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }

            MouseArea {
                id: muteMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.muteToggled()
            }

            function keyboardActivate() { root.muteToggled(); }

            Keys.onReturnPressed: {
                event.accepted = true;
                root.muteToggled();
            }

            Keys.onSpacePressed: {
                event.accepted = true;
                root.muteToggled();
            }
        }
    }

    Slider {
        id: slider
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        property bool keyboardFocused: false
        activeFocusOnTab: true

        from: 0
        to: 1
        value: root.value

        onMoved: root.moved(value)
        onPressedChanged: {
            if (!pressed)
                root.committed(value);
        }

        background: Rectangle {
            x: slider.leftPadding
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: slider.availableWidth
            height: 5
            radius: 3
            color: Theme.surfaceAlt

            Rectangle {
                width: slider.visualPosition * parent.width
                height: parent.height
                radius: parent.radius
                color: root.muted ? Theme.dim : root.accent

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + slider.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: root.muted ? Theme.subtext : Theme.accentSoft
            border.width: 2
            border.color: slider.activeFocus || slider.keyboardFocused
                ? Theme.accentSoft : Theme.surface
            scale: slider.pressed ? 1.15 : 1

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.motionFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        function keyboardActivate() { root.committed(slider.value); }
    }
}
