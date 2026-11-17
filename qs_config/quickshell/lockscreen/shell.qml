import QtQuick
import Quickshell
import Quickshell.Wayland
import "components"

ShellRoot {
    Component.onCompleted: Quickshell.watchFiles = false

    // Lives outside the lock surfaces so it survives their destruction.
    Timer {
        id: quitTimer
        interval: 300
        onTriggered: Qt.quit()
    }

    WlSessionLock {
        id: sessionLock
        locked: true

        WlSessionLockSurface {
            id: surface
            color: "#05070b"

            LockScreen {
                width: surface.width
                height: surface.height
                lock: sessionLock
                screen: surface.screen
                onUnlocked: quitTimer.restart()
            }
        }
    }
}
