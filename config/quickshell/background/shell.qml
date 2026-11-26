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
            // Cover the whole output, including the area reserved by the
            // top bar. A zone of 0 would push the wallpaper below the bar.
            exclusiveZone: -1
            color: Theme.bg

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell-background"

            Image {
                anchors.fill: parent
                asynchronous: true
                cache: false
                smooth: true
                // Only rerender when the path or mode actually changes.
                source: Theme.resolvedWallpaper.length > 0 ? "file://" + Theme.resolvedWallpaper : ""
                fillMode: Theme.wallpaperMode === "fit"
                    ? Image.PreserveAspectFit
                    : (Theme.wallpaperMode === "stretch" ? Image.Stretch : Image.PreserveAspectCrop)
            }

            // Wallpapers from settings.json can carry a slideshow. Rotate
            // through them on a timer while the background session runs.
            property var wallpaperSlides: Theme.wallpaperSlides
            property int wallpaperSlideIndex: 0
            Timer {
                id: wallpaperSlideTimer
                interval: 300000
                repeat: true
                running: true
                onTriggered: {
                    const slides = Theme.wallpaperSlides || [];
                    if (slides.length < 2)
                        return;
                    const next = slides[(wallpaperSlideIndex + 1) % slides.length];
                    const path = Theme.resolveWallpaperPath(typeof next === "object"
                        ? (next.path || "")
                        : String(next));
                    Theme.data.wallpaper = path;
                    wallpaperSlideIndex = (wallpaperSlideIndex + 1) % slides.length;
                }
            }
        }
    }
}
