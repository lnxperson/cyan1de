import QtQuick
import QtQml.Models
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Quickshell Settings — desktop control center.
// Manages wallpaper (drawn by Quickshell), top bar appearance (live via the
// Theme singleton) and the Hyprland look & feel / autostart / environment.
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string settingsPath: home + "/.config/quickshell/settings.json"
    readonly property string hyprDir: home + "/.config/hypr/hyprland"

    property bool shown: false
    property int page: 0
    property string status: "Changes are saved automatically"
    property color statusColor: Theme.dim

    // Wallpaper
    property string wallpaperPath: ""
    readonly property string resolvedWallpaperPath: resolveWallpaperPath(wallpaperPath)
    property string wallpaperMode: "crop"
    property string themeMode: "dark"
    property var themeColors: ({
        dark: { surface: "#11141b", pill: "#121722" },
        light: { surface: "#f5f6f8", pill: "#ffffff" }
    })
    property var wallpapers: []

    // Bar
    property string barAccent: "#7cc7f5"
    property string barSurface: "#11141b"
    property string barPill: "#121722"
    property string barPillBorder: "#2b3547"
    property int barPillHeight: 34
    property int barPillRadius: 12
    property int barSideMargin: 10
    property int barFontSize: 12
    property int barIconSize: 15
    property real barPillOpacity: 1.0
    property real barPillLeft: 0
    property real barPillCenter: 0.5
    property real barPillRight: 1
    // Three fixed slots shared by every pill. Pills can only ever occupy
    // one of these positions; dropping onto an occupied slot swaps them.
    readonly property var barPillSlots: [0, 0.5, 1]

    // Notifications
    property string notifyPosition: "top-right"
    property int notifyTimeout: 5000
    property int notifyMaxVisible: 4
    property bool notifyPauseOnHover: true
    property bool notifyPersistent: false
    property bool notifyShowAppIcon: true
    property bool notifyShowAppName: true

    // Hyprland look & feel
    property string hyprBorder1: "#0292e3"
    property string hyprBorder2: "#01d6be"
    property bool hyprGradient: true
    property int hyprAngle: 45
    property string hyprInactive: "#0f3246"
    property int hyprBorderSize: 1
    property int hyprRounding: 5
    property int hyprGapsIn: 5
    property int hyprGapsOut: 5

    // Lists
    property var autostart: []
    property var envVars: []

    // Raw contents of the managed Lua files. Kept verbatim so comments,
    // variables and custom blocks survive an Apply round-trip.
    property string inputText: ""
    property string programsText: ""
    property string monitorsText: ""
    property string keybindingsText: ""
    property string rulesText: ""

    // input.lua
    property string inKbLayout: "us"
    property string inKbVariant: ""
    property string inKbModel: ""
    property string inKbOptions: ""
    property string inKbRules: ""
    property real inFollowMouse: 1
    property real inSensitivity: 0
    property string inAccelProfile: "flat"
    property bool inForceNoAccel: true
    property bool inNaturalScroll: true
    property int gestureFingers: 3
    property string gestureDirection: "horizontal"
    property string gestureAction: "workspace"
    property string deviceName: ""
    property real deviceSensitivity: 0

    // programs.lua (raw Lua value expressions)
    property string progTerminal: "\"alacritty\""
    property string progFileManager: "\"nautilus\""
    property string progMenu: "os.getenv(\"HOME\") .. \"/.config/quickshell/launcher/toggle.sh\""
    property string progBrowser: "\"firefox\""
    property string progTextEditor: "\"gnome-text-editor\""
    property string progImageViewer: "\"loupe\""
    property string progPdfViewer: "\"papers\""
    property string progScreenshot: "\"hyprshot\""

    // monitors.lua - autodetected outputs and the draggable arrangement.
    // A ListModel keeps Repeater delegates alive when a value changes; a
    // plain JS array made every update destroy the delegate under the cursor
    // and drop the mouse grab mid-drag.
    ListModel { id: monitorModel }
    property alias monitorList: monitorModel
    readonly property int monitorCount: monitorModel.count
    // ListModel.get() returns a snapshot; bump this so bindings that read
    // monitorAt() re-evaluate after a role changes.
    property int monitorRevision: 0

    function monitorAt(index: int): var {
        return (index >= 0 && index < monitorModel.count) ? monitorModel.get(index).mon : null;
    }
    property int selectedMonitor: 0

    // keybindings.lua / rules.lua
    property var keybinds: []
    property string keyFilter: ""
    property var captureOwner: null
    property var bindOptionVars: ({})
    property var rules: []

    // Store wallpapers relative to $HOME so exported configs stay portable.
    function portablePath(path) {
        const value = String(path || "").trim();
        if (value === "" || value.startsWith("~/"))
            return value;
        if (home !== "" && value === home)
            return "~";
        if (home !== "" && value.startsWith(home + "/"))
            return "~" + value.substring(home.length);
        return value;
    }

    function resolveWallpaperPath(path) {
        const value = portablePath(path);
        return value.startsWith("~/") && home !== ""
            ? home + value.substring(1)
            : value;
    }

    // ---------------------------------------------------------------------
    // Defaults & persistence
    // ---------------------------------------------------------------------
    function defaults() {
        return {
            themeMode: "dark",
            themeColors: {
                dark: { surface: "#11141b", pill: "#121722" },
                light: { surface: "#f5f6f8", pill: "#ffffff" }
            },
            wallpaper: "",
            wallpaperMode: "crop",
            bar: {
                accent: "#7cc7f5",
                surface: "#11141b",
                pill: "#121722",
                pillBorder: "#2b3547",
                text: "#cdd6e6",
                pillHeight: 34,
                pillRadius: 12,
                sideMargin: 10,
                fontSize: 12,
                iconSize: 15,
                pillOpacity: 1.0,
                pills: {
                    left: 0,
                    center: 0.5,
                    right: 1
                }
            },
            hypr: {
                border1: "#0292e3",
                border2: "#01d6be",
                gradient: true,
                angle: 45,
                inactive: "#0f3246",
                borderSize: 1,
                rounding: 5,
                gapsIn: 5,
                gapsOut: 5
            },
            notifications: {
                position: "top-right",
                timeout: 5000,
                maxVisible: 4,
                pauseOnHover: true,
                persistent: false,
                showAppIcon: true,
                showAppName: true
            }
        };
    }

    function asText(v, fallback) {
        return (typeof v === "string" && v.length > 0) ? v : fallback;
    }

    function asInt(v, fallback) {
        return (typeof v === "number" && isFinite(v)) ? Math.round(v) : fallback;
    }

    function asReal(v, fallback) {
        return (typeof v === "number" && isFinite(v)) ? v : fallback;
    }

    function asFraction(v, fallback) {
        const n = asReal(v, fallback);
        return Math.min(1, Math.max(0, n));
    }

    function barPillFraction(which) {
        if (which === "left") return barPillLeft;
        if (which === "center") return barPillCenter;
        if (which === "right") return barPillRight;
        return 0;
    }

    function assignBarPillFraction(which, value) {
        if (which === "left") barPillLeft = value;
        else if (which === "center") barPillCenter = value;
        else if (which === "right") barPillRight = value;
    }

    // Always returns the nearest of the three fixed slots. Pills are never
    // allowed to sit anywhere else. The preview uses this for its guides.
    function barPillSnapSlot(value) {
        const v = asFraction(value, barPillSlots[0]);
        let best = barPillSlots[0];
        let bestDist = Math.abs(v - best);
        for (let i = 1; i < barPillSlots.length; i++) {
            const slot = barPillSlots[i];
            const dist = Math.abs(v - slot);
            if (dist < bestDist) {
                bestDist = dist;
                best = slot;
            }
        }
        return best;
    }

    // Repair stale settings that placed two pills in the same slot.
    function normalizeBarPillSlots() {
        const names = ["left", "center", "right"]
        const used = []
        for (let i = 0; i < names.length; i++) {
            const which = names[i]
            let slot = barPillSnapSlot(barPillFraction(which))
            if (used.indexOf(slot) >= 0) {
                for (let j = 0; j < barPillSlots.length; j++) {
                    const candidate = barPillSlots[j]
                    if (used.indexOf(candidate) < 0) {
                        slot = candidate
                        break
                    }
                }
            }
            assignBarPillFraction(which, slot)
            used.push(slot)
        }
    }

    function asBool(v, fallback) {
        return (typeof v === "boolean") ? v : fallback;
    }

    function applySettings(s) {
        const d = defaults();
        const b = (s && s.bar) || ({});
        const p = b.pills || ({});
        const h = (s && s.hypr) || ({});
        const n = (s && s.notifications) || ({});

        wallpaperPath = asText(s && s.wallpaper, d.wallpaper);
        wallpaperMode = (s && s.wallpaperMode === "fit")
            || (s && s.wallpaperMode === "stretch")
            || (s && s.wallpaperMode === "crop")
            ? s.wallpaperMode : d.wallpaperMode;
        themeMode = (s && s.themeMode === "light") ? "light" : d.themeMode;

        const savedColors = (s && s.themeColors) || ({});
        const savedDark = savedColors.dark || ({});
        const savedLight = savedColors.light || ({});
        themeColors = {
            dark: {
                surface: asText(savedDark.surface, asText(b.surface, d.themeColors.dark.surface)),
                pill: asText(savedDark.pill, asText(b.pill, d.themeColors.dark.pill))
            },
            light: {
                surface: asText(savedLight.surface, d.themeColors.light.surface),
                pill: asText(savedLight.pill, d.themeColors.light.pill)
            }
        };

        barAccent = asText(b.accent, d.bar.accent);
        barSurface = themeColors[themeMode].surface;
        barPill = themeColors[themeMode].pill;
        barPillBorder = asText(b.pillBorder, d.bar.pillBorder);
        barPillHeight = asInt(b.pillHeight, d.bar.pillHeight);
        barPillRadius = asInt(b.pillRadius, d.bar.pillRadius);
        barSideMargin = asInt(b.sideMargin, d.bar.sideMargin);
        barFontSize = asInt(b.fontSize, d.bar.fontSize);
        barIconSize = asInt(b.iconSize, d.bar.iconSize);
        barPillOpacity = asReal(b.pillOpacity, d.bar.pillOpacity);
        barPillLeft = barPillSnapSlot(asFraction(p.left, d.bar.pills.left));
        barPillCenter = barPillSnapSlot(asFraction(p.center, d.bar.pills.center));
        barPillRight = barPillSnapSlot(asFraction(p.right, d.bar.pills.right));
        normalizeBarPillSlots();

        hyprBorder1 = asText(h.border1, d.hypr.border1);
        hyprBorder2 = asText(h.border2, d.hypr.border2);
        hyprGradient = asBool(h.gradient, d.hypr.gradient);
        hyprAngle = asInt(h.angle, d.hypr.angle);
        hyprInactive = asText(h.inactive, d.hypr.inactive);
        hyprBorderSize = asInt(h.borderSize, d.hypr.borderSize);
        hyprRounding = asInt(h.rounding, d.hypr.rounding);
        hyprGapsIn = asInt(h.gapsIn, d.hypr.gapsIn);
        hyprGapsOut = asInt(h.gapsOut, d.hypr.gapsOut);

        notifyPosition = ["top-left", "top-right", "bottom-left", "bottom-right"]
            .indexOf(n.position) >= 0 ? n.position : d.notifications.position;
        notifyTimeout = Math.max(1000, asInt(n.timeout, d.notifications.timeout));
        notifyMaxVisible = Math.min(8, Math.max(1, asInt(n.maxVisible, d.notifications.maxVisible)));
        notifyPauseOnHover = asBool(n.pauseOnHover, d.notifications.pauseOnHover);
        notifyPersistent = asBool(n.persistent, d.notifications.persistent);
        notifyShowAppIcon = asBool(n.showAppIcon, d.notifications.showAppIcon);
        notifyShowAppName = asBool(n.showAppName, d.notifications.showAppName);
    }

    function buildSettings() {
        return {
            themeMode: themeMode,
            themeColors: themeColors,
            wallpaper: wallpaperPath,
            wallpaperMode: wallpaperMode,
            bar: {
                accent: barAccent,
                surface: barSurface,
                pill: barPill,
                pillBorder: barPillBorder,
                text: "#cdd6e6",
                pillHeight: barPillHeight,
                pillRadius: barPillRadius,
                sideMargin: barSideMargin,
                fontSize: barFontSize,
                iconSize: barIconSize,
                pillOpacity: Math.round(barPillOpacity * 100) / 100,
                pills: {
                    left: Math.round(barPillLeft * 1000) / 1000,
                    center: Math.round(barPillCenter * 1000) / 1000,
                    right: Math.round(barPillRight * 1000) / 1000
                }
            },
            hypr: {
                border1: hyprBorder1,
                border2: hyprBorder2,
                gradient: hyprGradient,
                angle: hyprAngle,
                inactive: hyprInactive,
                borderSize: hyprBorderSize,
                rounding: hyprRounding,
                gapsIn: hyprGapsIn,
                gapsOut: hyprGapsOut
            },
            notifications: {
                position: notifyPosition,
                timeout: notifyTimeout,
                maxVisible: notifyMaxVisible,
                pauseOnHover: notifyPauseOnHover,
                persistent: notifyPersistent,
                showAppIcon: notifyShowAppIcon,
                showAppName: notifyShowAppName
            }
        };
    }

    function saveSettings() {
        settingsWriter.setText(JSON.stringify(buildSettings(), null, 2) + "\n");
    }

    function queueSave() {
        saveDebounce.restart();
    }

    function themeGtkName(mode) {
        return mode === "light" ? "Adwaita" : "Adwaita-dark";
    }

    function themeScheme(mode) {
        return mode === "light" ? "prefer-light" : "prefer-dark";
    }

    function themedAutostart(mode) {
        const gtk = themeGtkName(mode);
        const scheme = themeScheme(mode);
        return autostart.map(command => {
            if (command.indexOf("gsettings set org.gnome.desktop.interface gtk-theme") === 0)
                return "gsettings set org.gnome.desktop.interface gtk-theme '" + gtk + "'";
            if (command.indexOf("gsettings set org.gnome.desktop.interface color-scheme") === 0)
                return "gsettings set org.gnome.desktop.interface color-scheme '" + scheme + "'";
            return command;
        });
    }

    function applyGtkTheme(mode) {
        Quickshell.execDetached(["sh", "-c",
            "gsettings set org.gnome.desktop.interface gtk-theme '" + themeGtkName(mode) + "' && "
            + "gsettings set org.gnome.desktop.interface color-scheme '" + themeScheme(mode) + "'"]);
    }

    function updateAutostartTheme(mode) {
        autostart = themedAutostart(mode);
        const encoded = b64Utf8(generateAutostart());
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' '" + encoded + "' | base64 -d > '" + hyprDir + "/autostart.lua'"]);
    }

    function setThemeMode(mode) {
        const next = (mode === "light") ? "light" : "dark";
        if (themeMode === next)
            return;
        themeColors[themeMode].surface = barSurface;
        themeColors[themeMode].pill = barPill;
        themeMode = next;
        barSurface = themeColors[next].surface;
        barPill = themeColors[next].pill;
        saveSettings();
        updateAutostartTheme(next);
        applyGtkTheme(next);
        status = next === "light" ? "Light theme enabled" : "Dark theme enabled";
        statusColor = Theme.green;
        statusTimer.restart();
    }

    function setBarColor(which, value) {
        const mode = (themeMode === "light") ? "light" : "dark";
        if (which === "surface") {
            barSurface = value;
            themeColors[mode].surface = value;
        } else if (which === "pill") {
            barPill = value;
            themeColors[mode].pill = value;
        } else {
            return;
        }
        queueSave();
    }

    function setBarPillPosition(which, value) {
        const target = barPillSnapSlot(value);
        const previous = barPillFraction(which);

        if (target !== previous) {
            // Any pill may occupy any slot. If the target is taken, the
            // current occupant moves to this pill's old slot.
            const names = ["left", "center", "right"];
            for (let i = 0; i < names.length; i++) {
                const other = names[i];
                if (other !== which && barPillFraction(other) === target) {
                    assignBarPillFraction(other, previous);
                    break;
                }
            }
            assignBarPillFraction(which, target);
            queueSave();
        }
    }

    // ---------------------------------------------------------------------
    // Loading
    // ---------------------------------------------------------------------
    function loadAll() {
        // FileView caches text between reads; refresh from disk before parsing
        // so externally edited files (or a previous Apply) are never stale.
        settingsFile.reload();
        autostartFile.reload();
        envFile.reload();
        inputFile.reload();
        programsFile.reload();
        monitorsFile.reload();
        keybindingsFile.reload();
        rulesFile.reload();

        let parsed = null;
        try {
            const raw = settingsFile.text();
            if (raw && raw.trim().length > 0)
                parsed = JSON.parse(raw);
        } catch (e) {
            console.log("settings: unable to read settings.json:", e);
        }
        applySettings(parsed || defaults());
        parseAutostart();
        autostart = themedAutostart(themeMode);
        parseEnv();

        inputText = inputFile.text() || "";
        programsText = programsFile.text() || "";
        monitorsText = monitorsFile.text() || "";
        keybindingsText = keybindingsFile.text() || "";
        rulesText = rulesFile.text() || "";
        parseInput();
        parsePrograms();
        detectMonitors();
        parseKeybindings();
        parseRules();

        scanWallpapers();
        status = "Changes are saved automatically";
        statusColor = Theme.dim;
    }

    function scanWallpapers() {
        wallpaperScan.running = true;
    }

    function escLua(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    function colorToLua(hex) {
        let v = String(hex).trim();
        if (v.startsWith("#"))
            v = v.substring(1);
        if (v.length !== 6)
            v = "ffffff";
        return "rgb(" + v.toLowerCase() + ")";
    }

    function parseAutostart() {
        const t = autostartFile.text() || "";
        const list = [];
        const re = /hl\s*\.\s*exec_cmd\s*\(\s*"((?:[^"\\]|\\.)*)"\s*\)/g;
        let m;
        while ((m = re.exec(t)) !== null)
            list.push(m[1].replace(/\\"/g, "\"").replace(/\\\\/g, "\\"));
        autostart = list;
    }

    function parseEnv() {
        const t = envFile.text() || "";
        const list = [];
        const re = /hl\s*\.\s*env\s*\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)/g;
        let m;
        while ((m = re.exec(t)) !== null)
            list.push({
                key: m[1].replace(/\\"/g, "\"").replace(/\\\\/g, "\\"),
                value: m[2].replace(/\\"/g, "\"").replace(/\\\\/g, "\\")
            });
        envVars = list;
    }

    // ---------------------------------------------------------------------
    // Quote-aware Lua helpers. Values are patched in place so comments,
    // formatting and user-authored blocks in the config files are preserved.
    // ---------------------------------------------------------------------
    function escapeRe(s) {
        return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function luaCommentIndex(s) {
        let quote = "";
        for (let i = 0; i < s.length - 1; i++) {
            const c = s.charAt(i);
            if (quote !== "") {
                if (c === "\\") { i++; continue; }
                if (c === quote) quote = "";
                continue;
            }
            if (c === '"' || c === "'") { quote = c; continue; }
            if (c === "-" && s.charAt(i + 1) === "-") return i;
        }
        return -1;
    }

    function luaFieldRaw(text, name, occurrence) {
        const lines = String(text || "").split("\n");
        const re = new RegExp("^\\s*" + escapeRe(name) + "\\s*=\\s*(.*)$");
        let count = -1;
        for (let i = 0; i < lines.length; i++) {
            const m = re.exec(lines[i]);
            if (!m) continue;
            count++;
            if (count !== (occurrence || 0)) continue;
            let v = m[1];
            const ci = luaCommentIndex(v);
            if (ci >= 0) v = v.substring(0, ci);
            return v.trim().replace(/,\s*$/, "");
        }
        return "";
    }

    function patchLuaField(text, name, rawValue, occurrence) {
        const lines = String(text || "").split("\n");
        const re = new RegExp("^(\\s*" + escapeRe(name) + "\\s*=\\s*)(.*)$");
        let count = -1;
        for (let i = 0; i < lines.length; i++) {
            const m = re.exec(lines[i]);
            if (!m) continue;
            count++;
            if (count !== (occurrence || 0)) continue;
            const rest = m[2];
            let comment = "", gap = "", valuePart = rest;
            const ci = luaCommentIndex(rest);
            if (ci >= 0) {
                comment = rest.substring(ci);
                const before = rest.substring(0, ci);
                valuePart = before.replace(/\s+$/, "");
                gap = before.substring(valuePart.length);
            } else {
                valuePart = rest.replace(/\s+$/, "");
            }
            const comma = /,\s*$/.test(valuePart) ? "," : "";
            if (comma) valuePart = valuePart.replace(/,\s*$/, "");
            lines[i] = m[1] + rawValue + comma + gap + comment;
            break;
        }
        return lines.join("\n");
    }

    function unquoteLua(v, fallback) {
        const s = String(v == null ? "" : v).trim();
        if (s.length >= 2) {
            const a = s.charAt(0), b = s.charAt(s.length - 1);
            if ((a === '"' && b === '"') || (a === "'" && b === "'"))
                return s.substring(1, s.length - 1);
        }
        return s.length > 0 ? s : fallback;
    }

    function luaStr(v) {
        return "\"" + escLua(String(v == null ? "" : v)) + "\"";
    }

    function luaBool(v) {
        return v ? "true" : "false";
    }

    function luaNum(v, fallback) {
        const n = parseFloat(v);
        return isFinite(n) ? String(n) : String(fallback);
    }

    function programValue(v) {
        const s = String(v).trim();
        if (s.length === 0) return "\"\"";
        if (s.indexOf('"') >= 0 || s.indexOf("'") >= 0 || s.indexOf("..") >= 0)
            return s;
        return "\"" + escLua(s) + "\"";
    }

    // ---------------------------------------------------------------------
    // Human-readable display for raw Lua expressions
    // ---------------------------------------------------------------------
    function displayProgram(raw) {
        const s = String(raw == null ? "" : raw).trim();
        const h = s.match(/os\.getenv\("HOME"\)\s*\.\.\s*"(.*)"$/);
        if (h) return "~" + h[1];
        const q = s.match(/^"(.*)"$/);
        if (q) return q[1];
        return s;
    }

    function setProgram(field, value) {
        const raw = String(root[field] == null ? "" : root[field]);
        const homeExpr = /os\.getenv\("HOME"\)/.test(raw);
        const v = String(value == null ? "" : value).trim();
        if (homeExpr && v.indexOf("~/") === 0)
            root[field] = "os.getenv(\"HOME\") .. \"" + escLua(v.substring(1)) + "\"";
        else
            root[field] = programValue(v);
    }

    function friendlyKey(expr) {
        let s = String(expr == null ? "" : expr).trim();
        s = s.replace(/\bmainMod\b/g, "SUPER");
        s = s.replace(/\s*\.\.\s*/g, "");
        s = s.replace(/["']/g, "");
        s = s.replace(/\+\s*\+\s*key\b/g, "+ <key>");
        return s.replace(/\s+/g, " ").trim();
    }

    function friendlyAction(expr) {
        let s = String(expr == null ? "" : expr).trim();

        // Named program variables first.
        if (/^hl\.dsp\.exec_cmd\(menu\)$/.test(s)) return "Open launcher";
        if (/^hl\.dsp\.exec_cmd\(terminal\)$/.test(s)) return "Open terminal";
        if (/^hl\.dsp\.exec_cmd\(fileManager\)$/.test(s)) return "Open file manager";
        if (/^hl\.dsp\.exec_cmd\(browser\)$/.test(s)) return "Open browser";

        const exec = s.match(/^hl\.dsp\.exec_cmd\((.*)\)$/);
        if (exec) {
            const inner = exec[1].trim();
            const q = inner.match(/^"(.*)"$/);
            if (q) return "Run: " + q[1];
            const h = inner.match(/os\.getenv\("HOME"\)\s*\.\.\s*"(.*)"$/);
            if (h) return "Run: ~" + h[1];
            return "Run: " + inner;
        }

        const bare = s.replace(/^hl\.dsp\./, "");
        const pairs = [
            [/window\.close\(\)/, "Close window"],
            [/window\.float\(\{[^}]*toggle[^}]*\}\)/, "Toggle floating"],
            [/window\.pseudo\(\)/, "Toggle pseudo-tiling"],
            [/window\.drag\(\)/, "Drag floating window"],
            [/window\.resize\(\)/, "Resize floating window"],
            [/window\.move\(\{[^}]*workspace\s*=\s*"?([^" }]+)"?[^}]*\}\)/, "Move to workspace $1"],
            [/focus\(\{\s*direction\s*=\s*"([^"]+)"\s*\}\)/, "Focus $1"],
            [/focus\(\{\s*workspace\s*=\s*"([^"]+)"\s*\}\)/, "Workspace $1"],
            [/focus\(\{\s*workspace\s*=\s*([^ }]+)\s*\}\)/, "Workspace $1"],
            [/layout\("([^"]+)"\)/, "Layout: $1"],
            [/toggle_special\("([^"]+)"\)/, "Toggle scratchpad: $1"]
        ];
        for (let i = 0; i < pairs.length; i++) {
            if (pairs[i][0].test(bare))
                return bare.replace(pairs[i][0], pairs[i][1]);
        }
        return s;
    }

    // UTF-8 safe base64 (Qt.btoa assumes Latin-1, which breaks on unicode paths).
    function b64Utf8(str) {
        const s = String(str == null ? "" : str);
        let out = "", i = 0;
        while (i < s.length) {
            const c = s.charCodeAt(i++);
            if (c < 0x80) {
                out += String.fromCharCode(c);
            } else if (c < 0x800) {
                out += String.fromCharCode(0xC0 | (c >> 6));
                out += String.fromCharCode(0x80 | (c & 0x3F));
            } else if (c >= 0xD800 && c <= 0xDBFF && i < s.length) {
                const c2 = s.charCodeAt(i++);
                const cp = 0x10000 + ((c - 0xD800) << 10) + (c2 - 0xDC00);
                out += String.fromCharCode(0xF0 | (cp >> 18));
                out += String.fromCharCode(0x80 | ((cp >> 12) & 0x3F));
                out += String.fromCharCode(0x80 | ((cp >> 6) & 0x3F));
                out += String.fromCharCode(0x80 | (cp & 0x3F));
            } else {
                out += String.fromCharCode(0xE0 | (c >> 12));
                out += String.fromCharCode(0x80 | ((c >> 6) & 0x3F));
                out += String.fromCharCode(0x80 | (c & 0x3F));
            }
        }
        return Qt.btoa(out);
    }

    function parseInput() {
        const t = inputText;
        inKbLayout = unquoteLua(luaFieldRaw(t, "kb_layout"), "us");
        inKbVariant = unquoteLua(luaFieldRaw(t, "kb_variant"), "");
        inKbModel = unquoteLua(luaFieldRaw(t, "kb_model"), "");
        inKbOptions = unquoteLua(luaFieldRaw(t, "kb_options"), "");
        inKbRules = unquoteLua(luaFieldRaw(t, "kb_rules"), "");
        inFollowMouse = parseFloat(luaFieldRaw(t, "follow_mouse")) || 0;
        inSensitivity = parseFloat(luaFieldRaw(t, "sensitivity", 0)) || 0;
        inAccelProfile = unquoteLua(luaFieldRaw(t, "accel_profile"), "flat");
        inForceNoAccel = luaFieldRaw(t, "force_no_accel") === "true";
        inNaturalScroll = luaFieldRaw(t, "natural_scroll") === "true";
        gestureFingers = parseInt(luaFieldRaw(t, "fingers"), 10) || 3;
        gestureDirection = unquoteLua(luaFieldRaw(t, "direction"), "horizontal");
        gestureAction = unquoteLua(luaFieldRaw(t, "action"), "workspace");
        deviceName = unquoteLua(luaFieldRaw(t, "name"), "");
        deviceSensitivity = parseFloat(luaFieldRaw(t, "sensitivity", 1)) || 0;
    }

    function parsePrograms() {
        const t = programsText;
        progTerminal = luaFieldRaw(t, "M.terminal") || "\"alacritty\"";
        progFileManager = luaFieldRaw(t, "M.fileManager") || "\"nautilus\"";
        progMenu = luaFieldRaw(t, "M.menu") || "os.getenv(\"HOME\") .. \"/.config/quickshell/launcher/toggle.sh\"";
        progBrowser = luaFieldRaw(t, "M.browser") || "\"firefox\"";
        progTextEditor = luaFieldRaw(t, "M.textEditor") || "\"gnome-text-editor\"";
        progImageViewer = luaFieldRaw(t, "M.imageViewer") || "\"loupe\"";
        progPdfViewer = luaFieldRaw(t, "M.pdfViewer") || "\"papers\"";
        progScreenshot = luaFieldRaw(t, "M.screenshot") || "\"hyprshot\"";
    }

    // Autodetect outputs and their supported modes from Hyprland itself.
    function detectMonitors() {
        monitorScan.running = true;
    }

    function onMonitorData(text: string): void {
        try {
            const arr = JSON.parse(text);
            if (!arr || arr.length === 0) return;
            monitorModel.clear();
            for (let i = 0; i < arr.length; i++) {
                const m = arr[i];
                const refresh = Math.round(Number(m.refreshRate) * 100) / 100;
                // One role object avoids role names like "x"/"width"
                // colliding with the Rectangle's own geometry properties.
                monitorModel.append({
                    mon: {
                        id: m.id,
                        name: m.name || ("output" + i),
                        description: m.description || m.model || m.name || "",
                        width: Number(m.width) || 0,
                        height: Number(m.height) || 0,
                        refresh: refresh,
                        mode: String(m.width) + "x" + String(m.height) + "@" + refresh.toFixed(2) + "Hz",
                        x: Number(m.x) || 0,
                        y: Number(m.y) || 0,
                        scale: Number(m.scale) || 1,
                        transform: Number(m.transform) || 0,
                        disabled: !!m.disabled,
                        modes: (m.availableModes || []).slice()
                    }
                });
            }
            if (selectedMonitor < 0 || selectedMonitor >= monitorModel.count)
                selectedMonitor = 0;
            monitorRevision++;
        } catch (e) {
            console.log("settings: unable to parse monitor data:", e);
        }
    }

    function updateMonitor(index: int, field: string, value: var): void {
        if (index < 0 || index >= monitorModel.count) return;
        const m = Object.assign({}, monitorModel.get(index).mon);
        const oldTransform = Number(m.transform) || 0;
        m[field] = value;
        monitorModel.setProperty(index, "mon", m);
        if (field === "transform" && (Number(m.transform) || 0) !== oldTransform) {
            const resolved = resolveMonitorPos(index, m.x, m.y);
            if (resolved.x !== m.x || resolved.y !== m.y) {
                const moved = Object.assign({}, monitorModel.get(index).mon);
                moved.x = resolved.x;
                moved.y = resolved.y;
                monitorModel.setProperty(index, "mon", moved);
            }
        }
        monitorRevision++;
    }

    function setMonitorMode(index: int, mode: string): void {
        if (index < 0 || index >= monitorModel.count) return;
        const parts = String(mode).split("@");
        const wh = parts[0].split("x");
        const m = Object.assign({}, monitorModel.get(index).mon);
        m.mode = mode;
        m.width = parseInt(wh[0], 10) || m.width;
        m.height = parseInt(wh[1], 10) || m.height;
        m.refresh = parseFloat(parts[1]) || m.refresh;
        monitorModel.setProperty(index, "mon", m);
        monitorRevision++;
    }

    // Hyprland keeps the native mode size in width/height even for rotated
    // outputs. Arrangement and hit-testing need the on-screen size instead.
    function monitorRotated(m): bool {
        const t = Number(m && m.transform) || 0;
        return t === 1 || t === 3;
    }

    function monitorWidth(m): real {
        if (!m) return 0;
        return monitorRotated(m) ? (Number(m.height) || 0) : (Number(m.width) || 0);
    }

    function monitorHeight(m): real {
        if (!m) return 0;
        return monitorRotated(m) ? (Number(m.width) || 0) : (Number(m.height) || 0);
    }

    // Keep outputs from overlapping. Each pass nudges the dragged monitor
    // out along the shallowest axis, snapping outward to the 10px grid so a
    // resolved position cannot reintroduce the overlap.
    function resolveMonitorPos(index: int, x: real, y: real): var {
        const self = monitorModel.get(index).mon;
        const selfW = monitorWidth(self);
        const selfH = monitorHeight(self);
        let px = Math.round(x / 10) * 10;
        let py = Math.round(y / 10) * 10;
        for (let pass = 0; pass < 8; pass++) {
            let moved = false;
            for (let i = 0; i < monitorModel.count; i++) {
                if (i === index) continue;
                const o = monitorModel.get(i).mon;
                const ow = monitorWidth(o);
                const oh = monitorHeight(o);
                const ox = Math.min(px + selfW, o.x + ow) - Math.max(px, o.x);
                const oy = Math.min(py + selfH, o.y + oh) - Math.max(py, o.y);
                if (ox <= 0 || oy <= 0) continue;
                if (ox < oy) {
                    if (px + selfW / 2 <= o.x + ow / 2)
                        px = Math.floor((o.x - selfW) / 10) * 10;
                    else
                        px = Math.ceil((o.x + ow) / 10) * 10;
                } else {
                    if (py + selfH / 2 <= o.y + oh / 2)
                        py = Math.floor((o.y - selfH) / 10) * 10;
                    else
                        py = Math.ceil((o.y + oh) / 10) * 10;
                }
                moved = true;
            }
            if (!moved) break;
        }
        return { x: px, y: py };
    }

    function setMonitorPos(index: int, x: real, y: real): void {
        if (index < 0 || index >= monitorModel.count) return;
        const resolved = resolveMonitorPos(index, x, y);
        const nx = resolved.x, ny = resolved.y;
        const m = Object.assign({}, monitorModel.get(index).mon);
        if (m.x === nx && m.y === ny) return;
        m.x = nx;
        m.y = ny;
        monitorModel.setProperty(index, "mon", m);
        monitorRevision++;
    }

    function monitorModeOptions(index: int): var {
        if (index < 0 || index >= monitorModel.count) return [];
        const seen = {};
        const out = [];
        const modes = monitorModel.get(index).mon.modes || [];
        for (let i = 0; i < modes.length; i++) {
            const res = String(modes[i]).split("@")[0];
            if (seen[res]) continue;
            seen[res] = true;
            out.push(res);
        }
        return out;
    }

    function monitorRefreshOptions(index: int, resolution: string): var {
        if (index < 0 || index >= monitorModel.count) return [];
        const out = [];
        const modes = monitorModel.get(index).mon.modes || [];
        for (let i = 0; i < modes.length; i++) {
            const parts = String(modes[i]).split("@");
            if (parts[0] !== resolution) continue;
            const hz = parseFloat(parts[1]);
            if (isFinite(hz)) out.push((Math.round(hz * 100) / 100) + " Hz");
        }
        out.sort((a, b) => parseFloat(b) - parseFloat(a));
        return out;
    }

    // Keeps each argument's surrounding whitespace so column alignment in
    // keybindings.lua survives an Apply round-trip unchanged.
    function splitLuaArgsRaw(s) {
        const out = [];
        let depth = 0, start = 0, quote = "";
        for (let i = 0; i < s.length; i++) {
            const c = s.charAt(i);
            if (quote !== "") {
                if (c === "\\") { i++; continue; }
                if (c === quote) quote = "";
                continue;
            }
            if (c === '"' || c === "'") { quote = c; continue; }
            if (c === "(" || c === "[" || c === "{") depth++;
            else if (c === ")" || c === "]" || c === "}") depth--;
            else if (c === "," && depth === 0) {
                out.push(s.substring(start, i));
                start = i + 1;
            }
        }
        out.push(s.substring(start));
        return out;
    }

    function luaArgPiece(piece) {
        const lead = (piece.match(/^\s*/) || [""])[0];
        const trail = (piece.match(/\s*$/) || [""])[0];
        return {
            lead: lead,
            text: piece.substring(lead.length, piece.length - trail.length),
            trail: trail
        };
    }

    function renderLuaArgs(pieces) {
        const out = [];
        for (let i = 0; i < pieces.length; i++)
            out.push(pieces[i].lead + pieces[i].text + pieces[i].trail);
        return out.join(",");
    }

    // Hyprland's label is the `description` field of the bind options table.
    function luaStringField(text: string, names: var): string {
        const source = String(text || "");
        for (let i = 0; i < names.length; i++) {
            const re = new RegExp("\\b" + names[i] + "\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\"");
            const m = re.exec(source);
            if (m)
                return m[1].replace(/\\"/g, "\"").replace(/\\\\/g, "\\");
        }
        return "";
    }

    function labelFromComment(comment: string): string {
        const c = String(comment || "").replace(/^\s*--\s*/, "").trim();
        if (c.length === 0) return "";
        const m = /(?:^|\|\s*)label\s*:\s*(.*)$/i.exec(c);
        return m ? m[1].trim() : c;
    }

    function bindOptionsOf(b): string {
        if (!b || !b.pieces || b.pieces.length < 3) return "";
        return b.pieces[2].text;
    }

    function bindCanInjectLabel(b): bool {
        const label = String(b && b.label || "").trim();
        if (label.length === 0) return false;
        const opts = bindOptionsOf(b).trim();
        if (opts.length === 0) return true;
        const resolved = bindOptionVars[opts] || opts;
        return resolved.charAt(0) === "{" && resolved.charAt(resolved.length - 1) === "}";
    }

    function luaBindOptions(b): string {
        const label = String(b && b.label || "").trim();
        if (label.length === 0) return bindOptionsOf(b);

        const desc = "description = " + luaStr(label);
        let opts = bindOptionsOf(b).trim();
        if (opts.length === 0) return "{ " + desc + " }";

        const resolved = bindOptionVars[opts] || opts;
        if (resolved.charAt(0) === "{" && resolved.charAt(resolved.length - 1) === "}") {
            let inner = resolved.substring(1, resolved.length - 1).trim();
            inner = inner.replace(/,?\s*(?:description|desc)\s*=\s*(?:"(?:[^"\\]|\\.)*"|'[^']*')/g, "");
            inner = inner.replace(/^\s*,\s*/, "").replace(/\s*,\s*$/, "").trim();
            return inner.length > 0 ? "{ " + inner + ", " + desc + " }" : "{ " + desc + " }";
        }
        return bindOptionsOf(b);
    }

    function luaBindComment(b): string {
        const comment = String(b && b.comment || "");
        const label = String(b && b.label || "").trim();
        if (label.length === 0 || bindCanInjectLabel(b))
            return comment;
        const marker = "label: " + label;
        if (comment.toLowerCase().indexOf(marker.toLowerCase()) >= 0)
            return comment;
        return comment.length > 0 ? comment + " | " + marker : " -- " + marker;
    }

    // Options without the label, for the compact summary chip.
    function bindFlags(b): string {
        const opts = bindOptionsOf(b).trim();
        if (opts.length === 0) return "";
        const resolved = bindOptionVars[opts] || opts;
        if (resolved.charAt(0) === "{" && resolved.charAt(resolved.length - 1) === "}") {
            let inner = resolved.substring(1, resolved.length - 1).trim();
            inner = inner.replace(/,?\s*(?:description|desc)\s*=\s*(?:"(?:[^"\\]|\\.)*"|'[^']*')/g, "");
            inner = inner.replace(/^\s*,\s*/, "").replace(/\s*,\s*$/, "").trim();
            return inner.length > 0 ? "{ " + inner + " }" : "";
        }
        return opts;
    }

    function parseKeybindings() {
        const lines = keybindingsText.split("\n");

        // Remember local option tables so `{ locked = true }` aliases can be
        // expanded when a label is added without losing their flags.
        const vars = {};
        const varRe = /^\s*local\s+([A-Za-z_]\w*)\s*=\s*(\{.*\})\s*$/;
        for (let i = 0; i < lines.length; i++) {
            const vm = varRe.exec(lines[i]);
            if (vm) vars[vm[1]] = vm[2];
        }
        bindOptionVars = vars;

        const list = [];
        const re = /^(\s*(?:local\s+\w+\s*=\s*)?)hl\.bind\((.*)\)(\s*--.*)?$/;
        for (let i = 0; i < lines.length; i++) {
            const m = re.exec(lines[i]);
            if (!m) continue;
            const pieces = splitLuaArgsRaw(m[2]).map(function (p) { return luaArgPiece(p); });
            if (pieces.length < 2) continue;
            const options = [];
            for (let j = 2; j < pieces.length; j++) options.push(pieces[j].text);
            const opts = pieces.length > 2 ? pieces[2].text : "";
            let label = luaStringField(opts, ["description", "desc"]);
            if (label.length === 0 && bindOptionVars[opts])
                label = luaStringField(bindOptionVars[opts], ["description", "desc"]);
            if (label.length === 0)
                label = labelFromComment(m[3] || "");
            if (label.length === 0)
                label = friendlyAction(pieces[1].text);
            list.push({
                line: i,
                prefix: m[1],
                pieces: pieces,
                bind: pieces[0].text,
                command: pieces[1].text,
                label: label,
                options: options.join(", "),
                comment: m[3] || "",
                removed: false
            });
        }
        keybinds = list;
    }

    function parseRules() {
        const blocks = rulesText.split("hl.window_rule(");
        const list = [];
        for (let i = 1; i < blocks.length; i++) {
            const b = blocks[i];
            const nameMatch = b.match(/name\s*=\s*"([^"]+)"/);
            const name = nameMatch ? nameMatch[1] : "rule " + i;
            let match = "";
            const mi = b.indexOf("match");
            if (mi >= 0) {
                const tail = b.substring(mi);
                const brace = tail.indexOf("{");
                if (brace >= 0) {
                    let depth = 0, end = -1;
                    for (let j = brace; j < tail.length; j++) {
                        const c = tail.charAt(j);
                        if (c === "{") depth++;
                        else if (c === "}") {
                            depth--;
                            if (depth === 0) { end = j + 1; break; }
                        }
                    }
                    if (end > 0)
                        match = tail.substring(brace, end).replace(/\s+/g, " ").trim();
                }
            }
            list.push({ name: name, match: match });
        }
        rules = list;
    }

    // ---------------------------------------------------------------------
    // Autostart / environment list editing
    // ---------------------------------------------------------------------
    function setAutostart(index, value) {
        // Mutate in place: reassigning the array would rebuild the Repeater
        // and steal focus while the user is still typing.
        if (index < 0 || index >= autostart.length)
            return;
        autostart[index] = value;
    }

    function addAutostart(value) {
        const command = String(value).trim();
        if (command.length === 0)
            return;
        autostart = autostart.concat([command]);
    }

    function removeAutostart(index) {
        const copy = autostart.slice();
        copy.splice(index, 1);
        autostart = copy;
    }

    function setEnv(index, field, value) {
        if (index < 0 || index >= envVars.length)
            return;
        envVars[index][field] = value;
    }

    function addEnv(key, value) {
        const k = String(key).trim();
        if (k.length === 0)
            return;
        envVars = envVars.concat([{ key: k, value: String(value) }]);
    }

    function removeEnv(index) {
        const copy = envVars.slice();
        copy.splice(index, 1);
        envVars = copy;
    }

    function setKeybind(index, field, value) {
        if (index < 0 || index >= keybinds.length) return;
        // In-place mutation keeps the text field focused while typing.
        keybinds[index][field] = value;
    }

    function removeKeybind(index) {
        if (index < 0 || index >= keybinds.length) return;
        const copy = keybinds.slice();
        const b = {};
        for (const k in copy[index]) b[k] = copy[index][k];
        b.removed = true;
        copy[index] = b;
        keybinds = copy;
    }

    function addKeybind(bind, command, label) {
        const b = String(bind).trim();
        const c = String(command).trim();
        if (b.length === 0 || c.length === 0) return;
        keybinds = keybinds.concat([{
            line: -1, prefix: "", pieces: [],
            bind: b, command: c, label: String(label || "").trim(),
            options: "", comment: "", removed: false
        }]);
    }

    // ---------------------------------------------------------------------
    // Generated Lua files
    // ---------------------------------------------------------------------
    function generateAutostart() {
        const lines = autostart.map(c => "    hl.exec_cmd(\"" + escLua(c) + "\")").join("\n");
        return "--------------------------------------------------------------------------------\n"
            + "-- AUTOSTART & SYSTEM INITIALIZATION\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + "hl.on(\"hyprland.start\", function ()\n"
            + lines + "\n"
            + "end)\n";
    }

    function generateEnv() {
        const lines = envVars.map(e => "hl.env(\"" + escLua(e.key) + "\", \"" + escLua(e.value) + "\")").join("\n");
        return "--------------------------------------------------------------------------------\n"
            + "-- ENVIRONMENT VARIABLES\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + lines + "\n";
    }

    function generateManaged() {
        const active = hyprGradient
            ? "{ colors = { \"" + colorToLua(hyprBorder1) + "\", \"" + colorToLua(hyprBorder2) + "\" }, angle = " + hyprAngle + " }"
            : "\"" + colorToLua(hyprBorder1) + "\"";

        return "--------------------------------------------------------------------------------\n"
            + "-- LOOK & FEEL OVERRIDES\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "-- This file is loaded last, so it wins over look_and_feel.lua.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + "hl.config({\n"
            + "    general = {\n"
            + "        gaps_in = " + hyprGapsIn + ",\n"
            + "        gaps_out = " + hyprGapsOut + ",\n"
            + "        border_size = " + hyprBorderSize + ",\n"
            + "        col = {\n"
            + "            active_border = " + active + ",\n"
            + "            inactive_border = \"" + colorToLua(hyprInactive) + "\",\n"
            + "        },\n"
            + "    },\n"
            + "    decoration = {\n"
            + "        rounding = " + hyprRounding + ",\n"
            + "    },\n"
            + "})\n";
    }

    // Machine-owned files are regenerated in full from the in-memory state.
    // No regex patching: one canonical definition per parameter, predictable
    // formatting, and no stale FileView text can corrupt an edit.
    function generateInput() {
        return "--------------------------------------------------------------------------------\n"
            + "-- INPUT DEVICES & GESTURES\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + "hl.config({\n"
            + "    input = {\n"
            + "        kb_layout = " + luaStr(inKbLayout) + ",\n"
            + "        kb_variant = " + luaStr(inKbVariant) + ",\n"
            + "        kb_model = " + luaStr(inKbModel) + ",\n"
            + "        kb_options = " + luaStr(inKbOptions) + ",\n"
            + "        kb_rules = " + luaStr(inKbRules) + ",\n"
            + "        follow_mouse = " + luaNum(inFollowMouse, 1) + ",\n"
            + "        sensitivity = " + luaNum(inSensitivity, 0) + ",\n"
            + "        accel_profile = " + luaStr(inAccelProfile) + ",\n"
            + "        force_no_accel = " + luaBool(inForceNoAccel) + ",\n"
            + "        touchpad = {\n"
            + "            natural_scroll = " + luaBool(inNaturalScroll) + ",\n"
            + "        },\n"
            + "    },\n"
            // Required on Hyprland 0.57 with rotated outputs: hardware
            // cursors leave an unreachable strip along the rotated edge.
            + "    cursor = {\n"
            + "        no_hardware_cursors = true,\n"
            + "    },\n"
            + "})\n\n"
            + "hl.gesture({\n"
            + "    fingers = " + String(Math.round(gestureFingers)) + ",\n"
            + "    direction = " + luaStr(gestureDirection) + ",\n"
            + "    action = " + luaStr(gestureAction) + ",\n"
            + "})\n\n"
            + "hl.device({\n"
            + "    name = " + luaStr(deviceName) + ",\n"
            + "    sensitivity = " + luaNum(deviceSensitivity, 0) + ",\n"
            + "})\n";
    }

    function generatePrograms() {
        return "--------------------------------------------------------------------------------\n"
            + "-- DEFAULT APPLICATIONS\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + "local M = {}\n\n"
            + "M.terminal = " + programValue(progTerminal) + "\n"
            + "M.fileManager = " + programValue(progFileManager) + "\n"
            + "M.menu = " + programValue(progMenu) + "\n"
            + "M.browser = " + programValue(progBrowser) + "\n"
            + "M.textEditor = " + programValue(progTextEditor) + "\n"
            + "M.imageViewer = " + programValue(progImageViewer) + "\n"
            + "M.pdfViewer = " + programValue(progPdfViewer) + "\n"
            + "M.screenshot = " + programValue(progScreenshot) + "\n\n"
            + "return M\n";
    }

    function generateMonitors() {
        const header = "--------------------------------------------------------------------------------\n"
            + "-- MONITORS CONFIGURATION\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "-- One rule per detected output; positions are the top-left corner in pixels.\n"
            + "--------------------------------------------------------------------------------\n\n";

        if (monitorModel.count === 0) {
            return header + "-- No outputs detected yet; Hyprland auto-configures displays.\n";
        }

        let out = header;
        for (let i = 0; i < monitorModel.count; i++) {
            const m = monitorModel.get(i).mon;
            out += "hl.monitor({\n"
                + "    output = " + luaStr(m.name) + ",\n"
                + "    mode = " + luaStr(m.mode) + ",\n"
                + "    position = " + luaStr(String(m.x) + "x" + String(m.y)) + ",\n"
                + "    scale = " + luaStr(String(m.scale)) + ",\n";
            if (Number(m.transform) !== 0)
                out += "    transform = " + String(Math.round(m.transform)) + ",\n";
            if (m.disabled)
                out += "    disabled = true,\n";
            out += "})\n\n";
        }
        return out;
    }

    function generateKeybindings() {
        const lines = keybindingsText.split("\n");
        for (let i = keybinds.length - 1; i >= 0; i--) {
            const b = keybinds[i];
            if (b.line < 0 || b.line >= lines.length) continue;
            if (b.removed) {
                lines[b.line] = "";
                continue;
            }
            if (!b.pieces || b.pieces.length < 2) continue;
            const pieces = [];
            for (let j = 0; j < b.pieces.length; j++) {
                const p = b.pieces[j];
                let text = p.text;
                if (j === 0)
                    text = b.bind;
                else if (j === 1)
                    text = b.command;
                else if (j === 2 && b.label)
                    text = luaBindOptions(b);
                pieces.push({ lead: p.lead, text: text, trail: p.trail });
            }
            if (b.label && pieces.length === 2)
                pieces.push({ lead: " ", text: luaBindOptions(b), trail: "" });
            lines[b.line] = b.prefix + "hl.bind(" + renderLuaArgs(pieces) + ")" + luaBindComment(b);
        }
        let out = lines.join("\n");
        for (let i = 0; i < keybinds.length; i++) {
            const b = keybinds[i];
            if (b.line !== -1 || b.removed) continue;
            const args = [b.bind, b.command];
            if (b.label)
                args.push(luaBindOptions(b));
            else if (b.options.length > 0)
                args.push(b.options);
            out += "hl.bind(" + args.join(", ") + ")" + luaBindComment(b) + "\n";
        }
        return out;
    }

    // ---------------------------------------------------------------------
    // Actions
    // ---------------------------------------------------------------------
    function selectWallpaper(path) {
        const p = String(path).trim();
        if (p.length === 0)
            return;
        wallpaperPath = portablePath(p);
        saveSettings();
        status = "Wallpaper updated";
        statusColor = Theme.green;
        statusTimer.restart();
    }

    function setWallpaperMode(mode) {
        wallpaperMode = mode;
        saveSettings();
    }

    function openPictures() {
        Quickshell.execDetached(["xdg-open", home + "/Pictures"]);
    }

    function openHyprFolder() {
        Quickshell.execDetached(["xdg-open", hyprDir]);
    }

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", String(path)]);
    }

    function resetAll() {
        applySettings(defaults());
        saveDebounce.stop();
        saveSettings();
        updateAutostartTheme("dark");
        applyGtkTheme("dark");
        status = "Defaults restored — press Apply for Hyprland";
        statusColor = Theme.yellow;
        statusTimer.restart();
    }

    function applyAll() {
        saveDebounce.stop();

        // Clicking Apply does not necessarily pull focus out of a TextField
        // (SettingsButton is a plain MouseArea), so flush any pending edit.
        if (window.activeFocusItem && window.activeFocusItem !== window)
            window.activeFocusItem.focus = false;

        const files = [
            [settingsPath, JSON.stringify(buildSettings(), null, 2) + "\n"],
            [hyprDir + "/autostart.lua", generateAutostart()],
            [hyprDir + "/env.lua", generateEnv()],
            [hyprDir + "/ui_overrides.lua", generateManaged()],
            [hyprDir + "/input.lua", generateInput()],
            [hyprDir + "/programs.lua", generatePrograms()],
            [hyprDir + "/monitors.lua", generateMonitors()],
            [hyprDir + "/keybindings.lua", generateKeybindings()]
        ];

        let script = "";
        for (let i = 0; i < files.length; i++) {
            const encoded = b64Utf8(files[i][1]);
            script += "printf '%s' '" + encoded + "' | base64 -d > '" + files[i][0] + "'\n";
        }
        script += "hyprctl reload >/dev/null 2>&1\n";

        Quickshell.execDetached(["sh", "-c", script]);
        status = "Applied — Hyprland reloaded";
        statusColor = Theme.green;
        statusTimer.restart();
    }

    // ---------------------------------------------------------------------
    // Window plumbing
    // ---------------------------------------------------------------------
    function open() {
        if (shown)
            return;
        loadAll();
        shown = true;
    }

    // Quit instead of hiding: every open is then a fresh process that reads
    // the config files from disk, so a new daemon can never show stale state.
    // ~/.config/quickshell/settings/toggle.sh relaunches it on demand.
    function close() {
        Qt.quit();
    }

    function toggle() {
        if (shown)
            close();
        else
            open();
    }

    IpcHandler {
        target: "settings"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
        function apply(): void { root.applyAll() }
        function reset(): void { root.resetAll() }
        function theme(mode: string): void { root.setThemeMode(mode) }
        function section(index: int): void {
            root.page = Math.max(0, Math.min(8, index));
            root.open();
        }
        // Kept as an alias for existing scripts: Hyprland tab 0..7 now
        // corresponds to top-level pages 0..7.
        function hsection(index: int): void {
            root.page = Math.max(0, Math.min(7, index));
            root.open();
        }
    }

    Timer {
        id: saveDebounce
        interval: 180
        onTriggered: root.saveSettings()
    }

    Timer {
        id: statusTimer
        interval: 2600
        onTriggered: {
            root.status = "Changes are saved automatically";
            root.statusColor = Theme.dim;
        }
    }

    FileView {
        id: settingsFile
        path: root.settingsPath
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: settingsWriter
        path: root.settingsPath
        blockWrites: false
        atomicWrites: false
        printErrors: true
    }

    FileView {
        id: autostartFile
        path: root.hyprDir + "/autostart.lua"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: envFile
        path: root.hyprDir + "/env.lua"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: inputFile
        path: root.hyprDir + "/input.lua"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: programsFile
        path: root.hyprDir + "/programs.lua"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: monitorsFile
        path: root.hyprDir + "/monitors.lua"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: keybindingsFile
        path: root.hyprDir + "/keybindings.lua"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: rulesFile
        path: root.hyprDir + "/rules.lua"
        preload: true
        blockLoading: true
        printErrors: false
    }

    Process {
        id: wallpaperScan
        running: false

        command: ["sh", "-c", "find \"$HOME/Pictures\" -maxdepth 3 -type f 2>/dev/null | grep -iE '\\.(png|jpg|jpeg|webp|gif)$' | sort"]

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                const paths = t.length > 0 ? t.split("\n") : [];
                root.wallpapers = paths
                    .map(function(path) { return root.portablePath(path); })
                    .filter(function(path) { return path.length > 0; });
            }
        }
    }

    Process {
        id: monitorScan
        running: false

        command: ["hyprctl", "monitors", "all", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.onMonitorData(text)
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shown && root.captureOwner === null
        onActivated: root.close()
    }

    PanelWindow {
        id: window

        visible: root.shown
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"
        focusable: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-settings"
        WlrLayershell.keyboardFocus: root.shown
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card

            width: Math.min(1100, parent.width - 80)
            height: Math.min(720, parent.height - 60)
            anchors.centerIn: parent
            radius: Theme.panelRadius
            color: Theme.surface
            border.width: 1
            border.color: Theme.border

            MouseArea {
                anchors.fill: parent
            }

            // Soft shadow
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                radius: parent.radius + 2
                color: "#66000000"
                z: -1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: "󰒓"
                        font.family: Theme.font
                        font.pixelSize: 22
                        color: Theme.accent
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: "Settings"
                            font.family: Theme.mono
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Theme.text
                        }

                        Text {
                            text: "Desktop control center"
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.dim
                        }
                    }

                    Item { Layout.fillWidth: true }

                    SettingsButton {
                        icon: "󰅖"
                        onClicked: root.close()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                // Body
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    ColumnLayout {
                        Layout.preferredWidth: 190
                        Layout.fillHeight: true
                        spacing: 4

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰖲"
                            label: "Appearance"
                            active: root.page === 0
                            onClicked: root.page = 0
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: ""
                            label: "Input"
                            active: root.page === 1
                            onClicked: root.page = 1
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰌋"
                            label: "Keybindings"
                            active: root.page === 2
                            onClicked: root.page = 2
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰒲"
                            label: "Autostart"
                            active: root.page === 3
                            onClicked: root.page = 3
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰀻"
                            label: "Programs"
                            active: root.page === 4
                            onClicked: root.page = 4
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰫧"
                            label: "Environment"
                            active: root.page === 5
                            onClicked: root.page = 5
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰍹"
                            label: "Monitors"
                            active: root.page === 6
                            onClicked: root.page = 6
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰰞"
                            label: "Rules"
                            active: root.page === 7
                            onClicked: root.page = 7
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰎟"
                            label: "Notifications"
                            active: root.page === 8
                            onClicked: root.page = 8
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Theme.border
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            text: "Quickshell 0.3.2\nHyprland 0.57"
                            font.family: Theme.mono
                            font.pixelSize: 9
                            color: Theme.dim
                            lineHeight: 1.35
                        }
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        width: 1
                        color: Theme.border
                    }

                    ScrollView {
                        id: scroller

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        contentHeight: contentWrapper.implicitHeight
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Item {
                            id: contentWrapper
                            width: scroller.availableWidth
                            height: implicitHeight
                            implicitHeight: pageLoader.implicitHeight + 32

                            Loader {
                                id: pageLoader
                                x: 16
                                y: 16
                                width: parent.width - 32
                                sourceComponent: [
                                    barPage, inputPage, keybindingsPage, autostartPage,
                                    programsPage, environmentPage, monitorsPage,
                                    rulesPage, notificationsPage
                                ][root.page]
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.border
                }

                // Footer
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: root.statusColor
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.status
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: root.statusColor
                        elide: Text.ElideRight
                    }

                    SettingsButton {
                        text: "Reset"
                        onClicked: root.resetAll()
                    }

                    SettingsButton {
                        icon: "󰄬"
                        text: "Apply"
                        primary: true
                        onClicked: root.applyAll()
                    }
                }
            }
        }
    }

    Component {
        id: barPage
        BarPage { app: root }
    }

    Component {
        id: inputPage
        InputPage { app: root }
    }

    Component {
        id: keybindingsPage
        KeybindingsPage { app: root }
    }

    Component {
        id: autostartPage
        AutostartPage { app: root }
    }

    Component {
        id: programsPage
        ProgramsPage { app: root }
    }

    Component {
        id: environmentPage
        EnvironmentPage { app: root }
    }

    Component {
        id: monitorsPage
        MonitorsPage { app: root }
    }

    Component {
        id: rulesPage
        RulesPage { app: root }
    }

    Component {
        id: notificationsPage
        NotificationsPage { app: root }
    }
}
