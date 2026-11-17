import QtQuick
import Quickshell
import Quickshell.Wayland

// Draws the desktop wallpaper directly on the Wayland background layer.
// Replaces hyprpaper; updates live when settings.json changes.
ShellRoot {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            exclusiveZone: 0
            color: Theme.bg

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-background"

            Image {
                anchors.fill: parent
                asynchronous: true
                cache: false
                smooth: true
                // Only rerender when the path or mode actually changes.
                source: Theme.wallpaper.length > 0 ? "file://" + Theme.wallpaper : ""
                fillMode: Theme.wallpaperMode === "fit"
                    ? Image.PreserveAspectFit
                    : (Theme.wallpaperMode === "stretch" ? Image.Stretch : Image.PreserveAspectCrop)
            }
        }
    }
}
