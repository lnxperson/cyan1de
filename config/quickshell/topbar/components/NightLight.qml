pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared night-light state. hyprsunset handles the actual colour transform;
// this singleton only persists the toggle/intensity and drives its IPC.
QtObject {
    id: root

    readonly property string scriptPath: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/topbar/nightlight.sh"

    property bool enabled: false
    property int intensity: 60
    property bool available: false

    readonly property int temperature: 6500 - root.intensity * 40

    Component.onCompleted: root.refresh()

    function refresh() {
        statusProcess.running = false;
        statusProcess.running = true;
    }

    function setEnabled(value) {
        const on = !!value;
        actionProcess.running = false;
        actionProcess.command = [root.scriptPath, on ? "enable" : "disable", String(root.intensity)];
        actionProcess.running = true;

        root.enabled = on;
        if (on)
            root.available = true;
    }

    function previewIntensity(value) {
        root.intensity = Math.max(0, Math.min(100, Math.round(value)));
    }

    function setIntensity(value) {
        const v = Math.max(0, Math.min(100, Math.round(value)));
        root.intensity = v;

        actionProcess.running = false;
        actionProcess.command = root.enabled
            ? [root.scriptPath, "enable", String(v)]
            : [root.scriptPath, "set", String(v), "0"];
        actionProcess.running = true;
    }

    property Process statusProcess: Process {
        command: [root.scriptPath, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length < 3)
                    return;

                root.enabled = parts[0] === "1";
                const value = parseInt(parts[1], 10);
                if (!isNaN(value))
                    root.intensity = Math.max(0, Math.min(100, value));
                root.available = parts[2] === "1";
            }
        }
    }

    property Process actionProcess: Process {
        command: []

        stdout: StdioCollector {
            onStreamFinished: root.refresh()
        }
        stderr: StdioCollector {
            onStreamFinished: root.refresh()
        }
    }
}
