import QtQuick
import Quickshell
import Quickshell.Hyprland

Row {
    id: root

    property var screen: null
    property int count: 10

    spacing: 2

    function workspaceFor(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i];
        }
        return null;
    }

    Repeater {
        model: root.count

        delegate: Item {
            id: button

            required property int index

            readonly property int wsId: index + 1
            readonly property var ws: root.workspaceFor(wsId)
            readonly property bool focused: ws !== null && ws.focused
            readonly property bool occupied: ws !== null && ws.toplevels.values.length > 0
            readonly property bool urgent: ws !== null && ws.urgent

            width: 26
            height: 26

            Rectangle {
                anchors.centerIn: parent
                width: 24
                height: 22
                radius: 6
                color: button.focused
                    ? Theme.active
                    : (mouse.containsMouse ? Theme.hover : "transparent")
                border.width: button.focused ? 1 : 0
                border.color: Theme.accent

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Text {
                anchors.centerIn: parent
                text: button.wsId
                font.family: Theme.mono
                font.pixelSize: Theme.barFontSize
                font.weight: button.focused ? Font.DemiBold : Font.Normal
                color: button.urgent
                    ? Theme.red
                    : (button.focused
                        ? Theme.accent
                        : (button.occupied ? Theme.text : Theme.dim))
            }

            // Small occupancy dot under the workspace number.
            Rectangle {
                visible: button.occupied && !button.focused
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                width: 3
                height: 3
                radius: 1.5
                color: button.urgent ? Theme.red : Theme.subtext
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + button.wsId + " })")
                onWheel: function (event) {
                    Hyprland.dispatch(event.angleDelta.y > 0
                        ? "hl.dsp.focus({ workspace = 'e-1' })"
                        : "hl.dsp.focus({ workspace = 'e+1' })");
                }
            }
        }
    }
}
