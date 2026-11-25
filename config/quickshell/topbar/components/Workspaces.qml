import QtQuick
import Quickshell
import Quickshell.Hyprland

// Workspace switcher. One sliding rectangle marks the focused workspace,
// matching the bar's action indicator. Flow keeps the same delegate working as
// a row on horizontal edges and a column on vertical edges.
Item {
    id: root

    property var screen: null
    property int count: 10
    property bool vertical: false

    readonly property int cellSize: 26
    readonly property int cellSpacing: 2
    readonly property int step: root.cellSize + root.cellSpacing

    implicitWidth: root.vertical
        ? root.cellSize
        : root.count * root.cellSize + (root.count - 1) * root.cellSpacing
    implicitHeight: root.vertical
        ? root.count * root.cellSize + (root.count - 1) * root.cellSpacing
        : root.cellSize

    property rect workspaceHighlightRect: Qt.rect(0, 0, 0, 0)
    property bool workspaceHighlightVisible: false
    property bool workspaceHighlightAnimate: false

    function workspaceFor(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i];
        }
        return null;
    }

    readonly property int focusedIndex: {
        for (let i = 0; i < root.count; i++) {
            const ws = root.workspaceFor(i + 1);
            if (ws && ws.focused)
                return i;
        }
        return -1;
    }

    function workspaceHighlightGeometry() {
        if (root.focusedIndex < 0)
            return null;

        return root.vertical
            ? Qt.rect(1, root.focusedIndex * root.step + 2, 24, 22)
            : Qt.rect(root.focusedIndex * root.step + 1, 2, 24, 22);
    }

    function syncWorkspaceHighlight(animate) {
        const rect = root.workspaceHighlightGeometry();
        if (!rect) {
            root.workspaceHighlightVisible = false;
            root.workspaceHighlightAnimate = false;
            return;
        }

        if (!root.workspaceHighlightVisible) {
            root.workspaceHighlightAnimate = false;
            root.workspaceHighlightRect = rect;
            root.workspaceHighlightVisible = true;
            Qt.callLater(function () {
                if (root.workspaceHighlightVisible)
                    root.workspaceHighlightAnimate = true;
            });
            return;
        }

        root.workspaceHighlightAnimate = animate === true;
        root.workspaceHighlightRect = rect;
    }

    onFocusedIndexChanged: root.syncWorkspaceHighlight(true)
    onVerticalChanged: root.syncWorkspaceHighlight(false)
    onCountChanged: root.syncWorkspaceHighlight(false)

    Component.onCompleted: {
        Qt.callLater(function () { root.syncWorkspaceHighlight(false) });
    }

    // Single active-workspace marker that slides between cells.
    Rectangle {
        x: root.workspaceHighlightRect.x
        y: root.workspaceHighlightRect.y
        width: root.workspaceHighlightRect.width
        height: root.workspaceHighlightRect.height
        radius: Math.min(Theme.controlRadius, height / 2)
        color: Theme.active
        border.width: 1
        border.color: Theme.accent
        scale: 1.06
        opacity: root.workspaceHighlightVisible ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

        Behavior on x {
            enabled: root.workspaceHighlightAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: root.workspaceHighlightAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            enabled: root.workspaceHighlightAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: root.workspaceHighlightAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
    }

    Flow {
        id: track

        anchors.fill: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: root.cellSpacing

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

                width: root.cellSize
                height: root.cellSize

                // Hover only; the focused fill is the sliding marker behind it.
                Rectangle {
                    anchors.centerIn: parent
                    width: 24
                    height: 22
                    radius: Math.min(Theme.controlRadius, height / 2)
                    color: !button.focused && mouse.containsMouse
                        ? Theme.hover : "transparent"
                    border.width: 0
                    scale: !button.focused && mouse.containsMouse ? 1.03 : 1

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Easing.OutCubic
                        }
                    }
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

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                // Small occupancy dot under the workspace number.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    width: 3
                    height: 3
                    radius: 1.5
                    color: button.urgent ? Theme.red : Theme.subtext
                    opacity: button.occupied && !button.focused ? 1 : 0

                    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
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
}
