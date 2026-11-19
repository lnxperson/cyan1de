pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Reads/writes the active power profile through powerprofiles.sh.
// `available` is true only when a real power-profiles-daemon backend answers,
// so callers can hide the profile UI when PPD is not installed/running.
QtObject {
    id: root

    readonly property string scriptPath: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/topbar/powerprofiles.sh"

    readonly property var profileOptions: ["power-saver", "balanced", "performance"]
    readonly property var profileLabels: ({
        "power-saver": "Power saver",
        "balanced": "Balanced",
        "performance": "Performance"
    })

    property bool available: false
    property string profile: ""
    property var profiles: root.profileOptions
    property string backend: "none"

    function labelFor(name) {
        return root.profileLabels[name] || name || "";
    }

    readonly property string backendLabel: ({
        cli: "powerprofilesctl",
        fdo: "PPD",
        legacy: "PPD (legacy)"
    })[root.backend] || root.backend;

    readonly property string statusHint: root.available
        ? "Active: " + root.labelFor(root.profile) + "  ·  " + root.backendLabel
        : "";

    function refresh() {
        statusProcess.running = false;
        statusProcess.running = true;
    }

    function setProfile(name) {
        if (!name || root.profileOptions.indexOf(name) < 0)
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
                    root.profiles = Array.isArray(d.profiles) && d.profiles.length > 0
                        ? d.profiles : root.profileOptions;
                    root.backend = d.backend || "none";
                } catch (e) {
                    root.available = false;
                    root.profile = "";
                    root.profiles = root.profileOptions;
                    root.backend = "none";
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
