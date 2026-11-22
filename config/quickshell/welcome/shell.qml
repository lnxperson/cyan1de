import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// cyan1de welcome guide. Shown shortly after login until the user disables it
// in the bottom-left corner. Dismissing it quits this process; the launcher
// can start a fresh daemon on demand.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string statePath: home + "/.config/quickshell/welcome.json"

    property bool shown: false
    property real reveal: 0
    property bool closing: false
    property bool disabledWelcome: false
    property bool manualOpen: false
    property bool quitting: false

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    readonly property var sections: [
        {
            title: "GETTING STARTED",
            items: [
                { keys: "SUPER + SPACE", text: "Search and launch applications." },
                { keys: "SUPER + ,", text: "Open Settings: wallpaper, panel, input, monitors, notifications." },
                { keys: "SUPER + .", text: "Open the emoji picker and paste into the focused app." },
                { keys: "SUPER + CTRL + P", text: "Toggle performance mode: stop Quickshell except the lockscreen." },
                { keys: "SUPER + L", text: "Lock the session using PAM and fingerprint." },
                { keys: "SUPER + M", text: "Open the session / exit menu." }
            ]
        },
        {
            title: "WINDOWS & WORKSPACES",
            items: [
                { keys: "SUPER + 1…0", text: "Jump to workspace 1–10." },
                { keys: "SUPER + SHIFT + 1…0", text: "Send the focused window to that workspace." },
                { keys: "SUPER + SCROLL", text: "Cycle through existing workspaces." },
                { keys: "SUPER + ARROWS", text: "Focus a window by direction." },
                { keys: "SUPER + V / P / J", text: "Toggle floating / pseudo-tile / flip the split." },
                { keys: "SUPER + DRAG", text: "Move a floating window; right-drag resizes it." }
            ]
        },
        {
            title: "SCRATCHPAD & SCREENSHOTS",
            items: [
                { keys: "SUPER + S", text: "Toggle the scratchpad; SHIFT + S sends a window there." },
                { keys: "PRINT", text: "Region to clipboard." },
                { keys: "SUPER + PRINT", text: "Screenshot the active display." },
                { keys: "SHIFT + PRINT", text: "Region to a file." }
            ]
        },
        {
            title: "THE DESKTOP",
            items: [
                { keys: "PANEL", text: "Three floating pills: workspaces, clock, tray and system controls." },
                { keys: "OSD", text: "Volume, brightness, keyboard backlight and media feedback." },
                { keys: "NOTIFICATIONS", text: "Pop in at the top-right; click to dismiss and use buttons to act." },
                { keys: "CONFIG", text: "This desktop is cyan1de. Settings → Apply writes the Hyprland files." }
            ]
        }
    ]

    function loadState() {
        stateFile.reload();
        let disabled = false;
        try {
            const raw = stateFile.text();
            if (raw && raw.trim().length > 0) {
                const parsed = JSON.parse(raw);
                disabled = parsed.disabled === true;
            }
        } catch (e) {
            disabled = false;
        }
        root.disabledWelcome = disabled;
    }

    function setDisabledWelcome(value: bool): void {
        root.disabledWelcome = value;
        stateWriter.setText(JSON.stringify({ disabled: value }, null, 2) + "\n");
        if (value)
            root.close();
    }

    function open() {
        quitTimer.stop();
        root.loadState();
        root.manualOpen = true;
        root.quitting = false;
        root.closing = false;
        root.shown = true;
        root.reveal = 1;
    }

    function close() {
        if (root.quitting || root.closing)
            return;
        root.quitting = true;
        root.closing = true;
        root.reveal = 0;
        // Give the exit animation and any pending state-file write a moment to
        // land before the process exits.
        quitTimer.restart();
    }

    function toggle() {
        if (root.shown && !root.closing)
            root.close();
        else
            root.open();
    }

    Component.onCompleted: {
        root.loadState();
        if (!root.disabledWelcome)
            startupTimer.restart();
    }

    Timer {
        id: startupTimer
        interval: 900
        onTriggered: {
            if (!root.manualOpen && !root.disabledWelcome) {
                root.shown = true;
                root.reveal = 1;
            }
        }
    }

    Timer {
        id: quitTimer
        interval: Theme.motionFast + 80
        onTriggered: {
            shown = false;
            Qt.quit();
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.loadState()
    }

    FileView {
        id: stateWriter
        path: root.statePath
        blockWrites: false
        atomicWrites: true
        printErrors: false
    }

    IpcHandler {
        target: "welcome"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shown
        onActivated: root.close()
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
        WlrLayershell.namespace: "quickshell-welcome-surface"

        Loader {
            anchors.fill: card
            z: 1000
            source: "SoftwareDimOverlay.qml"
            onLoaded: item.radius = Qt.binding(function() { return card.radius; })
        }
        WlrLayershell.keyboardFocus: root.shown
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        // Clicking outside the card dismisses the guide.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            anchors.fill: card
            anchors.margins: -1
            radius: card.radius + 1
            color: "#66000000"
            opacity: root.reveal
            z: -1
        }

        Rectangle {
            id: card

            width: Math.min(900, parent.width - 40)
            height: Math.min(640, parent.height - 40)
            anchors.centerIn: parent
            radius: Theme.panelRadius
            color: Theme.panelFill(Theme.surface, "welcome")
            border.width: 1
            border.color: Theme.border

            opacity: root.reveal
            scale: Theme.motionEnterScale + (1 - Theme.motionEnterScale) * root.reveal
            transform: Translate {
                y: -(1 - root.reveal) * Theme.motionEnterOffset
            }

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 11
                        color: Theme.active
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "󰒓"
                            font.family: Theme.font
                            font.pixelSize: 20
                            color: Theme.accent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: "Welcome to cyan1de"
                            font.family: Theme.mono
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "A compact Hyprland + Quickshell desktop — here is the short version."
                            font.family: Theme.mono
                            font.pixelSize: 11
                            color: Theme.subtext
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 8
                        color: closeMouse.containsMouse ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: closeMouse.containsMouse ? Theme.border : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.font
                            font.pixelSize: 15
                            color: Theme.subtext
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.close()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                Flickable {
                    id: flick

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: contentColumn.implicitHeight + 8

                    ColumnLayout {
                        id: contentColumn

                        width: flick.width
                        spacing: 14

                        Repeater {
                            model: root.sections

                            delegate: ColumnLayout {
                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.accentAlt
                                }

                                Repeater {
                                    model: modelData.items

                                    delegate: RowLayout {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: 10

                                        Rectangle {
                                            Layout.preferredWidth: 196
                                            Layout.preferredHeight: 24
                                            radius: 6
                                            color: Theme.active
                                            border.width: 1
                                            border.color: Theme.border

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.keys
                                                font.family: Theme.mono
                                                font.pixelSize: 10
                                                color: Theme.accentSoft
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.text
                                            font.family: Theme.mono
                                            font.pixelSize: 11
                                            color: Theme.subtext
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        id: disableControl

                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 28
                        radius: 7
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 18
                                radius: 9
                                color: root.disabledWelcome ? Theme.accent : Theme.border

                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                                Rectangle {
                                    x: root.disabledWelcome ? 17 : 2
                                    y: 2
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: Theme.text

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Theme.motionFast
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Disable welcome message"
                                font.family: Theme.mono
                                font.pixelSize: 11
                                color: Theme.subtext
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.setDisabledWelcome(!root.disabledWelcome)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 86
                        Layout.preferredHeight: 30
                        radius: 8
                        color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: "Got it"
                            font.family: Theme.mono
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.bg
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.close()
                        }
                    }
                }
            }
        }
    }
}
