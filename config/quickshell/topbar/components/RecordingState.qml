pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared recording state for every bar instance. The recorder helper writes a
// tiny three-line state file; this singleton turns it into a live elapsed time.
QtObject {
    id: root

    readonly property string statePath: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR") || "";
        const home = Quickshell.env("HOME") || "";
        return runtime
            ? runtime + "/cyan1de/recorder.state"
            : home + "/.cache/cyan1de/recorder.state";
    }

    property bool active: false
    property int started: 0
    property int elapsedSeconds: 0
    property string output: ""

    function refreshElapsed() {
        if (!root.active) {
            root.elapsedSeconds = 0;
            return;
        }
        root.elapsedSeconds = Math.max(
            0, Math.floor(Date.now() / 1000) - root.started);
    }

    function reload() {
        let text = "";
        try {
            text = stateFile.text();
        } catch (e) {
            text = "";
        }

        const lines = text.trim().split("\n");
        if (lines.length >= 3 && lines[0] === "v1") {
            const pid = Number(lines[1]);
            const started = Number(lines[2]);
            if (Number.isInteger(pid) && pid > 0
                && Number.isInteger(started) && started > 0) {
                root.active = true;
                root.started = started;
                root.output = lines.slice(3).join("\n");
                root.refreshElapsed();
                return;
            }
        }

        root.active = false;
        root.started = 0;
        root.elapsedSeconds = 0;
        root.output = "";
    }

    property FileView stateFile: FileView {
        path: root.statePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: root.reload()
    }

    // Poll for deletion as well as creation; FileView tracks content changes.
    property Timer poll: Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: stateFile.reload()
    }

    property Timer ticker: Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.refreshElapsed()
    }
}
