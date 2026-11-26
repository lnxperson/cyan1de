pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared idle-inhibitor state for every bar instance. power/inhibit.sh writes
// a tiny state file while its hypridle process is running; the panel uses it
// to show the coffee symbol in the action status cluster.
QtObject {
    id: root

    readonly property string statePath: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR") || "";
        const home = Quickshell.env("HOME") || "";
        return runtime
            ? runtime + "/cyan1de/idle.state"
            : home + "/.cache/cyan1de/idle.state";
    }

    property bool active: false

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
        root.active = text.trim() === "1";
    }

    property FileView stateFile: FileView {
        path: root.statePath
        watchChanges: true
        preload: true
        blockLoading: true
        printErrors: false
        onFileChanged: stateFile.reload()
        onLoaded: root.reload()
        onLoadFailed: root.active = false
    }
}
