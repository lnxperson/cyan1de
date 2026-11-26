pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Optional Arch update count. Prefers checkupdates (pacman-contrib) and falls
// back to pacman -Qu. Timers live in shell.qml because singleton timers do not
// tick reliably on the pinned Quickshell build.
QtObject {
    id: root

    property int count: -1
    property var packages: []
    property bool busy: false
    property bool available: false
    property bool supported: true
    property string lastChecked: ""

    function refresh() {
        if (process.running)
            return;
        root.supported = true;
        root.busy = true;
        process.running = true;
    }

    function clear() {
        root.count = -1;
        root.packages = [];
        root.busy = false;
        root.available = false;
        root.lastChecked = "";
    }

    property Process process: Process {
        command: ["sh", "-c",
            "if command -v checkupdates >/dev/null 2>&1; then checkupdates; "
            + "elif command -v pacman >/dev/null 2>&1; then pacman -Qu; "
            + "else echo __CYAN1DE_UPDATES_UNAVAILABLE__; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                const unavailable = text.indexOf("__CYAN1DE_UPDATES_UNAVAILABLE__") >= 0;
                const lines = text.split("\n")
                    .map(line => line.trim())
                    .filter(line => line.length > 0
                        && line.indexOf("__CYAN1DE_UPDATES_UNAVAILABLE__") < 0);
                root.packages = lines;
                root.count = unavailable ? -1 : lines.length;
                root.supported = !unavailable;
            }
        }

        onExited: function (exitCode) {
            root.busy = false;
            root.available = exitCode === 0 && root.supported;
            root.lastChecked = Qt.formatDateTime(new Date(), "HH:mm");
        }
    }
}
