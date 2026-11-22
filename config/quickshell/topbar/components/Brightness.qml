pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared brightness state for every bar and software dimming overlay.
// Hardware outputs are read/written through brightness.sh; outputs without
// DDC/CI are represented as software displays backed by a persisted value.
QtObject {
    id: root

    readonly property string scriptPath: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/topbar/brightness.sh"
    readonly property string cursorDimScript: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/topbar/cursor-dim.py"

    property ListModel displayModel: ListModel {
        id: displayStore
    }

    readonly property alias displays: displayStore

    property int percent: 0
    property bool available: false
    property int readIndex: -1

    Component.onCompleted: root.refresh()

    function refresh() {
        if (listProcess.running || readProcess.running)
            return;
        listProcess.running = true;
    }

    function readAll() {
        if (listProcess.running || readProcess.running)
            return;
        readIndex = -1;
        readNext();
    }

    function readNext() {
        readIndex++;
        while (readIndex < displayModel.count) {
            readProcess.command = [scriptPath, "get", displayModel.get(readIndex).uid];
            readProcess.running = true;
            return;
        }
        root.updateSummary();
    }

    function updateSummary() {
        let total = 0;
        for (let i = 0; i < displayModel.count; i++)
            total += displayModel.get(i).percent;
        root.percent = displayModel.count > 0 ? Math.round(total / displayModel.count) : 0;
        root.available = displayModel.count > 0;
    }

    function findIndex(uid) {
        for (let i = 0; i < displayModel.count; i++) {
            if (displayModel.get(i).uid === uid)
                return i;
        }
        return -1;
    }

    // Live slider movement: update the model so software overlays respond
    // immediately, but only persist/commit when the slider is released.
    function previewPercent(uid, value) {
        const v = Math.round(Math.max(0, Math.min(100, value)));
        const index = root.findIndex(uid);
        if (index >= 0)
            displayModel.setProperty(index, "percent", v);
        root.updateSummary();
    }

    function applyPercent(uid, value) {
        const v = Math.round(Math.max(0, Math.min(100, value)));
        const index = root.findIndex(uid);
        if (index >= 0)
            displayModel.setProperty(index, "percent", v);
        root.updateSummary();
        Quickshell.execDetached([scriptPath, "set", uid, String(v)]);
        Quickshell.execDetached([cursorDimScript]);
    }

    function applyAll(value) {
        const v = Math.round(Math.max(0, Math.min(100, value)));
        for (let i = 0; i < displayModel.count; i++) {
            const item = displayModel.get(i);
            displayModel.setProperty(i, "percent", v);
            Quickshell.execDetached([scriptPath, "set", item.uid, String(v)]);
        }
        Quickshell.execDetached([cursorDimScript]);
        root.updateSummary();
    }

    function percentForScreen(name) {
        if (!name)
            return 100;
        const lower = name.toLowerCase();
        for (let i = 0; i < displayModel.count; i++) {
            const item = displayModel.get(i);
            if (item.mode === "software" && item.connector.toLowerCase() === lower)
                return item.percent;
        }
        return 100;
    }

    function hasSoftwareForScreen(name) {
        if (!name)
            return false;
        const lower = name.toLowerCase();
        for (let i = 0; i < displayModel.count; i++) {
            const item = displayModel.get(i);
            if (item.mode === "software" && item.connector.toLowerCase() === lower)
                return true;
        }
        return false;
    }

    property Process listProcess: Process {
        command: [root.scriptPath, "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                displayModel.clear();
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t");
                    const uid = (parts[0] || "").trim();
                    const label = (parts[1] || "").trim();
                    const connector = (parts[2] || "").trim();
                    const mode = (parts[3] || "").trim();
                    if (!uid || !label)
                        continue;
                    displayModel.append({
                        uid: uid,
                        label: label,
                        connector: connector,
                        mode: mode || uid.split(":")[0],
                        percent: 100
                    });
                }
                root.updateSummary();
                root.readAll();
            }
        }
    }

    property Process readProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim(), 10);
                const index = root.readIndex;
                if (!isNaN(value) && index >= 0 && index < displayModel.count)
                    displayModel.setProperty(index, "percent", Math.max(0, Math.min(100, value)));
                root.updateSummary();
                root.readNext();
            }
        }
    }
}
