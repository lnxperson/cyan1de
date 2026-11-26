pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared replay-buffer state for every bar instance. replay.sh writes a tiny
// state file while its rolling buffer is running; the panel uses it to show a
// gray pill in the recording slot with the configured buffer length.
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
    property int seconds: 0

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
                const seconds = Number(lines[2]);
                root.active = true;
                root.pid = pid;
                root.seconds = Number.isInteger(seconds) && seconds > 0
                    ? seconds
                    : 60;
                return;
            }
        }

        root.active = false;
        root.pid = 0;
        root.seconds = 0;
    }

    property FileView stateFile: FileView {
        path: root.statePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: root.reload()
    }
}
