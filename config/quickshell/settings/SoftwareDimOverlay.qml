import QtQuick
import Quickshell
import Quickshell.Io

// Dims a single Quickshell popup from inside its own window. Shells launched
// after the full-screen software dimmer would otherwise map above it, so an
// internal overlay is the only reliable way to keep them in sync with the
// display brightness. Input passes through because the rectangle is disabled.
Rectangle {
    id: root

    property string monitorName: ""
    property int level: 100
    readonly property real dimAlpha: Math.max(0, Math.min(0.95, (100 - level) / 100))

    anchors.fill: parent
    color: "black"
    opacity: root.dimAlpha
    visible: root.dimAlpha > 0
    enabled: false
    z: 1000

    FileView {
        id: brightnessFile
        path: (Quickshell.env("HOME") || "") + "/.config/quickshell/soft-brightness.json"
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.reload()
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
        running: true
        onTriggered: {
            root.reload();
            if (!focusProbe.running)
                focusProbe.running = true;
        }
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
        focusProbe.running = true;
        root.reload();
    }
}
