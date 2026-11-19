//@ pragma UseQApplication
// Required: system-tray right-click menus use QtWidgets QMenu.
import QtQuick
import Quickshell
import "components"

ShellRoot {
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

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
