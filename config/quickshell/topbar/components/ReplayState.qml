pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared replay-buffer state for every bar instance. replay.sh writes a tiny
// two-line state file while its rolling buffer is running; the panel uses it
// to show a small gray icon in the recording slot.
QtObject {
    id: root

    readonly property string statePath: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR") || "";
        const home = Quickshell.env("HOME") || "";
        return runtime
            ? runtime + "/cyan1de/replay.state"
            : home + "/.cache/cyan1de/replay.state";
    }

    property bool active: false
    property int pid: 0

    function refresh() {
        stateFile.reload();
    }

    function reload() {
        let text = "";
        try {
            text = stateFile.text();
        } catch (e) {
            text = "";
        }

        const lines = text.trim().split("\n");
        if (lines.length >= 2 && lines[0] === "v1") {
            const pid = Number(lines[1]);
            if (Number.isInteger(pid) && pid > 0) {
                root.active = true;
                root.pid = pid;
                return;
            }
        }

        root.active = false;
        root.pid = 0;
    }

    property FileView stateFile: FileView {
        path: root.statePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: root.reload()
    }
}
