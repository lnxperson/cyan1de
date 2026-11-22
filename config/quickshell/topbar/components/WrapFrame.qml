import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Frame that hugs the screen while the unified bar is in "wrap" mode. It
// paints the three edges the bar does not cover, then curves into the bar
// with a rounded inner corner on both sides of the bar.
PanelWindow {
    id: frame

    property var modelData

    readonly property bool active: Theme.barLayout === "unifiedWrap"

    // Match the bar: a fullscreen workspace should not get a frame either.
    readonly property bool fullscreenHere: {
        const workspaces = Hyprland.workspaces.values;
        const monitor = screen ? Hyprland.monitorFor(screen) : null;

        for (let i = 0; i < workspaces.length; i++) {
            const workspace = workspaces[i];
            if (!workspace || !workspace.active || !workspace.hasFullscreen)
                continue;

            const wsMonitor = workspace.monitor;
            if (monitor && wsMonitor) {
                if (wsMonitor.id === monitor.id || wsMonitor.name === monitor.name)
                    return true;
                continue;
            }
            if (screen && wsMonitor && wsMonitor.name === screen.name)
                return true;
        }
        return false;
    }

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    visible: active && !fullscreenHere
    // The Canvas may not have painted while the window was hidden, so paint
    // once more whenever the frame is shown.
    onVisibleChanged: if (visible) surface.requestPaint()
    color: "transparent"
    focusable: false
    // -1 keeps the surface covering the whole output instead of being pushed
    // below the bar; Ignore keeps it out of the compositor's usable area.
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-wrap-" + (screen ? screen.name : "x")
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty input region: the frame never intercepts pointer events.
    mask: Region {
        intersection: Intersection.Subtract
        x: 0
        y: 0
        width: frame.width
        height: frame.height
    }

    Canvas {
        id: surface
        anchors.fill: parent

        Component.onCompleted: if (frame.visible) requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: Theme
            function onBarLayoutChanged() { surface.requestPaint() }
            function onBarEdgeChanged() { surface.requestPaint() }
            function onPanelHeightChanged() { surface.requestPaint() }
            function onWindowRoundingChanged() { surface.requestPaint() }
            function onPillFillChanged() { surface.requestPaint() }
        }

        onPaint: {
            const ctx = surface.getContext("2d");
            if (!ctx)
                return;

            const w = surface.width;
            const h = surface.height;
            if (w <= 0 || h <= 0)
                return;

            const t = Theme.panelHeight;
            // The wrap is a fixed 7px display border. Outer gaps only control
            // the space between this frame and the window area, so changing
            // that setting must not resize the frame.
            const gap = 7;
            // The frame thickness stays fixed, but its inner corners follow
            // Hyprland's window rounding so windows and wrap agree.
            const radius = Theme.windowRounding;
            const edge = Theme.barEdge;

            ctx.clearRect(0, 0, w, h);
            if (gap <= 0 || t <= 0)
                return;

            ctx.fillStyle = Theme.pillFill;
            ctx.beginPath();

            if (edge === "top") {
                // Left rail, bottom band, right rail. Every inner corner is
                // curved: the two under the bar and the two on the far side.
                ctx.moveTo(0, t);
                ctx.lineTo(0, h);
                ctx.lineTo(w, h);
                ctx.lineTo(w, t);
                ctx.lineTo(w - gap - radius, t);
                ctx.arc(w - gap - radius, t + radius, radius,
                    -Math.PI / 2, 0, false);
                ctx.lineTo(w - gap, h - gap - radius);
                ctx.arc(w - gap - radius, h - gap - radius, radius,
                    0, Math.PI / 2, false);
                ctx.lineTo(gap + radius, h - gap);
                ctx.arc(gap + radius, h - gap - radius, radius,
                    Math.PI / 2, Math.PI, false);
                ctx.lineTo(gap, t + radius);
                ctx.arc(gap + radius, t + radius, radius,
                    Math.PI, Math.PI * 1.5, false);
            } else if (edge === "bottom") {
                ctx.moveTo(0, h - t);
                ctx.lineTo(0, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h - t);
                ctx.lineTo(w - gap - radius, h - t);
                ctx.arc(w - gap - radius, h - t - radius, radius,
                    Math.PI / 2, 0, true);
                ctx.lineTo(w - gap, gap + radius);
                ctx.arc(w - gap - radius, gap + radius, radius,
                    0, -Math.PI / 2, true);
                ctx.lineTo(gap + radius, gap);
                ctx.arc(gap + radius, gap + radius, radius,
                    -Math.PI / 2, -Math.PI, true);
                ctx.lineTo(gap, h - t - radius);
                ctx.arc(gap + radius, h - t - radius, radius,
                    Math.PI, Math.PI / 2, true);
            } else if (edge === "left") {
                ctx.moveTo(t, 0);
                ctx.lineTo(w, 0);
                ctx.lineTo(w, h);
                ctx.lineTo(t, h);
                ctx.lineTo(t, h - gap - radius);
                ctx.arc(t + radius, h - gap - radius, radius,
                    Math.PI, Math.PI / 2, true);
                ctx.lineTo(w - gap - radius, h - gap);
                ctx.arc(w - gap - radius, h - gap - radius, radius,
                    Math.PI / 2, 0, true);
                ctx.lineTo(w - gap, gap + radius);
                ctx.arc(w - gap - radius, gap + radius, radius,
                    0, -Math.PI / 2, true);
                ctx.lineTo(t + radius, gap);
                ctx.arc(t + radius, gap + radius, radius,
                    -Math.PI / 2, Math.PI, true);
            } else {
                ctx.moveTo(w - t, 0);
                ctx.lineTo(0, 0);
                ctx.lineTo(0, h);
                ctx.lineTo(w - t, h);
                ctx.lineTo(w - t, h - gap - radius);
                ctx.arc(w - t - radius, h - gap - radius, radius,
                    0, Math.PI / 2, false);
                ctx.lineTo(gap + radius, h - gap);
                ctx.arc(gap + radius, h - gap - radius, radius,
                    Math.PI / 2, Math.PI, false);
                ctx.lineTo(gap, gap + radius);
                ctx.arc(gap + radius, gap + radius, radius,
                    Math.PI, Math.PI * 1.5, false);
                ctx.lineTo(w - t - radius, gap);
                ctx.arc(w - t - radius, gap + radius, radius,
                    -Math.PI / 2, 0, false);
            }

            ctx.closePath();
            ctx.fill();

            // One-pixel overlap under the bar hides any compositing seam
            // between the two surfaces. The opaque bar covers it.
            if (edge === "top")
                ctx.fillRect(0, t - 1, w, 1);
            else if (edge === "bottom")
                ctx.fillRect(0, h - t, w, 1);
            else if (edge === "left")
                ctx.fillRect(t - 1, 0, 1, h);
            else
                ctx.fillRect(w - t, 0, 1, h);
        }
    }
}
