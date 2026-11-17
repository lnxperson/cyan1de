import QtQuick
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

    readonly property string home: Quickshell.env("HOME") || "/home/fish"
    readonly property string settingsPath: home + "/.config/quickshell/settings.json"
    readonly property string hyprDir: home + "/.config/hypr/hyprland"

    property bool shown: false
    property int page: 0
    property string status: "Changes are saved automatically"
    property color statusColor: Theme.dim

    // Wallpaper
    property string wallpaperPath: ""
    property string wallpaperMode: "crop"
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

    // ---------------------------------------------------------------------
    // Defaults & persistence
    // ---------------------------------------------------------------------
    function defaults() {
        return {
            wallpaper: root.home + "/Pictures/Sollee.png",
            wallpaperMode: "crop",
            bar: {
                accent: "#7cc7f5",
                accentAlt: "#68e0c8",
                surface: "#11141b",
                pill: "#121722",
                pillBorder: "#2b3547",
                text: "#cdd6e6",
                pillHeight: 34,
                pillRadius: 12,
                sideMargin: 10,
                fontSize: 12,
                iconSize: 15,
                pillOpacity: 1.0
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

    function asBool(v, fallback) {
        return (typeof v === "boolean") ? v : fallback;
    }

    function applySettings(s) {
        const d = defaults();
        const b = (s && s.bar) || ({});
        const h = (s && s.hypr) || ({});

        wallpaperPath = asText(s && s.wallpaper, d.wallpaper);
        wallpaperMode = (s && s.wallpaperMode === "fit")
            || (s && s.wallpaperMode === "stretch")
            || (s && s.wallpaperMode === "crop")
            ? s.wallpaperMode : d.wallpaperMode;

        barAccent = asText(b.accent, d.bar.accent);
        barSurface = asText(b.surface, d.bar.surface);
        barPill = asText(b.pill, d.bar.pill);
        barPillBorder = asText(b.pillBorder, d.bar.pillBorder);
        barPillHeight = asInt(b.pillHeight, d.bar.pillHeight);
        barPillRadius = asInt(b.pillRadius, d.bar.pillRadius);
        barSideMargin = asInt(b.sideMargin, d.bar.sideMargin);
        barFontSize = asInt(b.fontSize, d.bar.fontSize);
        barIconSize = asInt(b.iconSize, d.bar.iconSize);
        barPillOpacity = asReal(b.pillOpacity, d.bar.pillOpacity);

        hyprBorder1 = asText(h.border1, d.hypr.border1);
        hyprBorder2 = asText(h.border2, d.hypr.border2);
        hyprGradient = asBool(h.gradient, d.hypr.gradient);
        hyprAngle = asInt(h.angle, d.hypr.angle);
        hyprInactive = asText(h.inactive, d.hypr.inactive);
        hyprBorderSize = asInt(h.borderSize, d.hypr.borderSize);
        hyprRounding = asInt(h.rounding, d.hypr.rounding);
        hyprGapsIn = asInt(h.gapsIn, d.hypr.gapsIn);
        hyprGapsOut = asInt(h.gapsOut, d.hypr.gapsOut);
    }

    function buildSettings() {
        return {
            wallpaper: wallpaperPath,
            wallpaperMode: wallpaperMode,
            bar: {
                accent: barAccent,
                accentAlt: "#68e0c8",
                surface: barSurface,
                pill: barPill,
                pillBorder: barPillBorder,
                text: "#cdd6e6",
                pillHeight: barPillHeight,
                pillRadius: barPillRadius,
                sideMargin: barSideMargin,
                fontSize: barFontSize,
                iconSize: barIconSize,
                pillOpacity: Math.round(barPillOpacity * 100) / 100
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
            }
        };
    }

    function saveSettings() {
        settingsWriter.setText(JSON.stringify(buildSettings(), null, 2) + "\n");
    }

    function queueSave() {
        saveDebounce.restart();
    }

    // ---------------------------------------------------------------------
    // Loading
    // ---------------------------------------------------------------------
    function loadAll() {
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
        parseEnv();
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
    // Autostart / environment list editing
    // ---------------------------------------------------------------------
    function setAutostart(index, value) {
        const copy = autostart.slice();
        if (index < 0 || index >= copy.length)
            return;
        copy[index] = value;
        autostart = copy;
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
        const copy = envVars.slice();
        if (index < 0 || index >= copy.length)
            return;
        copy[index] = { key: field === "key" ? value : copy[index].key, value: field === "value" ? value : copy[index].value };
        envVars = copy;
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

    // ---------------------------------------------------------------------
    // Generated Lua files
    // ---------------------------------------------------------------------
    function generateAutostart() {
        const lines = autostart.map(c => "    hl.exec_cmd(\"" + escLua(c) + "\")").join("\n");
        return "--------------------------------------------------------------------------------\n"
            + "-- AUTOSTART & SYSTEM INITIALIZATION\n"
            + "-- Managed by Quickshell Settings — regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + "hl.on(\"hyprland.start\", function ()\n"
            + lines + "\n"
            + "end)\n";
    }

    function generateEnv() {
        const lines = envVars.map(e => "hl.env(\"" + escLua(e.key) + "\", \"" + escLua(e.value) + "\")").join("\n");
        return "--------------------------------------------------------------------------------\n"
            + "-- ENVIRONMENT VARIABLES\n"
            + "-- Managed by Quickshell Settings — regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + lines + "\n";
    }

    function generateManaged() {
        const active = hyprGradient
            ? "{ colors = { \"" + colorToLua(hyprBorder1) + "\", \"" + colorToLua(hyprBorder2) + "\" }, angle = " + hyprAngle + " }"
            : "\"" + colorToLua(hyprBorder1) + "\"";

        return "--------------------------------------------------------------------------------\n"
            + "-- LOOK & FEEL OVERRIDES\n"
            + "-- Managed by Quickshell Settings — regenerated when you press Apply.\n"
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

    // ---------------------------------------------------------------------
    // Actions
    // ---------------------------------------------------------------------
    function selectWallpaper(path) {
        const p = String(path).trim();
        if (p.length === 0)
            return;
        wallpaperPath = p;
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

    function resetAll() {
        applySettings(defaults());
        saveDebounce.stop();
        saveSettings();
        status = "Defaults restored — press Apply for Hyprland";
        statusColor = Theme.yellow;
        statusTimer.restart();
    }

    function applyAll() {
        saveDebounce.stop();

        const files = [
            [settingsPath, JSON.stringify(buildSettings(), null, 2) + "\n"],
            [hyprDir + "/autostart.lua", generateAutostart()],
            [hyprDir + "/env.lua", generateEnv()],
            [hyprDir + "/ui_overrides.lua", generateManaged()]
        ];

        let script = "";
        for (let i = 0; i < files.length; i++) {
            const encoded = Qt.btoa(files[i][1]);
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

    function close() {
        shown = false;
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
        function section(index: int): void {
            root.page = Math.max(0, Math.min(2, index));
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

    Process {
        id: wallpaperScan
        running: false

        command: ["sh", "-c", "find \"$HOME/Pictures\" -maxdepth 3 -type f 2>/dev/null | grep -iE '\\.(png|jpg|jpeg|webp|gif)$' | sort"]

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.wallpapers = t.length > 0 ? t.split("\n") : [];
            }
        }
    }

    Shortcut {
        sequence: "Escape"
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
            radius: 18
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
                            icon: "󰸉"
                            label: "Wallpaper"
                            active: root.page === 0
                            onClicked: root.page = 0
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰒓"
                            label: "Top Bar"
                            active: root.page === 1
                            onClicked: root.page = 1
                        }

                        NavItem {
                            Layout.fillWidth: true
                            icon: "󰖲"
                            label: "Hyprland"
                            active: root.page === 2
                            onClicked: root.page = 2
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
                                sourceComponent: root.page === 0
                                    ? wallpaperPage
                                    : (root.page === 1 ? barPage : hyprlandPage)
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
        id: wallpaperPage
        WallpaperPage { app: root }
    }

    Component {
        id: barPage
        BarPage { app: root }
    }

    Component {
        id: hyprlandPage
        HyprlandPage { app: root }
    }
}
