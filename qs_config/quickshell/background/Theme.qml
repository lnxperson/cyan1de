pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live theme singleton. Reads ~/.config/quickshell/settings.json and updates
// every bound property when the settings app writes a new version.
QtObject {
    id: root

    property var data: ({})
    property var barData: data.bar || ({})
    property var hyprData: data.hypr || ({})
    property string lastText: ""

    // Typography
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string mono: "JetBrainsMono Nerd Font Mono"

    // Palette
    readonly property color bg: "#0a0c11"
    readonly property color surface: barData.surface || "#11141b"
    readonly property color surfaceAlt: "#171b24"
    readonly property color hover: "#1a202b"
    readonly property color active: "#1d2b38"
    readonly property color border: "#232a37"
    readonly property color text: barData.text || "#cdd6e6"
    readonly property color subtext: "#8b96ab"
    readonly property color dim: "#5f6a80"
    readonly property color accent: barData.accent || "#7cc7f5"
    readonly property color accentSoft: barData.accentSoft || "#b9e6ff"
    readonly property color accentAlt: barData.accentAlt || "#68e0c8"
    readonly property color green: "#9bd48b"
    readonly property color yellow: "#e6c384"
    readonly property color red: "#e78a8a"
    readonly property color mauve: "#c6a0e8"

    // Bar geometry
    readonly property int pillHeight: barData.pillHeight !== undefined ? barData.pillHeight : 34
    readonly property int pillRadius: barData.pillRadius !== undefined ? barData.pillRadius : 12
    readonly property int sideMargin: barData.sideMargin !== undefined ? barData.sideMargin : 10
    readonly property int iconSize: barData.iconSize !== undefined ? barData.iconSize : 15
    readonly property int barFontSize: barData.fontSize !== undefined ? barData.fontSize : 12
    readonly property real pillOpacity: barData.pillOpacity !== undefined ? barData.pillOpacity : 1.0
    readonly property color pill: barData.pill || "#121722"
    readonly property color pillFill: Qt.rgba(pill.r, pill.g, pill.b, pillOpacity)
    readonly property color pillBorder: barData.pillBorder || "#2b3547"
    readonly property int barHeight: Math.max(44, pillHeight + 10)

    // Wallpaper
    readonly property string wallpaper: data.wallpaper || ""
    readonly property string wallpaperMode: data.wallpaperMode || "crop"

    function reload() {
        try {
            reader.reload();
            const text = reader.text();
            if (!text || text === lastText)
                return;
            lastText = text;
            data = JSON.parse(text);
        } catch (e) {
            // Keep the previous theme if the file is mid-write or invalid.
        }
    }

    property FileView reader: FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/settings.json"
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.reload()
    }

    // sysfs-free, cheap: one tiny JSON read a few times per second.
    property Timer poll: Timer {
        interval: 150
        repeat: true
        running: true
        onTriggered: root.reload()
    }
}
