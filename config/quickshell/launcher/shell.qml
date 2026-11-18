import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Replacement for fuzzel: a Quickshell application launcher.
// Runs as a daemon and is toggled over IPC by SUPER+SPACE.
ShellRoot {
    id: root

    property bool shown: false
    property string query: ""
    property int selected: 0

    readonly property var results: {
        const source = DesktopEntries.applications.values;
        const q = root.query.trim().toLowerCase();
        const matches = [];

        for (let i = 0; i < source.length; i++) {
            const entry = source[i];
            if (!entry || entry.noDisplay)
                continue;

            if (q === "") {
                matches.push(entry);
                continue;
            }

            const name = (entry.name || "").toLowerCase();
            const generic = (entry.genericName || "").toLowerCase();
            const comment = (entry.comment || "").toLowerCase();

            if (name.includes(q) || generic.includes(q) || comment.includes(q))
                matches.push(entry);
        }

        function score(entry) {
            if (q === "")
                return 0;
            const name = (entry.name || "").toLowerCase();
            if (name.startsWith(q))
                return 0;
            if (name.includes(q))
                return 1;
            return 2;
        }

        matches.sort(function (a, b) {
            return score(a) - score(b) || a.name.localeCompare(b.name);
        });

        return matches;
    }

    function open() {
        if (root.shown) {
            focusTimer.restart();
            return;
        }

        field.text = "";
        root.query = "";
        root.selected = 0;
        root.shown = true;
        focusTimer.restart();
    }

    function close() {
        root.shown = false;
    }

    function toggle() {
        if (root.shown)
            root.close();
        else
            root.open();
    }

    function move(delta) {
        if (root.results.length === 0)
            return;

        root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + delta));
        list.positionViewAtIndex(root.selected, ListView.Contain);
    }

    function launchCurrent() {
        const entry = root.results[root.selected];
        if (!entry)
            return;

        const command = Array.from(entry.command);
        if (command.length === 0)
            return;

        root.close();

        if (entry.runInTerminal)
            Quickshell.execDetached(["alacritty", "-e"].concat(command));
        else
            Quickshell.execDetached(command);
    }

    onResultsChanged: root.selected = 0

    IpcHandler {
        target: "launcher"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: field.forceActiveFocus()
    }

    PanelWindow {
        id: window

        visible: root.shown
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"
        focusable: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: root.shown
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            anchors.fill: card
            anchors.margins: -1
            radius: card.radius + 1
            color: "#66000000"
            z: -1
        }

        Rectangle {
            id: card

            width: 640
            height: 500
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            radius: Theme.panelRadius
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "󰍉"
                        font.family: Theme.font
                        font.pixelSize: 18
                        color: Theme.dim
                    }

                    TextField {
                        id: field

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: "Search applications…"
                        placeholderTextColor: Theme.dim
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 15
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        leftPadding: 0
                        rightPadding: 0
                        background: Rectangle { color: "transparent" }

                        onTextChanged: root.query = text
                        onAccepted: root.launchCurrent()

                        Keys.onEscapePressed: root.close()
                        Keys.onUpPressed: root.move(-1)
                        Keys.onDownPressed: root.move(1)
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_PageUp) {
                                root.move(-6);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                root.move(6);
                                event.accepted = true;
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: list

                        anchors.fill: parent
                        clip: true
                        model: root.results
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool highlighted: root.selected === index
                            readonly property string iconName: row.modelData.icon || ""
                            // Nerd Font glyphs live outside the BMP (or in the
                            // private use area); render those as text instead
                            // of handing them to the icon provider.
                            readonly property bool iconIsGlyph: iconName.length > 0 &&
                                iconName.charCodeAt(0) > 0xd7ff

                            width: list.width
                            height: 46
                            radius: 9
                            color: highlighted
                                ? Theme.active
                                : (rowMouse.containsMouse ? Theme.hover : "transparent")

                            Behavior on color { ColorAnimation { duration: 90 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    visible: row.iconIsGlyph
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    text: row.iconName
                                    font.family: Theme.mono
                                    font.pixelSize: 20
                                    color: Theme.accent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Image {
                                    visible: !row.iconIsGlyph
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    sourceSize.width: 52
                                    sourceSize.height: 52
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    source: Quickshell.iconPath(row.iconName, "application-x-executable")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.name
                                        font.family: Theme.mono
                                        font.pixelSize: 13
                                        font.weight: row.highlighted ? Font.DemiBold : Font.Normal
                                        color: row.highlighted ? Theme.accentSoft : Theme.text
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: row.modelData.genericName || row.modelData.comment || ""
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                        color: Theme.subtext
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        root.selected = row.index;
                                }

                                onClicked: {
                                    root.selected = row.index;
                                    root.launchCurrent();
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: root.query === ""
                            ? "Loading applications…"
                            : "No applications match “" + root.query + "”"
                        font.family: Theme.mono
                        font.pixelSize: 12
                        color: Theme.subtext
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: root.results.length + (root.results.length === 1 ? " application" : " applications")
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.dim
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "↑↓ navigate    ↵ open    esc close"
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.dim
                    }
                }
            }
        }
    }
}
