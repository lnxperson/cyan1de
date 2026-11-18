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
    property var pillData: barData.pills || ({})
    property var hyprData: data.hypr || ({})
    property string lastText: ""

    // Typography
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string mono: "JetBrainsMono Nerd Font Mono"

    function mixColor(a, b, amount) {
        const t = Math.min(1, Math.max(0, amount));
        return Qt.rgba(
            a.r * (1 - t) + b.r * t,
            a.g * (1 - t) + b.g * t,
            a.b * (1 - t) + b.b * t,
            1
        );
    }

    readonly property bool lightMode: data.themeMode === "light"

    readonly property color darkBg: "#0a0c11"
    readonly property color darkSubtext: "#8b96ab"
    readonly property color darkDim: "#5f6a80"
    readonly property color accentInk: "#0b3b5a"
    readonly property color baseSurface: barData.surface || "#11141b"
    readonly property color baseSurfaceAlt: barData.pill || "#171b24"
    readonly property color basePill: barData.pill || "#121722"
    readonly property color baseBorder: barData.pillBorder || "#232a37"
    readonly property color basePillBorder: barData.pillBorder || "#2b3547"
    readonly property color baseAccent: barData.accent || "#7cc7f5"
    readonly property color baseText: barData.text || "#cdd6e6"

    // Palette shared by every Quickshell panel. Dark mode uses the saved
    // colours as-is; light mode derives soft paper tones from them so the
    // existing colour controls still affect both modes.
    readonly property color white: "#ffffff"
    readonly property color lightBg: mixColor(darkBg, white, 0.94)
    readonly property color lightSurface: baseSurface
    readonly property color lightSurfaceAlt: basePill
    readonly property color lightBorder: mixColor(baseBorder, white, 0.62)
    readonly property color lightText: "#1c2430"
    readonly property color lightSubtext: "#4b5563"
    readonly property color lightDim: "#6b7280"
    readonly property color lightAccent: mixColor(baseAccent, accentInk, 0.42)

    readonly property color bg: lightMode ? lightBg : darkBg
    readonly property color surface: lightMode ? lightSurface : baseSurface
    readonly property color surfaceAlt: lightMode ? lightSurfaceAlt : baseSurfaceAlt
    readonly property color border: lightMode ? lightBorder : baseBorder
    readonly property color text: lightMode ? lightText : baseText
    readonly property color subtext: lightMode ? lightSubtext : darkSubtext
    readonly property color dim: lightMode ? lightDim : darkDim
    readonly property color accent: lightMode ? lightAccent : baseAccent
    readonly property color accentSoft: mixColor(accent, white, 0.45)
    readonly property color accentAlt: mixColor(accent, white, 0.20)
    readonly property color hover: Qt.lighter(surfaceAlt, 1.14)
    readonly property color active: mixColor(surfaceAlt, accent, 0.18)
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
    readonly property color pill: lightMode ? lightSurfaceAlt : basePill
    readonly property color pillFill: Qt.rgba(pill.r, pill.g, pill.b, pillOpacity)
    readonly property color pillBorder: lightMode ? lightBorder : basePillBorder
    readonly property int barHeight: Math.max(44, pillHeight + 10)

    // Pill positions, stored as fractions of the available bar width.
    readonly property real pillLeft: pillData.left !== undefined ? pillData.left : 0
    readonly property real pillCenter: pillData.center !== undefined ? pillData.center : 0.5
    readonly property real pillRight: pillData.right !== undefined ? pillData.right : 1

    // Shared corner radius for all Quickshell panels.
    readonly property int panelRadius: pillRadius

    // Wallpaper
    readonly property string wallpaper: data.wallpaper || ""
    readonly property string wallpaperMode: data.wallpaperMode || "crop"
    // settings.json may store "~" for portability; QML needs a real path.
    readonly property string resolvedWallpaper: wallpaper.startsWith("~/")
        ? (Quickshell.env("HOME") || "") + wallpaper.substring(1)
        : wallpaper

    // Notifications
    property var notifyData: data.notifications || ({})
    readonly property string notifyPosition: notifyData.position || "top-right"
    readonly property int notifyTimeout: notifyData.timeout !== undefined ? notifyData.timeout : 5000
    readonly property int notifyMaxVisible: notifyData.maxVisible !== undefined ? notifyData.maxVisible : 4
    readonly property bool notifyPauseOnHover: notifyData.pauseOnHover !== undefined ? notifyData.pauseOnHover : true
    readonly property bool notifyPersistent: notifyData.persistent !== undefined ? notifyData.persistent : false
    readonly property bool notifyShowAppIcon: notifyData.showAppIcon !== undefined ? notifyData.showAppIcon : true
    readonly property bool notifyShowAppName: notifyData.showAppName !== undefined ? notifyData.showAppName : true

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
