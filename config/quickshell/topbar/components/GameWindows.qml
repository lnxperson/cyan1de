pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Detects maximized game windows so the bar can hide only on the active
// workspace of the display that owns them. Detection is intentionally
// conservative: Steam titles publish a
// steam_app_<id> class, and the common standalone launchers/emulators have
// stable app ids. Known desktop apps are excluded before title matching so a
// folder named after a game does not hide the bar. Extra app ids or class names
// can be added, one regular expression per line, to
// ~/.config/quickshell/game-apps.txt.
QtObject {
    id: root

    property var customPatterns: []

    readonly property var builtinPatterns: [
        /^steam_app_\d+$/i,
        /^(lutris|heroic|bottles|wine|proton|dosbox|retroarch|rpcs3|yuzu|ryujinx|pcsx2|dolphin|citra|ppsspp|duckstation|melonds|mgba)$/i,
        /^(geometrydash|geometry dash|minecraft|terraria|balatro|stardew valley|osu!?|roblox)$/i
    ]

    // A window title alone is not enough: a file manager showing a folder named
    // "Geometry Dash" would otherwise hide the bar. Exclude known desktop apps
    // before any title matching is attempted.
    readonly property var nonGamePatterns: [
        /^(org\.)?(gnome\.)?(nautilus|nemo|thunar|pcmanfm|dolphin|caja|thunar)$/i,
        /^(firefox|zen|chromium|google-chrome|chrome|brave|vivaldi)$/i,
        /^(alacritty|kitty|konsole|gnome-terminal|xterm|wezterm|foot)$/i,
        /^(discord|telegram|signal|whatsapp|slack)$/i,
        /^(code|gedit|org\.gnome\.texteditor|org\.gnome\.gedit)$/i
    ]

    function matchesAny(patterns, value) {
        if (typeof value !== "string" || !value)
            return false;
        const text = value.toLowerCase();
        for (let i = 0; i < patterns.length; i++) {
            if (patterns[i].test(text))
                return true;
        }
        return false;
    }

    // Each monitor has its own active workspace. Returning it lets the bar hide
    // only while the game's workspace is actually shown on this display.
    function activeWorkspaceOn(screen) {
        if (!screen)
            return null;
        const monitor = Hyprland.monitorFor(screen);
        const monitorName = monitor ? monitor.name : screen.name;
        const workspaces = Hyprland.workspaces.values || [];

        for (let i = 0; i < workspaces.length; i++) {
            const workspace = workspaces[i];
            if (!workspace || !workspace.active)
                continue;

            const wsMonitor = workspace.monitor;
            if (monitor && wsMonitor) {
                if (wsMonitor.id === monitor.id || wsMonitor.name === monitor.name)
                    return workspace;
                continue;
            }
            if (wsMonitor && wsMonitor.name === monitorName)
                return workspace;
        }
        return null;
    }

    function workspaceParts(workspace) {
        if (!workspace || typeof workspace !== "object")
            return null;
        const id = workspace.id;
        const name = workspace.name;
        return {
            id: id !== undefined && id !== null ? String(id) : null,
            name: typeof name === "string" && name ? name : null
        };
    }

    function sameWorkspace(first, second) {
        const a = root.workspaceParts(first);
        const b = root.workspaceParts(second);
        if (!a || !b)
            return false;
        if (a.id !== null && b.id !== null)
            return a.id === b.id;
        if (a.name !== null && b.name !== null)
            return a.name === b.name;
        return false;
    }

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
        const appId = wayland ? wayland.appId : "";
        const className = ipc.class || ipc.initialClass || "";

        // An app id/class that belongs to a normal desktop application wins
        // over any coincidental title match, including folder names.
        if (root.matchesAny(root.nonGamePatterns, appId)
            || root.matchesAny(root.nonGamePatterns, className))
            return false;

        const values = [appId, className, toplevel.title || ""];

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
        const activeWorkspace = root.activeWorkspaceOn(screen);
        if (!activeWorkspace)
            return false;
        const toplevels = Hyprland.toplevels.values || [];

        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const wayland = toplevel.wayland;
            if (!wayland || !root.isGame(toplevel))
                continue;

            const ipc = toplevel.lastIpcObject || {};
            if (!root.sameWorkspace(activeWorkspace,
                                    toplevel.workspace || ipc.workspace))
                continue;
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
