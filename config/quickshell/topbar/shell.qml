//@ pragma UseQApplication
// Required: system-tray right-click menus use QtWidgets QMenu.
import QtQuick
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
    id: root

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

    // One-shot-per-cycle low battery warnings, independent of any screen.
    BatteryMonitor { id: batteryMonitor }

    // Software dimmers are created before the bars so the bars stay above
    // them in the Wayland top layer.
    Variants {
        model: Quickshell.screens

        SoftwareDim {
            property var modelData
            screen: modelData
        }
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

    Variants {
        model: root.panelScreens

        Bar {
            property var modelData
            screen: modelData
            cursorX: root.cursorX
            cursorY: root.cursorY
        }
    }

    // The wrap lives on its own full-screen surface so it can hug the display
    // without expanding the bar's exclusive zone.
    Variants {
        model: root.panelScreens

        WrapFrame {
            property var modelData
            screen: modelData
        }
    }
}
