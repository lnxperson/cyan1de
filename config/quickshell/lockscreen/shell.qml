import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "components"

ShellRoot {
    id: root

    Component.onCompleted: Quickshell.watchFiles = false

    readonly property string home: Quickshell.env("HOME") || ""
    property string wallpaperPath: ""
    readonly property string resolvedWallpaperPath: wallpaperPath.startsWith("~/") && home !== ""
        ? home + wallpaperPath.substring(1)
        : wallpaperPath

    function loadWallpaper() {
        try {
            const data = JSON.parse(settingsFile.text());
            wallpaperPath = data.wallpaper || "";
        } catch (e) {
            wallpaperPath = "";
        }
    }

    FileView {
        id: settingsFile
        path: root.home + "/.config/quickshell/settings.json"
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.loadWallpaper()
    }

    // Lives outside the lock surfaces so it survives their destruction.
    Timer {
        id: quitTimer
        interval: 120
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
                wallpaperPath: root.resolvedWallpaperPath
                onUnlocked: quitTimer.restart()
            }
        }
    }
}
