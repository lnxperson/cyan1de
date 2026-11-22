import QtQuick
import Quickshell
import Quickshell.Io

// Dims a topbar PopupWindow from inside its own surface. Topbar popups are
// separate xdg popup surfaces mapped after the full-screen dimmer, so the
// full-screen overlay cannot cover them. Input passes through because the
// rectangle is disabled.
Rectangle {
    id: root

    property string monitorName: ""
    property int level: 100
    property real reveal: 1
    // Hidden popups still exist as QML objects. Only poll while this overlay's
    // own popup is actually on screen; otherwise every popup would spawn a
    // hyprctl process twice per second in the background.
    property bool active: true
    readonly property real dimAlpha: Math.max(0, Math.min(0.95, (100 - level) / 100))

    anchors.fill: parent
    color: "black"
    opacity: root.dimAlpha * root.reveal
    visible: root.dimAlpha > 0
    enabled: false
    z: 1000

    FileView {
        id: brightnessFile
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/soft-brightness.json"
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded && root.active) root.reload()
    }

    // PanelWindow.screen is not reliable for Hyprland popups, so ask the
    // compositor which monitor is focused and dim only that output.
    Process {
        id: focusProbe
        command: ["hyprctl", "-j", "activeworkspace"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (parsed && parsed.monitor)
                        root.monitorName = parsed.monitor;
                } catch (e) {
                    // Keep the last known monitor if the reply is malformed.
                }
            }
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: root.active
        onTriggered: {
            root.reload();
            if (!focusProbe.running)
                focusProbe.running = true;
        }
    }

    onActiveChanged: {
        if (!root.active)
            return;
        root.reload();
        if (!focusProbe.running)
            focusProbe.running = true;
    }

    function reload() {
        try {
            brightnessFile.reload();
            const parsed = JSON.parse(brightnessFile.text());
            const value = parsed[root.monitorName];
            root.level = typeof value === "number"
                ? Math.max(0, Math.min(100, Math.round(value)))
                : 100;
        } catch (e) {
            // Keep the last good value if the file is mid-write or missing.
        }
    }

    Component.onCompleted: {
        if (root.active) {
            focusProbe.running = true;
            root.reload();
        }
    }
}
