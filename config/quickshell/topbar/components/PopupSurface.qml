import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property int padding: 16
    default property alias content: column.data

    // PopupWindow visibility is a hard cut, so the surface owns a short
    // reveal animation and delays the actual window hide until it finishes.
    property var window: null
    property real reveal: 0
    property bool closing: false

    readonly property string attachEdge: root.window && root.window.bar
        ? root.window.bar.edge : ""
    readonly property int enterX: root.attachEdge === "left"
        ? -Theme.motionEnterOffset
        : (root.attachEdge === "right" ? Theme.motionEnterOffset : 0)
    readonly property int enterY: root.attachEdge === "top"
        ? -Theme.motionEnterOffset
        : (root.attachEdge === "bottom" ? Theme.motionEnterOffset : 0)

    radius: Theme.panelRadius
    color: Theme.popupFill(Theme.surface)
    border.width: 1
    border.color: Theme.border

    opacity: root.reveal
    scale: Theme.motionEnterScale + (1 - Theme.motionEnterScale) * root.reveal
    transform: Translate {
        x: root.enterX * (1 - root.reveal)
        y: root.enterY * (1 - root.reveal)
    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

    Timer {
        id: hideTimer
        interval: Theme.motionFast + 20
        onTriggered: {
            if (root.window)
                root.window.visible = false;
            root.closing = false;
        }
    }

    function open() {
        hideTimer.stop();
        root.closing = false;
        if (root.window)
            root.window.visible = true;
        root.reveal = 1;
    }

    function close() {
        if (!root.window || !root.window.visible || root.closing)
            return;
        root.closing = true;
        root.reveal = 0;
        hideTimer.start();
    }

    // Used when the PopupWindow is hidden outside of close(), for example by
    // the compositor dismissing it. Keeps the next open animated.
    function reset() {
        hideTimer.stop();
        root.closing = false;
        root.reveal = 0;
    }

    // Soft drop shadow, drawn inside the transparent popup surface.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        z: -1
        radius: parent.radius + 1
        color: "#55000000"
    }

    Flickable {
        id: flick
        anchors {
            fill: parent
            margins: root.padding
        }
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: column.width
        contentHeight: Math.max(flick.height, column.implicitHeight)

        ColumnLayout {
            id: column
            width: flick.width
            height: Math.max(flick.height, implicitHeight)
            spacing: 12
        }
    }

    PopupDimOverlay {
        anchors.fill: parent
        radius: parent.radius
    }
}
