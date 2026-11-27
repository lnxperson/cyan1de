pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Detects maximized game windows so the bar can hide only on the display that
// owns them. Detection is intentionally conservative: Steam titles publish a
// steam_app_<id> class, and the common standalone launchers/emulators have
// stable app ids. Extra app ids or class names can be added, one regular
// expression per line, to ~/.config/quickshell/game-apps.txt.
QtObject {
    id: root

    property var customPatterns: []

    readonly property var builtinPatterns: [
        /^steam_app_\d+$/i,
        /^(lutris|heroic|bottles|wine|proton|dosbox|retroarch|rpcs3|yuzu|ryujinx|pcsx2|dolphin|citra|ppsspp|duckstation|melonds|mgba)$/i,
        /^(geometrydash|geometry dash|minecraft|terraria|balatro|stardew valley|osu!?|roblox)$/i
    ]

    function loadCustomPatterns() {
        let patterns = [];
        const text = customFile.text ? String(customFile.text() || "") : "";
        const lines = text.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (!line || line.charAt(0) === "#")
                continue;
            try {
                patterns.push(new RegExp(line, "i"));
            } catch (error) {
                // Ignore malformed user patterns instead of breaking the bar.
            }
        }
        root.customPatterns = patterns;
    }

    property FileView customFile: FileView {
        path: (Quickshell.env("HOME") || "")
            + "/.config/quickshell/game-apps.txt"
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.loadCustomPatterns()
    }

    function isGame(toplevel) {
        if (!toplevel)
            return false;
        const wayland = toplevel.wayland;
        const ipc = toplevel.lastIpcObject || {};
        const values = [
            wayland ? wayland.appId : "",
            toplevel.title || "",
            ipc.class || ipc.initialClass || ""
        ];

        // Match each field separately: anchored patterns must not be defeated
        // by other fields (title, class) appended to the same string.
        for (let i = 0; i < values.length; i++) {
            const value = values[i];
            if (typeof value !== "string" || !value)
                continue;
            const text = value.toLowerCase();
            for (let j = 0; j < root.builtinPatterns.length; j++) {
                if (root.builtinPatterns[j].test(text))
                    return true;
            }
            for (let j = 0; j < root.customPatterns.length; j++) {
                if (root.customPatterns[j].test(text))
                    return true;
            }
        }
        return false;
    }

    function maximizedOn(screen) {
        if (!screen)
            return false;
        const monitor = Hyprland.monitorFor(screen);
        const monitorName = monitor ? monitor.name : screen.name;
        const toplevels = Hyprland.toplevels.values || [];

        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const wayland = toplevel.wayland;
            if (!wayland || !root.isGame(toplevel))
                continue;

            const ipc = toplevel.lastIpcObject || {};
            if (!root.coversScreen(toplevel, ipc, screen))
                continue;

            const windowMonitor = toplevel.monitor;
            if (monitor && windowMonitor) {
                if (windowMonitor.id === monitor.id
                    || windowMonitor.name === monitor.name)
                    return true;
                continue;
            }

            if (monitor && typeof ipc.monitor === "number"
                && ipc.monitor === monitor.id)
                return true;
            if (windowMonitor && windowMonitor.name === monitorName)
                return true;
        }
        return false;
    }

    // Hyprland does not always expose a maximized state for games, especially
    // Xwayland titles. Treat a window that fills nearly the whole output as
    // maximized; the bar's reserved strip is only a few percent of the height.
    function coversScreen(toplevel, ipc, screen) {
        const wayland = toplevel.wayland;
        if (wayland.fullscreen || wayland.maximized)
            return true;

        const at = ipc.at;
        const size = ipc.size;
        // Hyprland IPC lists are array-like QJSValues, not JS arrays.
        if (!at || !size || typeof at.length !== "number"
            || typeof size.length !== "number" || at.length < 2
            || size.length < 2)
            return false;

        const left = Number(at[0]);
        const top = Number(at[1]);
        const width = Number(size[0]);
        const height = Number(size[1]);
        if (!isFinite(left) || !isFinite(top) || !isFinite(width)
            || !isFinite(height))
            return false;

        const tolerance = 4;
        return left >= screen.x - tolerance
            && top >= screen.y - tolerance
            && left + width <= screen.x + screen.width + tolerance
            && top + height <= screen.y + screen.height + tolerance
            && width >= screen.width * 0.85
            && height >= screen.height * 0.85;
    }
}
