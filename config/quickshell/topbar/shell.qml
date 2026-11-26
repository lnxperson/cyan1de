//@ pragma UseQApplication
// Required: system-tray right-click menus use QtWidgets QMenu.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "components"

ShellRoot {
    id: root

    readonly property string replayScript: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/recorder/replay.sh"

    // Global cursor position from Hyprland, used only by the island layout's
    // edge-reveal behaviour. -1 means unknown, which keeps the bar visible.
    property int cursorX: -1
    property int cursorY: -1

    Process {
        id: cursorProbe
        command: ["hyprctl", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length < 2)
                    return;
                const x = parseInt(parts[0], 10);
                const y = parseInt(parts[1], 10);
                if (!isNaN(x) && !isNaN(y)) {
                    root.cursorX = x;
                    root.cursorY = y;
                }
            }
        }
    }

    // Singleton timers do not tick on 0.3.2, so poll from the shell root.
    // Only island needs cursor tracking, so the process stays idle otherwise.
    Timer {
        interval: 120
        repeat: true
        running: Theme.barLayout === "island"
        onTriggered: {
            if (!cursorProbe.running)
                cursorProbe.running = true;
        }
    }

    // Theme's singleton-internal Timer does not tick on Quickshell 0.3.2, so
    // drive its settings.json reload from the shell root where timers work.
    Timer {
        interval: 150
        repeat: true
        running: true
        onTriggered: Theme.reload()
    }

    // Singleton Timers do not tick on 0.3.2, so refresh PPD availability here.
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: PowerProfileControl.refresh()
    }

    // State files can be deleted without a watcher event, so poll both capture
    // indicators from the shell root. The pill should follow the shortcut
    // immediately, not wait for the next ensure cycle.
    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            ReplayState.refresh();
            IdleState.refresh();
        }
    }

    // The rolling replay buffer is a detached process so it survives bar
    // restarts. The helper is idempotent and restarts only when capture
    // settings change.
    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: Quickshell.execDetached([root.replayScript, "ensure"]);
    }

    // One-shot-per-cycle low battery warnings, independent of any screen.
    BatteryMonitor { id: batteryMonitor }

    // Hyprland draws the software cursor after every layer surface, so the
    // dim overlay cannot cover it. The helper switches a dimmed Xcursor theme
    // when the cursor is over a software-brightness monitor.
    Process {
        id: cursorDimProcess
        command: [Brightness.cursorDimScript]
    }

    Timer {
        interval: 600
        repeat: true
        running: true
        onTriggered: {
            if (!cursorDimProcess.running)
                cursorDimProcess.running = true;
        }
    }

    Component.onCompleted: {
        cursorDimProcess.running = true;
        Quickshell.execDetached([root.replayScript, "ensure"]);
        ReplayState.refresh();
        IdleState.refresh();
    }

    readonly property var panelScreens: {
        const screens = Quickshell.screens;
        const want = Theme.barDisplay;
        if (!want || want === "all")
            return screens;
        const matched = [];
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === want)
                matched.push(screens[i]);
        }
        // Keep a panel visible if the saved display is disconnected.
        return matched.length > 0 ? matched : screens;
    }

    // Keyboard shortcuts are dispatched over IPC to the bar on the focused
    // monitor, or to whichever bar already owns an open popup.
    property var bars: []

    function registerBar(bar) {
        if (root.bars.indexOf(bar) < 0)
            root.bars.push(bar);
    }

    function unregisterBar(bar) {
        const index = root.bars.indexOf(bar);
        if (index >= 0)
            root.bars.splice(index, 1);
    }

    function targetBar() {
        for (let i = 0; i < root.bars.length; i++) {
            if (root.bars[i].activePopup !== null)
                return root.bars[i];
        }

        const monitor = Hyprland.focusedMonitor;
        const focusedName = monitor ? monitor.name : "";
        for (let i = 0; i < root.bars.length; i++) {
            const bar = root.bars[i];
            if (bar.visible && (!focusedName
                || (bar.screen && bar.screen.name === focusedName)))
                return bar;
        }

        for (let i = 0; i < root.bars.length; i++) {
            if (root.bars[i].visible)
                return root.bars[i];
        }
        return root.bars.length ? root.bars[0] : null;
    }

    IpcHandler {
        target: "topbar"

        function cycleAction(): void {
            const bar = root.targetBar();
            if (bar)
                bar.cycleActionPopup();
        }

        function calendar(): void {
            const bar = root.targetBar();
            if (bar)
                bar.toggleCalendar();
        }

        function power(): void {
            const bar = root.targetBar();
            if (bar)
                bar.togglePopup(bar.actionPopupHost.powerPopup);
        }

        function close(): void {
            const bar = root.targetBar();
            if (bar)
                bar.closePopup();
        }

    }

    // The wrap lives on its own full-screen surface so it can hug the display
    // without expanding the bar's exclusive zone. It shares the bar's overlay
    // layer and is created first so the bar paints above it.
    Variants {
        model: root.panelScreens

        WrapFrame {
            property var modelData
            screen: modelData
        }
    }

    Variants {
        model: root.panelScreens

        Bar {
            property var modelData
            shellRoot: root
            screen: modelData
            cursorX: root.cursorX
            cursorY: root.cursorY
        }
    }

    // Created last so the overlay-layer dimmer paints above the bar and wrap.
    Variants {
        model: Quickshell.screens

        SoftwareDim {
            property var modelData
            screen: modelData
        }
    }
}
