import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Read-only list of recent notifications recorded by the notifications daemon.
// The daemon owns the history file; removal goes through its IPC so the file is
// never written by two processes at once.
ColumnLayout {
    id: root

    property var entries: []
    property string lastText: ""
    property bool awaitingChange: false

    readonly property string historyPath: Quickshell.env("HOME") + "/.config/quickshell/notification-history.json"

    spacing: 8
    visible: Theme.calendarNotifications

    function reloadHistory() {
        try {
            historyFile.reload();
            const text = historyFile.text();
            if (!text || text === root.lastText)
                return;
            root.lastText = text;
            const parsed = JSON.parse(text);
            root.entries = Array.isArray(parsed) ? parsed : [];
            root.awaitingChange = false;
        } catch (e) {
            // Keep the previous list if the file is mid-write or missing.
        }
    }

    function clearAll() {
        if (root.entries.length === 0)
            return;
        root.awaitingChange = true;
        root.entries = [];
        Quickshell.execDetached([
            "qs", "ipc", "-c", "notifications", "call", "notifications", "clearHistory"
        ]);
    }

    function removeEntry(id) {
        root.awaitingChange = true;
        root.entries = root.entries.filter(entry => Number(entry && entry.id) !== Number(id));
        Quickshell.execDetached([
            "qs", "ipc", "-c", "notifications", "call", "notifications",
            "removeHistory", String(id)
        ]);
    }

    function formatTime(value) {
        const date = new Date(Number(value) * 1000);
        return isNaN(date.getTime()) ? "" : Qt.formatDateTime(date, "HH:mm");
    }

    function urgencyColor(value) {
        if (value === 2)
            return Theme.red;
        if (value === 0)
            return Theme.dim;
        return Theme.accentAlt;
    }

    Timer {
        interval: 800
        repeat: true
        running: true
        onTriggered: root.reloadHistory()
    }

    // If an IPC removal fails, stop suppressing reloads so the UI resyncs.
    Timer {
        interval: 5000
        repeat: false
        running: root.awaitingChange
        onTriggered: {
            root.awaitingChange = false;
            root.reloadHistory();
        }
    }

    Component.onCompleted: root.reloadHistory()

    FileView {
        id: historyFile
        path: root.historyPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.reloadHistory()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "NOTIFICATIONS"
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Theme.subtext
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.entries.length
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }

        Rectangle {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 18
            radius: Theme.controlRadius
            color: clearArea.containsMouse ? Theme.hover : Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border
            visible: root.entries.length > 0

            Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: Theme.mono
                font.pixelSize: 10
                color: clearArea.containsMouse ? Theme.red : Theme.subtext
            }

            MouseArea {
                id: clearArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.clearAll()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredWidth: 280
        Layout.preferredHeight: 258
        Layout.maximumHeight: 258
        clip: true
        model: root.entries
        spacing: 6

        delegate: Rectangle {
            required property var modelData

            width: ListView.view.width - 4
            x: 2
            implicitHeight: content.implicitHeight + 16
            radius: Theme.panelRadius
            color: Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: modelData.appName || "Notification"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: root.urgencyColor(modelData.urgency)
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        textFormat: Text.PlainText
                    }

                    Text {
                        text: root.formatTime(modelData.time)
                        font.family: Theme.mono
                        font.pixelSize: 9
                        color: Theme.dim
                        visible: text !== ""
                    }

                    Rectangle {
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        radius: 4
                        color: entryCloseArea.containsMouse ? Theme.hover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.mono
                            font.pixelSize: 9
                            color: entryCloseArea.containsMouse ? Theme.red : Theme.dim
                        }

                        MouseArea {
                            id: entryCloseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeEntry(modelData.id)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.summary || ""
                    font.family: Theme.mono
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.text
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.body || ""
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.subtext
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    visible: text !== ""
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "No notifications yet"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.dim
            visible: root.entries.length === 0
        }
    }
}
