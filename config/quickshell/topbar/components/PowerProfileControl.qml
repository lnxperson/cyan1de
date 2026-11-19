pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Read/write power-profiles-daemon through a small shell helper. The daemon may
// be absent or stopped; callers simply check `available` before showing UI.
QtObject {
    id: root

    readonly property string scriptPath: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/topbar/powerprofiles.sh"

    property bool available: false
    property string profile: ""
    property var profiles: []

    readonly property var profileLabels: ({
        "performance": "Performance",
        "balanced": "Balanced",
        "power-saver": "Power Saver"
    })

    function labelFor(name) {
        return profileLabels[name] || name || "";
    }

    function refresh() {
        statusProcess.running = false;
        statusProcess.running = true;
    }

    function setProfile(name) {
        if (!name || name === root.profile)
            return;
        actionProcess.command = [root.scriptPath, "set", name];
        actionProcess.running = false;
        actionProcess.running = true;
        root.profile = name;
    }

    Component.onCompleted: root.refresh()

    property Process statusProcess: Process {
        command: [root.scriptPath, "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.available = d.available === true;
                    root.profile = d.profile || "";
                    root.profiles = Array.isArray(d.profiles) ? d.profiles : [];
                } catch (e) {
                    root.available = false;
                    root.profile = "";
                    root.profiles = [];
                }
            }
        }
    }

    property Process actionProcess: Process {
        command: []

        stdout: StdioCollector { onStreamFinished: root.refresh() }
        stderr: StdioCollector { onStreamFinished: root.refresh() }
    }
}
