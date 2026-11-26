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
    property bool ready: false
    property real reveal: 0
    property bool closing: false
    property bool applying: false
    property bool pendingCloseAfterApply: false
    property string pendingApplyScript: ""
    property Item dragOverlayHost: null
    property int page: 0
    property int renderedPage: 0
    property bool previousWasBarPage: false
    property bool pageSwapSnap: false
    property bool navSwapping: false
    property string appearanceSection: "panel"
    readonly property var appearanceSections: [
        { label: "Panel", value: "panel" },
        { label: "Style", value: "style" },
        { label: "Themes", value: "themes" },
        { label: "Cursor", value: "cursor" },
        { label: "Wallpaper", value: "wallpaper" }
    ]
    readonly property var appearanceSectionHints: ({
        panel: "Layout, elements, preview",
        style: "Theme mode, colours, sizing",
        themes: "Save and load appearance presets",
        cursor: "Pointer theme and size",
        wallpaper: "Wallpaper source and fit"
    })
    readonly property var appearanceSectionNames: ({
        panel: "Panel",
        style: "Style",
        themes: "Themes",
        cursor: "Cursor",
        wallpaper: "Wallpaper"
    })

    // Search spans every control, not just page titles. The results are a
    // flat index built from the same labels and help text used by the pages,
    // plus the editable lists (keybinds, rules, autostart and environment).
    property string searchQuery: ""
    property string pendingSearchLabel: ""
    readonly property bool searchActive: root.searchQuery.trim().length > 0
    property bool confirmReset: false
    readonly property string statusIdle: "Saved locally — press Apply for Hyprland changes"
    readonly property var pages: [
        { icon: "󰖲", title: "Appearance",
            subtitle: "Wallpaper, panel, theme and cursor" },
        { icon: "", title: "Windows",
            subtitle: "Borders, rounding and gaps" },
        { icon: "", title: "Effects",
            subtitle: "Animations and blur" },
        { icon: "", title: "Input",
            subtitle: "Keyboard, mouse and touchpad behavior" },
        { icon: "󰌋", title: "Keybindings",
            subtitle: "Keyboard shortcuts and window actions" },
        { icon: "󰍹", title: "Monitors",
            subtitle: "Display layout and scaling" },
        { icon: "󰥔", title: "Session",
            subtitle: "Idle dimming and screen lock" },
        { icon: "󰎟", title: "Notifications",
            subtitle: "Notification style and behavior" },
        { icon: "󰒲", title: "Autostart",
            subtitle: "Applications launched with your session" },
        { icon: "󰀻", title: "Programs",
            subtitle: "Default terminal, browser and utilities" },
        { icon: "󰫧", title: "Environment",
            subtitle: "Variables exported to every application" },
        { icon: "󰰞", title: "Rules",
            subtitle: "Window rules and per-app overrides" }
    ]
    readonly property var currentPage: pages[page] || pages[0]

    function buildSearchResults() {
        const q = root.searchQuery.trim().toLowerCase();
        if (!q)
            return [];

        const out = [];
        const seen = {};
        const add = function(label, pageIndex, section, keywords, detail) {
            const pageTitle = root.pages[pageIndex] ? root.pages[pageIndex].title : "";
            const sectionTitle = section
                ? (root.appearanceSectionNames[section] || section) : "";
            const helpText = SettingHelp.textFor(label);
            const detailText = detail && detail !== "" ? detail : helpText;
            const haystack = [label, pageTitle, sectionTitle, keywords || "",
                detailText].join(" ").toLowerCase();
            if (haystack.indexOf(q) < 0)
                return;
            const key = pageIndex + "|" + section + "|" + label + "|" + (keywords || "");
            if (seen[key])
                return;
            seen[key] = true;
            out.push({
                label: label,
                pageIndex: pageIndex,
                section: section,
                pageTitle: pageTitle,
                sectionTitle: sectionTitle,
                detail: detailText,
                keywords: keywords || ""
            });
        };

        // Appearance — Style
        add("Light mode", 0, "style", "dark theme gtk qt palette");
        add("Use wallpaper colors", 0, "style", "average tint palette accent");
        add("Accent", 0, "style", "colour gtk qt highlight");
        add("Font color", 0, "style", "colour text");
        add("Popup surface", 0, "style", "colour calendar notification");
        add("Background", 0, "style", "colour panel pill");
        add("Border", 0, "style", "colour outline");
        add("Panel height", 0, "style", "thickness size");
        add("Corner radius", 0, "style", "roundness pill panel");
        add("Side margin", 0, "style", "spacing edge screen");
        add("Text size", 0, "style", "font pixels");
        add("Icon size", 0, "style", "glyph pixels");
        add("Pill opacity", 0, "style", "transparency");

        // Appearance — Themes
        add("Save as", 0, "themes", "theme name preset", "Name for the saved appearance preset.");
        add("Save theme", 0, "themes", "preset appearance windows", "Save the current appearance and window settings.");
        add("Saved themes", 0, "themes", "load delete preset", "Saved appearance presets. Click one to load it.");

        // Appearance — Cursor
        add("Theme", 0, "cursor", "cursor pointer xcursor", "Installed cursor theme used for the mouse pointer.");
        add("Rescan", 0, "cursor", "cursor themes refresh", "Look for installed cursor themes again.");
        add("Pointer size", 0, "cursor", "cursor pixels", "Cursor size in pixels.");

        // Appearance — Panel
        add("Layout", 0, "panel", "pills unified wrap corners island");
        add("Edge", 0, "panel", "top bottom left right");
        add("Display", 0, "panel", "monitor all displays");
        add("Application menu", 0, "panel", "launcher button");
        add("Workspaces", 0, "panel", "workspace switcher");
        add("Clock", 0, "panel", "calendar date time");
        add("System tray", 0, "panel", "tray icons separator");
        add("Bluetooth", 0, "panel", "status control");
        add("Network", 0, "panel", "status control");
        add("Volume", 0, "panel", "sound status control");
        add("Brightness", 0, "panel", "display status control");
        add("Battery", 0, "panel", "laptop status control");
        add("Power", 0, "panel", "session menu");

        // Appearance — Wallpaper
        add("Wallpaper", 0, "wallpaper", "image background", "Choose the desktop wallpaper.");
        add("Scaling", 0, "wallpaper", "crop stretch fit tile");
        add("Pictures folder", 0, "wallpaper", "library directory images");
        add("Wallpaper library", 0, "wallpaper", "images browse", "Images found in the Pictures folder.");
        add("Custom path", 0, "wallpaper", "image file browse");
        add("Set wallpaper", 0, "wallpaper", "apply image", "Use the selected image as the wallpaper.");

        // Windows
        add("Active border", 1, "", "focused colour gradient");
        add("Gradient end", 1, "", "focused border colour");
        add("Inactive border", 1, "", "unfocused colour");
        add("Gradient border", 1, "", "two colour blend");
        add("Gradient angle", 1, "", "border direction");
        add("Border size", 1, "", "thickness width");
        add("Corner rounding", 1, "", "radius wrap frame");
        add("Inner gaps", 1, "", "spacing between windows");
        add("Outer gaps", 1, "", "spacing edge wrap frame display");

        // Effects
        add("Window open", 2, "", "animation appear");
        add("Window close", 2, "", "animation disappear");
        add("Workspace switch", 2, "", "animation desktop");
        add("Layer / popup", 2, "", "animation layer shell");
        add("Open easing", 2, "", "animation curve");
        add("Close easing", 2, "", "animation curve");
        add("Animation speed", 2, "", "duration global");
        add("Hyprland blur", 2, "", "transparent windows");
        add("Alacritty blur", 2, "", "terminal background");
        add("Alacritty blur strength", 2, "", "terminal amount");
        add("Hyprland blur radius", 2, "", "amount compositor");

        // Input
        add("Layout", 3, "Keyboard", "keyboard xkb us");
        add("Variant", 3, "Keyboard", "keyboard xkb dvorak nodeadkeys");
        add("Model", 3, "Keyboard", "keyboard xkb hardware");
        add("Options", 3, "Keyboard", "keyboard xkb comma");
        add("Rules", 3, "Keyboard", "keyboard xkb");
        add("Follow mouse", 3, "Pointer", "active monitor pointer");
        add("Sensitivity", 3, "Pointer", "mouse speed", "Mouse movement sensitivity multiplier.");
        add("Accel profile", 3, "Pointer", "libinput flat adaptive");
        add("Disable acceleration", 3, "Pointer", "libinput raw input");
        add("Natural scrolling", 3, "Touchpad", "reverse scroll direction");
        add("Fingers", 3, "Gestures", "touchpad swipe count");
        add("Direction", 3, "Gestures", "swipe horizontal vertical");
        add("Action", 3, "Gestures", "swipe workspace");
        add("Device name", 3, "Per-device override", "libinput hardware");
        add("Sensitivity", 3, "Per-device override", "device speed",
            "Optional sensitivity override for a named device.");

        // Keybindings
        add("Bind", 4, "", "shortcut keys", "Shortcut keys assigned to an action.");
        add("Command", 4, "", "action keysbind", "Command run by a shortcut.");
        add("Label", 4, "", "description shortcut", "Description shown for a shortcut.");
        add("Add keybinding", 4, "", "new shortcut", "Add a new keyboard shortcut.");
        const binds = root.keybinds || [];
        for (let i = 0; i < binds.length; i++) {
            const bind = binds[i];
            add(bind.label || "Keybinding", 4, "",
                String(bind.bind || "") + " " + String(bind.command || ""),
                String(bind.command || ""));
        }

        // Monitors
        add("Display arrangement", 5, "", "drag outputs layout positions");
        add("Resolution", 5, "", "display pixels");
        add("Refresh rate", 5, "", "display hz");
        add("Scale", 5, "", "display hidpi factor");
        add("Rotation", 5, "", "display portrait landscape");
        add("Enabled", 5, "", "display turn on off");
        add("Re-detect", 5, "", "refresh outputs monitors");

        // Session
        add("Auto dim and lock", 6, "", "hypridle idle");
        add("Dim screen", 6, "", "idle brightness");
        add("Dim after", 6, "", "idle timeout seconds");
        add("Dim brightness", 6, "", "idle percentage");
        add("Lock screen", 6, "", "idle timeout");
        add("Lock after", 6, "", "idle timeout seconds");

        // Notifications
        add("Position", 7, "", "popup edge side");
        add("Display time", 7, "", "popup duration timeout");
        add("Max popups", 7, "", "banner limit count");
        add("Pause on hover", 7, "", "banner mouse");
        add("Persistent popups", 7, "", "banner dismiss timeout");
        add("Low battery warning", 7, "", "power notification");
        add("Warn at", 7, "", "battery percentage threshold");
        add("Notification history", 7, "", "calendar dismissed list");
        add("Media controls", 7, "", "calendar now playing");
        add("Media position", 7, "", "calendar above below");
        add("Popup width", 7, "", "calendar notification width");
        add("Show app icon", 7, "", "notification source icon");
        add("Show app name", 7, "", "notification source title");
        add("Send test notification", 7, "", "preview banner", "Send a test notification banner.");
        add("Clear popups", 7, "", "dismiss banners", "Dismiss all active notification banners.");

        // Autostart
        add("Autostart commands", 8, "", "startup login hyprland", "Commands run when Hyprland starts.");
        add("Add command", 8, "", "startup login", "Add an autostart command.");
        const autoList = root.autostart || [];
        for (let i = 0; i < autoList.length; i++)
            add("Command " + (i + 1), 8, "", String(autoList[i]), String(autoList[i]));

        // Programs
        add("Terminal", 9, "", "alacritty console");
        add("File manager", 9, "", "nautilus files");
        add("Launcher", 9, "", "application menu");
        add("Browser", 9, "", "web firefox");
        add("Text editor", 9, "", "editor files");
        add("Image viewer", 9, "", "photos pictures");
        add("PDF viewer", 9, "", "documents");
        add("Screenshot", 9, "", "capture hyprshot");

        // Environment
        add("Variable", 10, "", "env export key value");
        add("Add variable", 10, "", "env export new", "Add an exported environment variable.");
        const envList = root.envVars || [];
        for (let i = 0; i < envList.length; i++) {
            const env = envList[i];
            add(String(env.key || ("Variable " + (i + 1))), 10, "",
                String(env.value || ""), String(env.value || ""));
        }

        // Rules
        add("Window rule", 11, "", "match floating position", "Read-only overview of active window rules.");
        const ruleList = root.rules || [];
        for (let i = 0; i < ruleList.length; i++) {
            const rule = ruleList[i];
            add(String(rule.name || ("Rule " + (i + 1))), 11, "",
                String(rule.match || ""), String(rule.match || ""));
        }

        return out;
    }

    readonly property var searchResults: root.buildSearchResults()
    readonly property var groupedSearchResults: {
        const groups = [];
        const lookup = {};
        const list = root.searchResults;
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            const key = item.pageIndex + "|" + item.section;
            if (!lookup[key]) {
                lookup[key] = {
                    pageIndex: item.pageIndex,
                    pageTitle: item.pageTitle,
                    section: item.section,
                    sectionTitle: item.sectionTitle,
                    items: []
                };
                groups.push(lookup[key]);
            }
            lookup[key].items.push(item);
        }
        return groups;
    }

    property string status: statusIdle
    property color statusColor: Theme.dim

    // The settings card keeps its native layout and is scaled as a whole when
    // Hyprland reports a small logical surface (high display scale). Letting
    // the layout reflow into that tiny surface is what pushed rows off screen.
    readonly property real settingsBaseWidth: 1100
    readonly property real settingsBaseHeight: 720

    // Sliding sidebar highlight, driven by the same rect-sync pattern as the
    // top bar's action indicator.
    property rect navHighlightRect: Qt.rect(0, 0, 0, 0)
    property bool navHighlightVisible: false
    property bool navHighlightAnimate: false

    function navHighlightGeometry() {
        const item = navRepeater.itemAt(root.page);
        if (!item || !navList)
            return null;
        const origin = item.mapToItem(navList, 0, 0);
        return Qt.rect(0, origin.y, navList.width, item.height);
    }

    function syncNavHighlight() {
        const rect = root.navHighlightGeometry();
        if (!rect) {
            root.navHighlightVisible = false;
            root.navHighlightAnimate = false;
            return;
        }

        if (!root.navHighlightVisible) {
            // First layout snaps into place; later page changes slide.
            root.navHighlightAnimate = false;
            root.navHighlightRect = rect;
            root.navHighlightVisible = true;
            Qt.callLater(function () {
                if (root.navHighlightVisible)
                    root.navHighlightAnimate = true;
            });
        } else {
            root.navHighlightRect = rect;
        }
    }

    Component.onCompleted: {
        root.ready = true;
        Qt.callLater(root.syncNavHighlight);
    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    // Page swaps cross-fade the old page into the new one while the sidebar
    // highlight slides between rows.
    Connections {
        target: root

        function onPageChanged() {
            // Cross-fade the outgoing page into the incoming one so the
            // content area never empties out mid-swap.
            previousWasBarPage = renderedPage === 0;

            navSwapping = true;
            navSwapTimer.restart();

            pageSwapSnap = true;
            previousPageLoader.sourceComponent = pageLoader.sourceComponent;
            previousPageLoader.opacity = 1;
            renderedPage = page;
            pageLoader.opacity = 0;
            pageSwapSnap = false;

            pageLoader.opacity = 1;
            previousPageLoader.opacity = 0;
            scroller.contentItem.contentY = 0;
            pageFadeTimer.restart();
            root.syncNavHighlight();
        }

        function onSearchQueryChanged() {
            scroller.contentItem.contentY = 0;
            revealTimer.stop();
        }
    }

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

    // Saved appearance + window themes
    readonly property string themesPath: home + "/.config/quickshell/themes.json"
    property var themeNames: []
    property var themePreviews: ({})
    property string selectedTheme: ""
    property string newThemeName: ""

    // Cursor
    property string cursorTheme: "default"
    property int cursorSize: 24
    property var cursorThemes: []
    readonly property var cursorThemeOptions: {
        const list = root.cursorThemes.slice();
        if (list.indexOf("default") < 0)
            list.unshift("default");
        if (root.cursorTheme && list.indexOf(root.cursorTheme) < 0)
            list.push(root.cursorTheme);
        return list;
    }
    readonly property var cursorThemeLabels: {
        const labels = {};
        const list = root.cursorThemeOptions;
        for (let i = 0; i < list.length; i++) {
            const value = list[i];
            labels[value] = value === "default"
                ? "System default"
                : String(value).replace(/_/g, " ").replace(/-/g, " ");
        }
        return labels;
    }

    // Bar
    readonly property string gtkAccentHelper: home
        + "/.config/quickshell/settings/apply-gtk-accent.sh"
    property string barAccent: "#7cc7f5"
    onBarAccentChanged: {
        if (root.ready && root.shown)
            gtkAccentDebounce.restart();
    }
    property string barSurface: "#11141b"
    property string barPill: "#121722"
    property string barPillBorder: "#2b3547"
    property string barText: "#cdd6e6"
    // Layouts are now exposed as single choices instead of a unified bar plus
    // a separate corners toggle. Old unifiedCorners and unifiedRamp settings
    // migrate to the attached variants on load.
    property string barLayout: "pills"
    property string barEdge: "top"
    property string barDisplay: "all"
    readonly property bool barUnifiedCorners: barLayout === "unifiedCorners"
        || barLayout === "unifiedWrap"
    readonly property var barLayoutOptions: ["pills", "unified",
        "unifiedCorners", "unifiedWrap", "island"]
    readonly property var barLayoutLabels: ({
        "pills": "Floating pills",
        "unified": "Unified bar",
        "unifiedCorners": "Unified + corners",
        "unifiedWrap": "Unified + wrap",
        "island": "Floating island"
    })
    readonly property var barEdgeOptions: ["top", "bottom", "left", "right"]
    readonly property var barEdgeLabels: ({
        "top": "Top",
        "bottom": "Bottom",
        "left": "Left",
        "right": "Right"
    })
    property int barPanelHeight: 34
    property int barPillRadius: 12
    property int barSideMargin: 10
    property int barFontSize: 12
    property int barIconSize: 15
    property real barPillOpacity: 1.0
    property bool calendarMedia: true
    property string calendarMediaPosition: "bottom"
    property string calendarNotificationsSide: "right"
    property int calendarWidth: 680

    // Individual panel elements. All are visible by default so existing
    // configs keep the panel they already have.
    property bool barShowAppMenu: true
    property bool barShowWorkspaces: true
    property bool barShowClock: true
    property bool barShowTray: true
    property bool barShowBluetooth: true
    property bool barShowNetwork: true
    property bool barShowVolume: true
    property bool barShowBrightness: true
    property bool barShowBattery: true
    property bool barShowPower: true

    readonly property var barElementKeys: [
        "appMenu", "workspaces", "clock", "tray", "bluetooth",
        "network", "volume", "brightness", "battery", "power"
    ]
    readonly property var barSectionKeys: ["left", "center", "right"]
    property var barElementLayout: ({
        left: ["appMenu", "workspaces"],
        center: ["clock"],
        right: ["tray", "bluetooth", "network", "volume",
                "brightness", "battery", "power"]
    })

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
    property bool calendarNotifications: true
    property bool lowBatteryEnabled: true
    property int lowBatteryThreshold: 20

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
    property bool hyprBlur: true
    property int hyprBlurSize: 10
    property bool alacrittyBlur: true
    property int alacrittyBlurStrength: 60

    // Animations (hyprland/animations.lua is generated on Apply)
    property string animWindowOpen: "popin 87%"
    property string animWindowClose: "popin 87%"
    property string animWorkspace: "slide"
    property string animLayer: "fade"
    property string animOpenCurve: "easy"
    property string animCloseCurve: "linear"
    property int animSpeed: 10
    // Curated from the Hyprland 0.57.2 animation tree: one entry per distinct
    // animation (no duplicated popin scales or gnome/gnomed aliases). Values
    // stay canonical so generated animations.lua is unchanged; labels are for UI.
    readonly property var windowAnimStyles: [
        "popin 87%", "gnomed",
        "slide", "slide top", "slide bottom", "slide left", "slide right"
    ]
    readonly property var workspaceAnimStyles: [
        "fade", "slidevert", "slidefadevert",
        "slide", "slide top", "slide bottom", "slide left", "slide right",
        "slidefade", "slidefade top", "slidefade bottom",
        "slidefade left", "slidefade right"
    ]
    readonly property var layerAnimStyles: [
        "fade", "popin 87%",
        "slide", "slide top", "slide bottom", "slide left", "slide right"
    ]
    // Named easing curves already declared in animations.lua - no free text.
    readonly property var animCurves: [
        "easeOutQuint", "easeInOutCubic", "almostLinear", "quick", "linear", "easy"
    ]
    readonly property var animCurveLabels: ({
        "easeOutQuint": "Smooth Out",
        "easeInOutCubic": "Smooth In-Out",
        "almostLinear": "Almost Linear",
        "quick": "Snappy",
        "linear": "Linear",
        "easy": "Springy"
    })
    readonly property var animCurveKinds: ({
        "easeOutQuint": "bezier", "easeInOutCubic": "bezier",
        "almostLinear": "bezier", "quick": "bezier", "linear": "bezier",
        "easy": "spring"
    })

    function animCurveExpr(name) {
        const kind = animCurveKinds[name] === "spring" ? "spring" : "bezier";
        return kind + " = \"" + name + "\"";
    }
    readonly property var animStyleLabels: ({
        "popin 87%": "Pop In",
        "gnomed": "Center Expand",
        "slide": "Slide In",
        "slide top": "Slide In from Top",
        "slide bottom": "Slide In from Bottom",
        "slide left": "Slide In from Left",
        "slide right": "Slide In from Right",
        "fade": "Fade",
        "slidevert": "Vertical Slide",
        "slidefadevert": "Vertical Slide + Fade",
        "slidefade": "Slide + Fade",
        "slidefade top": "Slide + Fade from Top",
        "slidefade bottom": "Slide + Fade from Bottom",
        "slidefade left": "Slide + Fade from Left",
        "slidefade right": "Slide + Fade from Right"
    })

    // Idle handling (hypridle.conf is generated on Apply)
    property bool idleEnabled: true
    property bool idleDimEnabled: true
    property int idleDimTimeout: 150
    property int idleDimLevel: 10
    property bool idleLockEnabled: true
    property int idleLockTimeout: 300

    // Raw alacritty.toml, kept verbatim so only the opacity line is patched.
    property string alacrittyText: ""

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
            cursor: {
                theme: "default",
                size: 24
            },
            bar: {
                accent: "#7cc7f5",
                surface: "#11141b",
                pill: "#121722",
                pillBorder: "#2b3547",
                text: "#cdd6e6",
                layout: "pills",
                edge: "top",
                display: "all",
                unifiedCorners: false,
                panelHeight: 34,
                pillRadius: 12,
                sideMargin: 10,
                fontSize: 12,
                iconSize: 15,
                pillOpacity: 1.0,
                calendarMedia: true,
                calendarMediaPosition: "bottom",
                calendarNotificationsSide: "right",
                calendarWidth: 680,
                elements: {
                    appMenu: true,
                    workspaces: true,
                    clock: true,
                    tray: true,
                    bluetooth: true,
                    network: true,
                    volume: true,
                    brightness: true,
                    battery: true,
                    power: true
                },
                elementLayout: {
                    left: ["appMenu", "workspaces"],
                    center: ["clock"],
                    right: ["tray", "bluetooth", "network", "volume",
                            "brightness", "battery", "power"]
                },
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
                gapsOut: 5,
                blur: true,
                blurSize: 10,
                alacrittyBlur: true,
                alacrittyBlurStrength: 60,
                animWindowOpen: "popin 87%",
                animWindowClose: "popin 87%",
                animWorkspace: "slide",
                animLayer: "fade",
                animOpenCurve: "easy",
                animCloseCurve: "linear",
                animSpeed: 10
            },
            idle: {
                enabled: true,
                dim: true,
                dimTimeout: 150,
                dimLevel: 10,
                lock: true,
                lockTimeout: 300
            },
            notifications: {
                position: "top-right",
                timeout: 5000,
                maxVisible: 4,
                pauseOnHover: true,
                persistent: false,
                showAppIcon: true,
                showAppName: true,
                calendarNotifications: true,
                lowBatteryEnabled: true,
                lowBatteryThreshold: 20
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

    function defaultBarElementSection(key) {
        if (key === "appMenu" || key === "workspaces") return "left";
        if (key === "clock") return "center";
        return "right";
    }

    // Keep saved layouts complete and free of duplicates. Unknown keys are
    // ignored and anything missing returns to its original section.
    function normalizeBarElementLayout(layout) {
        const fallback = defaults().bar.elementLayout;
        const out = { left: [], center: [], right: [] };
        const seen = {};
        for (let s = 0; s < root.barSectionKeys.length; s++) {
            const section = root.barSectionKeys[s];
            const list = layout && Array.isArray(layout[section])
                ? layout[section] : fallback[section];
            for (let i = 0; i < list.length; i++) {
                const key = list[i];
                if (root.barElementKeys.indexOf(key) < 0 || seen[key])
                    continue;
                out[section].push(key);
                seen[key] = true;
            }
        }
        for (let i = 0; i < root.barElementKeys.length; i++) {
            const key = root.barElementKeys[i];
            if (!seen[key])
                out[defaultBarElementSection(key)].push(key);
        }
        return out;
    }

    function moveBarElement(key, section, index) {
        if (root.barElementKeys.indexOf(key) < 0
            || root.barSectionKeys.indexOf(section) < 0)
            return;
        const next = { left: [], center: [], right: [] };
        for (let s = 0; s < root.barSectionKeys.length; s++) {
            const name = root.barSectionKeys[s];
            const list = barElementLayout[name] || [];
            for (let i = 0; i < list.length; i++) {
                if (list[i] !== key)
                    next[name].push(list[i]);
            }
        }
        const target = next[section];
        const at = (typeof index === "number")
            ? Math.max(0, Math.min(index, target.length)) : target.length;
        target.splice(at, 0, key);
        barElementLayout = normalizeBarElementLayout(next);
        queueSave();
    }

    function applySettings(s) {
        const d = defaults();
        const b = (s && s.bar) || ({});
        const p = b.pills || ({});
        const e = b.elements || ({});
        const h = (s && s.hypr) || ({});
        const idle = (s && s.idle) || ({});
        const n = (s && s.notifications) || ({});
        const c = (s && s.cursor) || ({});

        wallpaperPath = asText(s && s.wallpaper, d.wallpaper);
        wallpaperMode = (s && s.wallpaperMode === "fit")
            || (s && s.wallpaperMode === "stretch")
            || (s && s.wallpaperMode === "crop")
            ? s.wallpaperMode : d.wallpaperMode;
        themeMode = (s && s.themeMode === "light") ? "light" : d.themeMode;
        cursorTheme = asText(c.theme, d.cursor.theme);
        cursorSize = Math.max(8, Math.min(96,
            asInt(c.size, d.cursor.size)));

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
        barText = asText(b.text, d.bar.text);
        const layoutOptions = ["pills", "unified", "unifiedCorners",
            "unifiedWrap", "island"];
        const legacyCorners = asBool(b.unifiedCorners, d.bar.unifiedCorners);
        barLayout = (b.layout === "unifiedRamp")
            ? "unifiedWrap"
            : ((b.layout === "unified" && legacyCorners)
                ? "unifiedCorners"
                : (layoutOptions.indexOf(b.layout) >= 0
                    ? b.layout : d.bar.layout));
        barEdge = ["top", "bottom", "left", "right"].indexOf(b.edge) >= 0
            ? b.edge : d.bar.edge;
        barDisplay = asText(b.display, d.bar.display);
        // Old configs stored the visible pill thickness under pillHeight.
        // The new panelHeight value is that same thickness for every layout.
        barPanelHeight = Math.max(30, Math.min(56,
            b.panelHeight !== undefined
                ? asInt(b.panelHeight, d.bar.panelHeight)
                : asInt(b.pillHeight, d.bar.panelHeight)));
        barPillRadius = asInt(b.pillRadius, d.bar.pillRadius);
        barSideMargin = asInt(b.sideMargin, d.bar.sideMargin);
        barFontSize = asInt(b.fontSize, d.bar.fontSize);
        barIconSize = asInt(b.iconSize, d.bar.iconSize);
        barPillOpacity = asReal(b.pillOpacity, d.bar.pillOpacity);
        calendarMedia = asBool(b.calendarMedia, d.bar.calendarMedia);
        calendarMediaPosition = ["top", "bottom"].indexOf(b.calendarMediaPosition) >= 0
            ? b.calendarMediaPosition : d.bar.calendarMediaPosition;
        calendarNotificationsSide = ["left", "right"].indexOf(b.calendarNotificationsSide) >= 0
            ? b.calendarNotificationsSide : d.bar.calendarNotificationsSide;
        calendarWidth = Math.max(380, Math.min(1100,
            asInt(b.calendarWidth, d.bar.calendarWidth)));
        barShowAppMenu = asBool(e.appMenu, d.bar.elements.appMenu);
        barShowWorkspaces = asBool(e.workspaces, d.bar.elements.workspaces);
        barShowClock = asBool(e.clock, d.bar.elements.clock);
        barShowTray = asBool(e.tray, d.bar.elements.tray);
        barShowBluetooth = asBool(e.bluetooth, d.bar.elements.bluetooth);
        barShowNetwork = asBool(e.network, d.bar.elements.network);
        barShowVolume = asBool(e.volume, d.bar.elements.volume);
        barShowBrightness = asBool(e.brightness, d.bar.elements.brightness);
        barShowBattery = asBool(e.battery, d.bar.elements.battery);
        barShowPower = asBool(e.power, d.bar.elements.power);
        barElementLayout = normalizeBarElementLayout(b.elementLayout);
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
        hyprBlur = asBool(h.blur, d.hypr.blur);
        hyprBlurSize = Math.max(1, Math.min(20,
            asInt(h.blurSize, d.hypr.blurSize)));
        alacrittyBlur = asBool(h.alacrittyBlur, d.hypr.alacrittyBlur);
        alacrittyBlurStrength = Math.max(0, Math.min(100,
            asInt(h.alacrittyBlurStrength, d.hypr.alacrittyBlurStrength)));

        animWindowOpen = windowAnimStyles.indexOf(h.animWindowOpen) >= 0
            ? h.animWindowOpen : d.hypr.animWindowOpen;
        animWindowClose = windowAnimStyles.indexOf(h.animWindowClose) >= 0
            ? h.animWindowClose : d.hypr.animWindowClose;
        animWorkspace = workspaceAnimStyles.indexOf(h.animWorkspace) >= 0
            ? h.animWorkspace : d.hypr.animWorkspace;
        animLayer = layerAnimStyles.indexOf(h.animLayer) >= 0
            ? h.animLayer : d.hypr.animLayer;
        animOpenCurve = animCurves.indexOf(h.animOpenCurve) >= 0
            ? h.animOpenCurve : d.hypr.animOpenCurve;
        animCloseCurve = animCurves.indexOf(h.animCloseCurve) >= 0
            ? h.animCloseCurve : d.hypr.animCloseCurve;
        animSpeed = Math.max(1, Math.min(20,
            asInt(h.animSpeed, d.hypr.animSpeed)));

        idleEnabled = asBool(idle.enabled, d.idle.enabled);
        idleDimEnabled = asBool(idle.dim, d.idle.dim);
        idleDimTimeout = Math.max(30, Math.min(1800,
            asInt(idle.dimTimeout, d.idle.dimTimeout)));
        idleDimLevel = Math.max(1, Math.min(100,
            asInt(idle.dimLevel, d.idle.dimLevel)));
        idleLockEnabled = asBool(idle.lock, d.idle.lock);
        idleLockTimeout = Math.max(60, Math.min(1800,
            asInt(idle.lockTimeout, d.idle.lockTimeout)));

        notifyPosition = ["top-left", "top-right", "bottom-left", "bottom-right"]
            .indexOf(n.position) >= 0 ? n.position : d.notifications.position;
        notifyTimeout = Math.max(1000, asInt(n.timeout, d.notifications.timeout));
        notifyMaxVisible = Math.min(8, Math.max(1, asInt(n.maxVisible, d.notifications.maxVisible)));
        notifyPauseOnHover = asBool(n.pauseOnHover, d.notifications.pauseOnHover);
        notifyPersistent = asBool(n.persistent, d.notifications.persistent);
        notifyShowAppIcon = asBool(n.showAppIcon, d.notifications.showAppIcon);
        notifyShowAppName = asBool(n.showAppName, d.notifications.showAppName);
        calendarNotifications = asBool(n.calendarNotifications, d.notifications.calendarNotifications);
        lowBatteryEnabled = asBool(n.lowBatteryEnabled, d.notifications.lowBatteryEnabled);
        lowBatteryThreshold = Math.max(5, Math.min(50,
            asInt(n.lowBatteryThreshold, d.notifications.lowBatteryThreshold)));
    }

    function buildSettings() {
        return {
            themeMode: themeMode,
            themeColors: themeColors,
            wallpaper: wallpaperPath,
            wallpaperMode: wallpaperMode,
            cursor: {
                theme: cursorTheme,
                size: cursorSize
            },
            bar: {
                accent: barAccent,
                surface: barSurface,
                pill: barPill,
                pillBorder: barPillBorder,
                text: barText,
                layout: barLayout,
                edge: barEdge,
                display: barDisplay,
                unifiedCorners: barUnifiedCorners,
                panelHeight: barPanelHeight,
                pillRadius: barPillRadius,
                sideMargin: barSideMargin,
                fontSize: barFontSize,
                iconSize: barIconSize,
                pillOpacity: Math.round(barPillOpacity * 100) / 100,
                calendarMedia: calendarMedia,
                calendarMediaPosition: calendarMediaPosition,
                calendarNotificationsSide: calendarNotificationsSide,
                calendarWidth: calendarWidth,
                elements: {
                    appMenu: barShowAppMenu,
                    workspaces: barShowWorkspaces,
                    clock: barShowClock,
                    tray: barShowTray,
                    bluetooth: barShowBluetooth,
                    network: barShowNetwork,
                    volume: barShowVolume,
                    brightness: barShowBrightness,
                    battery: barShowBattery,
                    power: barShowPower
                },
                elementLayout: barElementLayout,
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
                gapsOut: hyprGapsOut,
                blur: hyprBlur,
                blurSize: hyprBlurSize,
                alacrittyBlur: alacrittyBlur,
                alacrittyBlurStrength: alacrittyBlurStrength,
                animWindowOpen: animWindowOpen,
                animWindowClose: animWindowClose,
                animWorkspace: animWorkspace,
                animLayer: animLayer,
                animOpenCurve: animOpenCurve,
                animCloseCurve: animCloseCurve,
                animSpeed: animSpeed
            },
            idle: {
                enabled: idleEnabled,
                dim: idleDimEnabled,
                dimTimeout: idleDimTimeout,
                dimLevel: idleDimLevel,
                lock: idleLockEnabled,
                lockTimeout: idleLockTimeout
            },
            notifications: {
                position: notifyPosition,
                timeout: notifyTimeout,
                maxVisible: notifyMaxVisible,
                pauseOnHover: notifyPauseOnHover,
                persistent: notifyPersistent,
                showAppIcon: notifyShowAppIcon,
                showAppName: notifyShowAppName,
                calendarNotifications: calendarNotifications,
                lowBatteryEnabled: lowBatteryEnabled,
                lowBatteryThreshold: lowBatteryThreshold
            }
        };
    }

    function saveSettings() {
        settingsWriter.setText(JSON.stringify(buildSettings(), null, 2) + "\n");
    }

    function queueSave() {
        saveDebounce.restart();
    }

    // Layout, edge, display and outer-gap changes must refresh the generated
    // gaps right away. The panel updates from settings.json, but Hyprland reads
    // ui_overrides.lua, so leaving that file stale keeps wrap-only gaps alive
    // after switching away from unified + wrap. Only this managed file is
    // rewritten; other Hyprland files may contain live user edits.
    function queueManaged() {
        if (!shown)
            return;
        saveDebounce.restart();
        managedDebounce.restart();
    }

    function applyManaged() {
        if (!shown)
            return;
        const encoded = b64Utf8(generateManaged());
        Quickshell.execDetached(["sh", "-c",
            "printf '%s' '" + encoded + "' | base64 -d > '" + hyprDir
                + "/ui_overrides.lua' && hyprctl reload >/dev/null 2>&1"]);
        status = "Window gaps updated";
        statusColor = Theme.green;
        statusTimer.restart();
    }

    function themeGtkName(mode) {
        return mode === "light" ? "cyan1de-light" : "cyan1de-dark";
    }

    function themeScheme(mode) {
        return mode === "light" ? "prefer-light" : "prefer-dark";
    }

    // GTK4/libadwaita only accept one of nine named accents. Pick the closest
    // match to the exact panel accent; GTK3 and Qt get the exact colour through
    // the generated themes below.
    function gtkAccentName(value) {
        const accents = ({
            blue: "#3584e4", teal: "#2190a4", green: "#3a944a",
            yellow: "#c88800", orange: "#ed5b00", red: "#e62d42",
            pink: "#d56199", purple: "#9141ac", slate: "#6f8396"
        });
        const names = Object.keys(accents);
        const raw = String(value || "").trim();
        let hex = raw.replace("#", "");
        if (hex.length === 3)
            hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
        if (hex.length !== 6 || !/^[0-9a-fA-F]+$/.test(hex))
            return "blue";

        const rgb = [parseInt(hex.slice(0, 2), 16),
            parseInt(hex.slice(2, 4), 16), parseInt(hex.slice(4, 6), 16)];
        const weights = [0.30, 0.59, 0.11];
        let best = names[0];
        let bestDistance = Infinity;
        for (let i = 0; i < names.length; i++) {
            const candidate = hexToRgb(accents[names[i]]);
            let distance = 0;
            for (let c = 0; c < 3; c++)
                distance += weights[c] * (rgb[c] - candidate[c]) * (rgb[c] - candidate[c]);
            if (distance < bestDistance) {
                bestDistance = distance;
                best = names[i];
            }
        }
        return best;
    }

    function isThemedAutostartCommand(command) {
        return command.indexOf(root.gtkAccentHelper) === 0
            || command.indexOf("~/.config/quickshell/settings/apply-gtk-accent.sh") === 0
            || command.indexOf("gsettings set org.gnome.desktop.interface gtk-theme") === 0
            || command.indexOf("gsettings set org.gnome.desktop.interface color-scheme") === 0
            || command.indexOf("gsettings set org.gnome.desktop.interface accent-color") === 0;
    }

    function themedAutostart(mode) {
        const helper = root.gtkAccentHelper + " '" + barAccent + "' '" + mode + "'";
        const out = [];
        let inserted = false;
        for (let i = 0; i < autostart.length; i++) {
            const command = autostart[i];
            if (isThemedAutostartCommand(command)) {
                if (!inserted) {
                    out.push(helper);
                    inserted = true;
                }
                continue;
            }
            out.push(command);
        }
        if (!inserted)
            out.push(helper);
        return out;
    }

    function applyGtkTheme(mode) {
        Quickshell.execDetached([root.gtkAccentHelper, barAccent, mode]);
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

    function isCursorEnvKey(key) {
        return ["XCURSOR_THEME", "HYPRCURSOR_THEME",
            "XCURSOR_SIZE", "HYPRCURSOR_SIZE"].indexOf(key) >= 0;
    }

    function cursorThemeLabel(value) {
        if (value === "default")
            return "System default";
        return String(value).replace(/_/g, " ").replace(/-/g, " ");
    }

    function applyCursor() {
        Quickshell.execDetached(["hyprctl", "setcursor", cursorTheme, String(cursorSize)]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface",
            "cursor-theme", cursorTheme]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface",
            "cursor-size", String(cursorSize)]);
    }

    function setCursorTheme(value) {
        const theme = String(value).trim();
        if (theme.length === 0 || theme === cursorTheme)
            return;
        cursorTheme = theme;
        if (cursorThemes.indexOf(theme) < 0)
            cursorThemes = cursorThemes.concat([theme]);
        applyCursor();
        saveSettings();
        status = "Cursor theme: " + cursorThemeLabel(theme);
        statusColor = Theme.green;
        statusTimer.restart();
    }

    function setCursorSize(value) {
        const size = Math.max(8, Math.min(96,
            Math.round(asInt(value, cursorSize))));
        if (size === cursorSize)
            return;
        cursorSize = size;
        applyCursor();
        queueSave();
        status = "Cursor size: " + size + "px";
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

    function clampByte(value) {
        return Math.max(0, Math.min(255, Math.round(Number(value) || 0)));
    }

    function hexToRgb(value) {
        const h = String(value || "").replace("#", "");
        if (h.length === 3)
            return [parseInt(h[0] + h[0], 16), parseInt(h[1] + h[1], 16),
                parseInt(h[2] + h[2], 16)];
        if (h.length < 6) return [0, 0, 0];
        return [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16),
            parseInt(h.slice(4, 6), 16)];
    }

    function rgbToHex(rgb) {
        const part = function (value) {
            const h = clampByte(value).toString(16);
            return h.length === 1 ? "0" + h : h;
        };
        return "#" + part(rgb[0]) + part(rgb[1]) + part(rgb[2]);
    }

    function mixRgb(a, b, amount) {
        const t = Math.max(0, Math.min(1, amount));
        return [
            a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t
        ];
    }

    function rgbLuma(rgb) {
        return (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255;
    }

    function saturateRgb(rgb, amount) {
        const luma = rgbLuma(rgb) * 255;
        return [
            clampByte(luma + (rgb[0] - luma) * amount),
            clampByte(luma + (rgb[1] - luma) * amount),
            clampByte(luma + (rgb[2] - luma) * amount)
        ];
    }

    function brightenRgb(rgb, factor) {
        return [
            clampByte(rgb[0] * factor),
            clampByte(rgb[1] * factor),
            clampByte(rgb[2] * factor)
        ];
    }

    function applyWallpaperAverage(r, g, b) {
        const avg = saturateRgb([clampByte(r), clampByte(g), clampByte(b)], 1.12);
        const light = themeMode === "light";

        let accent = saturateRgb(mixRgb(avg, hexToRgb("#7cc7f5"), 0.28), 1.06);
        if (light) {
            if (rgbLuma(accent) > 0.80)
                accent = mixRgb(accent, [20, 40, 60], 0.28);
            else if (rgbLuma(accent) < 0.32)
                accent = brightenRgb(accent, 1.16);
        } else {
            if (rgbLuma(accent) < 0.46)
                accent = brightenRgb(accent, 1.20);
            else if (rgbLuma(accent) > 0.88)
                accent = mixRgb(accent, [17, 20, 27], 0.10);
        }

        const textAnchor = light ? [20, 28, 40] : [255, 255, 255];
        const surfaceAnchor = light ? [245, 246, 248] : [17, 20, 27];
        const pillAnchor = light ? [255, 255, 255] : [23, 27, 36];
        const borderAnchor = light ? [184, 192, 204] : [43, 53, 71];

        barAccent = rgbToHex(accent);
        barText = rgbToHex(mixRgb(avg, textAnchor, light ? 0.66 : 0.64));
        setBarColor("surface", rgbToHex(mixRgb(avg, surfaceAnchor, light ? 0.74 : 0.72)));
        setBarColor("pill", rgbToHex(mixRgb(avg, pillAnchor, light ? 0.62 : 0.60)));
        barPillBorder = rgbToHex(mixRgb(avg, borderAnchor, light ? 0.48 : 0.42));
        queueSave();

        status = "Applied wallpaper colors";
        statusColor = Theme.green;
        statusTimer.restart();
    }

    function applyWallpaperColors() {
        if (!root.resolvedWallpaperPath || root.resolvedWallpaperPath.length === 0) {
            status = "Choose a wallpaper first";
            statusColor = Theme.yellow;
            statusTimer.restart();
            return;
        }

        wallpaperColorProcess.command = ["sh", "-c", root.wallpaperColorScript,
            "cyan1de-wallpaper-color", root.b64Utf8(root.resolvedWallpaperPath)];
        wallpaperColorProcess.running = false;
        wallpaperColorProcess.running = true;
        status = "Sampling wallpaper…";
        statusColor = Theme.subtext;
        statusTimer.restart();
    }

    function sanitizeThemeName(value) {
        return String(value || "").trim().replace(/\s+/g, " ").substring(0, 60);
    }

    function readThemeStore() {
        try {
            reloadFile(themesFile);
            const raw = themesFile.text();
            if (!raw || !raw.trim())
                return {};
            const parsed = JSON.parse(raw);
            return parsed && typeof parsed === "object" && !Array.isArray(parsed)
                ? parsed : {};
        } catch (e) {
            return {};
        }
    }

    function persistThemeStore(store) {
        themesWriter.setText(JSON.stringify(store, null, 2) + "\n");
        themesWriter.waitForJob();
    }

    function captureThemeSnapshot() {
        const current = buildSettings();
        return JSON.parse(JSON.stringify({
            themeMode: current.themeMode,
            themeColors: current.themeColors,
            wallpaper: current.wallpaper,
            wallpaperMode: current.wallpaperMode,
            cursor: current.cursor,
            bar: current.bar,
            hypr: current.hypr
        }));
    }

    function reloadThemes() {
        const store = readThemeStore();
        const previews = {};
        themeNames = Object.keys(store).sort();

        for (let i = 0; i < themeNames.length; i++) {
            const name = themeNames[i];
            const snapshot = store[name] || {};
            const bar = snapshot.bar || {};
            const colors = snapshot.themeColors || {};
            const dark = colors.dark || {};
            const hypr = snapshot.hypr || {};

            previews[name] = {
                accent: bar.accent || "#7cc7f5",
                surface: bar.surface || dark.surface || "#11141b",
                pill: bar.pill || dark.pill || "#121722",
                text: bar.text || "#cdd6e6",
                border1: hypr.border1 || "#0292e3"
            };
        }

        themePreviews = previews;
        if (themeNames.indexOf(selectedTheme) < 0)
            selectedTheme = themeNames.length > 0 ? themeNames[0] : "";
    }

    function saveTheme(value) {
        const name = sanitizeThemeName(value);
        if (name.length === 0) {
            status = "Enter a theme name";
            statusColor = Theme.yellow;
            statusTimer.restart();
            return;
        }

        const store = readThemeStore();
        const existed = Object.prototype.hasOwnProperty.call(store, name);
        store[name] = captureThemeSnapshot();
        persistThemeStore(store);
        reloadThemes();
        selectedTheme = name;
        newThemeName = name;
        status = (existed ? "Updated theme: " : "Saved theme: ") + name;
        statusColor = Theme.green;
        statusTimer.restart();
    }

    function loadTheme(value) {
        const name = sanitizeThemeName(value);
        const store = readThemeStore();
        const snapshot = store[name];

        if (!snapshot || typeof snapshot !== "object") {
            status = "Saved theme not found";
            statusColor = Theme.yellow;
            statusTimer.restart();
            return;
        }

        const merged = Object.assign({}, buildSettings(),
            JSON.parse(JSON.stringify(snapshot)));
        applySettings(merged);
        updateAutostartTheme(themeMode);
        applyGtkTheme(themeMode);
        applyCursor();
        saveSettings();
        status = "Loading theme: " + name;
        statusColor = Theme.subtext;
        statusTimer.restart();
        applyAll();
    }

    function deleteTheme(value) {
        const name = sanitizeThemeName(value);
        const store = readThemeStore();
        if (!Object.prototype.hasOwnProperty.call(store, name)) {
            status = "Saved theme not found";
            statusColor = Theme.yellow;
            statusTimer.restart();
            return;
        }

        delete store[name];
        persistThemeStore(store);
        reloadThemes();
        status = "Deleted theme: " + name;
        statusColor = Theme.green;
        statusTimer.restart();
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
    function reloadFile(file) {
        file.reload();
        // reload() can be asynchronous. Block until it finishes so the text()
        // calls below always see the file as it exists on disk right now.
        file.waitForJob();
    }

    function loadAll() {
        // FileView caches text between reads; refresh from disk before parsing
        // so externally edited files (or a previous Apply) are never stale.
        reloadFile(settingsFile);
        reloadThemes();
        reloadFile(autostartFile);
        reloadFile(envFile);
        reloadFile(inputFile);
        reloadFile(programsFile);
        reloadFile(monitorsFile);
        reloadFile(keybindingsFile);
        reloadFile(rulesFile);
        reloadFile(alacrittyFile);

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
        alacrittyText = alacrittyFile.text() || "";
        parseInput();
        parsePrograms();
        detectMonitors();
        parseKeybindings();
        parseRules();

        scanWallpapers();
        scanCursors();
        status = statusIdle;
        statusColor = Theme.dim;
    }

    function scanWallpapers() {
        wallpaperScan.running = true;
    }

    function scanCursors() {
        cursorScan.running = true;
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
        while ((m = re.exec(t)) !== null) {
            const key = m[1].replace(/\\"/g, "\"").replace(/\\\\/g, "\\");
            if (root.isCursorEnvKey(key))
                continue;
            list.push({
                key: key,
                value: m[2].replace(/\\"/g, "\"").replace(/\\\\/g, "\\")
            });
        }
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

    // Downscale the current wallpaper to one pixel and print its RGB bytes.
    // The path is base64-encoded so spaces and quotes cannot break the shell.
    readonly property string wallpaperColorScript: [
        "path=$(printf %s \"$1\" | base64 -d)",
        "[ -f \"$path\" ] || exit 1",
        "if command -v ffmpeg >/dev/null 2>&1; then",
        "  ffmpeg -v error -i \"$path\" -vf 'scale=1:1:flags=area' -frames:v 1 -f rawvideo -pix_fmt rgb24 pipe:1 | od -An -v -tu1",
        "elif command -v python3 >/dev/null 2>&1; then",
        "  python3 -c 'import sys; from PIL import Image; im = Image.open(sys.argv[1]).convert(\"RGB\").resize((1, 1)); p = im.getpixel((0, 0)); print(p[0], p[1], p[2])' \"$path\"",
        "else",
        "  exit 1",
        "fi"
    ].join("\n")

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
        // hypridle is managed by the idle setting, not by the raw list: filter
        // any older copy out so toggling never leaves duplicate launches.
        const commands = autostart.filter(c => String(c).indexOf("hypridle") < 0);
        if (idleEnabled)
            commands.push("command -v hypridle >/dev/null 2>&1 && hypridle -c \"$HOME/.config/hypr/hypridle.conf\"");
        const lines = commands.map(c => "    hl.exec_cmd(\"" + escLua(c) + "\")").join("\n");
        return "--------------------------------------------------------------------------------\n"
            + "-- AUTOSTART & SYSTEM INITIALIZATION\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + "hl.on(\"hyprland.start\", function ()\n"
            + lines + "\n"
            + "end)\n";
    }

    // Idle behaviour lives in ~/.config/hypr/hypridle.conf. DPMS and suspend
    // keep their existing 330s/900s schedule as a safe follow-up to locking.
    function generateHypridle() {
        const head = "general {\n"
            + "    lock_cmd = ~/.config/quickshell/lockscreen/lock.sh   # Quickshell lockscreen with crash watchdog\n"
            + "    before_sleep_cmd = loginctl lock-session    # lock before suspend\n"
            + "    after_sleep_cmd = hyprctl dispatch dpms on  # avoid having to press a key twice to turn on display\n"
            + "}\n\n";
        if (!idleEnabled)
            return head + "# Idle actions are disabled in Settings > Monitors.\n";

        let out = head;
        if (idleDimEnabled) {
            out += "# Dim screen after " + idleDimTimeout + "s\n"
                + "listener {\n"
                + "    timeout = " + idleDimTimeout + "\n"
                + "    on-timeout = brightnessctl -s set " + idleDimLevel + "\n"
                + "    on-resume = brightnessctl -r\n"
                + "}\n\n";
        }
        if (idleLockEnabled) {
            out += "# Lock screen after " + idleLockTimeout + "s\n"
                + "listener {\n"
                + "    timeout = " + idleLockTimeout + "\n"
                + "    on-timeout = loginctl lock-session\n"
                + "}\n\n";
        }
        out += "# Turn off screen after 5.5 minutes (330s)\n"
            + "listener {\n"
            + "    timeout = 330\n"
            + "    on-timeout = hyprctl dispatch dpms off\n"
            + "    on-resume = hyprctl dispatch dpms on\n"
            + "}\n\n"
            + "# Suspend laptop after 15 minutes (900s)\n"
            + "listener {\n"
            + "    timeout = 900\n"
            + "    on-timeout = systemctl suspend\n"
            + "}\n";
        return out;
    }

    function generateEnv() {
        const managed = [
            { key: "XCURSOR_THEME", value: cursorTheme },
            { key: "HYPRCURSOR_THEME", value: cursorTheme },
            { key: "XCURSOR_SIZE", value: String(cursorSize) },
            { key: "HYPRCURSOR_SIZE", value: String(cursorSize) }
        ];
        const lines = envVars
            .filter(e => !root.isCursorEnvKey(e.key))
            .concat(managed)
            .map(e => "hl.env(\"" + escLua(e.key) + "\", \"" + escLua(e.value) + "\")")
            .join("\n");
        return "--------------------------------------------------------------------------------\n"
            + "-- ENVIRONMENT VARIABLES\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + lines + "\n";
    }


    // The wrap is a fixed 7px display border; Outer gaps only set the space
    // between that border and the window area. The bar edge uses the gap
    // directly, while the frame edges add the fixed frame thickness. With a
    // single-display filter the gaps stay uniform because the other screens
    // have no bar or frame to align with.
    function managedGapsOut() {
        if (barLayout !== "unifiedWrap"
                || (barDisplay !== "all" && barDisplay !== ""))
            return String(hyprGapsOut);

        const wrapThickness = 7;
        const sides = {
            top: wrapThickness + hyprGapsOut,
            right: wrapThickness + hyprGapsOut,
            bottom: wrapThickness + hyprGapsOut,
            left: wrapThickness + hyprGapsOut
        };
        if (sides[barEdge] !== undefined)
            sides[barEdge] = hyprGapsOut;
        return "{ top = " + sides.top + ", right = " + sides.right
            + ", bottom = " + sides.bottom + ", left = " + sides.left + " }";
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
            + "        gaps_out = " + managedGapsOut() + ",\n"
            + "        border_size = " + hyprBorderSize + ",\n"
            + "        col = {\n"
            + "            active_border = " + active + ",\n"
            + "            inactive_border = \"" + colorToLua(hyprInactive) + "\",\n"
            + "        },\n"
            + "    },\n"
            + "    decoration = {\n"
            + "        rounding = " + hyprRounding + ",\n"
            + "        blur = {\n"
            + "            enabled = " + luaBool(hyprBlur) + ",\n"
            + "            size = " + hyprBlurSize + ",\n"
            + "        },\n"
            + "    },\n"
            + "})\n";
    }

    // The whole animation tree is generated here so the speed slider scales
    // every leaf. Base speeds are the tuned values of the original tree
    // (authored around global speed 10); relative feel is preserved.
    function generateAnimations() {
        const spd = base => (Math.round(base * animSpeed / 10 * 100) / 100).toString();
        const openStyle = "style = \"" + escLua(animWindowOpen) + "\"";
        const closeStyle = "style = \"" + escLua(animWindowClose) + "\"";
        const wsStyle = "style = \"" + escLua(animWorkspace) + "\"";
        const layerStyle = "style = \"" + escLua(animLayer) + "\"";
        const openCurve = animCurveExpr(animOpenCurve);
        const closeCurve = animCurveExpr(animCloseCurve);
        const leaves = [
            ["global",        10,    "bezier = \"default\"", ""],
            ["border",        5.39,  "bezier = \"easeOutQuint\"", ""],
            ["windows",       4.79,  "spring = \"easy\"", ""],
            ["windowsIn",     4.1,   openCurve, openStyle],
            ["windowsOut",    1.49,  closeCurve, closeStyle],
            ["fadeIn",        1.73,  "bezier = \"almostLinear\"", ""],
            ["fadeOut",       1.46,  "bezier = \"almostLinear\"", ""],
            ["fade",          3.03,  "bezier = \"quick\"", ""],
            ["layers",        3.81,  "bezier = \"easeOutQuint\"", ""],
            ["layersIn",      4,     "bezier = \"easeOutQuint\"", layerStyle],
            ["layersOut",     1.5,   "bezier = \"linear\"", layerStyle],
            ["fadeLayersIn",  1.79,  "bezier = \"almostLinear\"", ""],
            ["fadeLayersOut", 1.39,  "bezier = \"almostLinear\"", ""],
            ["workspaces",    6,     "bezier = \"easeOutQuint\"", wsStyle],
            ["workspacesIn",  6,     "bezier = \"easeOutQuint\"", wsStyle],
            ["workspacesOut", 6,     "bezier = \"easeOutQuint\"", wsStyle],
            ["zoomFactor",    7,     "bezier = \"quick\"", ""]
        ];

        let out = "--------------------------------------------------------------------------------\n"
            + "-- ANIMATIONS\n"
            + "-- Managed by Quickshell Settings - regenerated when you press Apply.\n"
            + "-- Styles and speed: Settings -> Appearance -> Animations.\n"
            + "--------------------------------------------------------------------------------\n\n"
            + "-- Curves used by the animation leaves below\n"
            + "hl.curve(\"easeOutQuint\",   { type = \"bezier\", points = { {0.23, 1}, {0.32, 1} } })\n"
            + "hl.curve(\"easeInOutCubic\", { type = \"bezier\", points = { {0.65, 0.05}, {0.36, 1} } })\n"
            + "hl.curve(\"linear\",         { type = \"bezier\", points = { {0, 0}, {1, 1} } })\n"
            + "hl.curve(\"almostLinear\",   { type = \"bezier\", points = { {0.5, 0.5}, {0.75, 1} } })\n"
            + "hl.curve(\"quick\",          { type = \"bezier\", points = { {0.15, 0}, {0.1, 1} } })\n"
            + "hl.curve(\"easy\",           { type = \"spring\", mass = 1, stiffness = 238.1191, damping = 24.21279333 })\n\n";

        for (let i = 0; i < leaves.length; i++) {
            const leaf = leaves[i];
            out += "hl.animation({ leaf = \"" + leaf[0] + "\", enabled = true, speed = " + spd(leaf[1])
                + (leaf[2] ? ", " + leaf[2] : "")
                + (leaf[3] ? ", " + leaf[3] : "")
                + " })\n";
        }
        return out;
    }

    // Alacritty has no blur of its own: transparency lets Hyprland's blur
    // show through. Strength 0 keeps the terminal opaque; 100 is the most
    // transparent (and therefore the most visibly blurred) setting.
    function alacrittyOpacity() {
        const strength = Math.max(0, Math.min(100, alacrittyBlurStrength));
        return alacrittyBlur ? (1 - strength / 200) : 1;
    }

    function generateAlacritty() {
        let text = String(alacrittyText || "");
        if (text.trim().length === 0)
            text = "[font]\n"
                + "normal = { family = \"JetBrainsMono Nerd Font\", style = \"Regular\" }\n"
                + "bold = { family = \"JetBrainsMono Nerd Font\", style = \"Bold\" }\n"
                + "italic = { family = \"JetBrainsMono Nerd Font\", style = \"Italic\" }\n"
                + "size = 11.0\n"
                + "[window]\n";

        const opacity = alacrittyOpacity().toFixed(2);
        const re = /^([ \t]*opacity[ \t]*=[ \t]*)([^\n]*)$/m;
        if (re.test(text)) {
            text = text.replace(re, "$1" + opacity);
        } else if (/^[ \t]*\[window\][ \t]*$/m.test(text)) {
            text = text.replace(/^([ \t]*\[window\][ \t]*)$/m, "$1\nopacity = " + opacity);
        } else {
            text = text.replace(/\s*$/, "\n\n[window]\nopacity = " + opacity + "\n");
        }
        return text;
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
        applyCursor();
        saveDebounce.stop();
        saveSettings();
        updateAutostartTheme("dark");
        applyGtkTheme("dark");
        status = "Defaults restored — press Apply for Hyprland";
        statusColor = Theme.yellow;
        statusTimer.restart();
    }

    function applyAll() {
        if (applying)
            return;
        saveDebounce.stop();

        // Apply can also be called over IPC without opening the UI first. In
        // that case nothing has populated the parsed file state yet, so reload
        // from disk before writing any managed files back out.
        if (!shown)
            loadAll();

        // Clicking Apply does not necessarily pull focus out of a TextField
        // (SettingsButton is a plain MouseArea), so flush any pending edit.
        if (window.activeFocusItem && window.activeFocusItem !== window)
            window.activeFocusItem.focus = false;

        const files = [
            [settingsPath, JSON.stringify(buildSettings(), null, 2) + "\n"],
            [hyprDir + "/autostart.lua", generateAutostart()],
            [hyprDir + "/env.lua", generateEnv()],
            [hyprDir + "/ui_overrides.lua", generateManaged()],
            [hyprDir + "/animations.lua", generateAnimations()],
            [hyprDir + "/input.lua", generateInput()],
            [hyprDir + "/programs.lua", generatePrograms()],
            [hyprDir + "/monitors.lua", generateMonitors()],
            [hyprDir + "/keybindings.lua", generateKeybindings()],
            [home + "/.config/hypr/hypridle.conf", generateHypridle()],
            [home + "/.config/alacritty/alacritty.toml", generateAlacritty()]
        ];

        let script = "mkdir -p '" + home + "/.config/alacritty' '" + home + "/.config/hypr'\n";
        for (let i = 0; i < files.length; i++) {
            const encoded = b64Utf8(files[i][1]);
            script += "printf '%s' '" + encoded + "' | base64 -d > '" + files[i][0] + "'\n";
        }
        script += "hyprctl reload >/dev/null 2>&1\n";
        // Cursor env vars only reach a fresh session, so set the live cursor
        // after the reload as well. Base64 keeps odd theme names shell-safe.
        const cursorThemeB64 = b64Utf8(cursorTheme);
        script += "cursor_theme=$(printf '%s' '" + cursorThemeB64 + "' | base64 -d)\n";
        script += "hyprctl setcursor \"$cursor_theme\" " + cursorSize + " >/dev/null 2>&1\n";
        script += "command -v gsettings >/dev/null 2>&1 && "
            + "gsettings set org.gnome.desktop.interface cursor-theme \"$cursor_theme\" >/dev/null 2>&1\n";
        script += "command -v gsettings >/dev/null 2>&1 && "
            + "gsettings set org.gnome.desktop.interface cursor-size " + cursorSize + " >/dev/null 2>&1\n";
        // autostart only runs at Hyprland start, so restart hypridle here to
        // make a freshly applied idle config take effect immediately.
        script += "if command -v hypridle >/dev/null 2>&1; then\n";
        script += "  pkill -x hypridle 2>/dev/null || true\n";
        if (idleEnabled)
            script += "  nohup hypridle -c '" + home
                + "/.config/hypr/hypridle.conf' >/dev/null 2>&1 &\n";
        script += "fi\n";

        pendingApplyScript = script;
        applying = true;
        status = "Applying…";
        statusColor = Theme.subtext;
        applyProc.running = true;
    }

    // ---------------------------------------------------------------------
    // Window plumbing
    // ---------------------------------------------------------------------
    function open() {
        if (shown && !closing)
            return;
        hideTimer.stop();
        loadAll();
        applyGtkTheme(themeMode);
        root.clearSearch();
        revealTimer.stop();

        // A warm daemon must still feel like a fresh panel: always return to
        // the first page with the first appearance section selected.
        navHighlightAnimate = false;
        navHighlightVisible = false;
        navSwapping = false;
        navSwapTimer.stop();
        page = 0;
        renderedPage = 0;
        pageSwapSnap = true;
        previousPageLoader.opacity = 0;
        previousPageLoader.sourceComponent = null;
        pageSwapSnap = false;
        pageFadeTimer.stop();
        pageLoader.opacity = 1;
        appearanceSection = "panel";
        confirmReset = false;
        scroller.contentItem.contentY = 0;
        Qt.callLater(root.syncNavHighlight);

        closing = false;
        shown = true;
        reveal = 1;
    }

    // Keep the daemon warm so the next open is instant. open() always calls
    // loadAll(), which reloads every managed file from disk first, so a hidden
    // process can never show stale settings.
    function close() {
        if (closing)
            return;
        if (applying) {
            pendingCloseAfterApply = true;
            status = "Finishing Apply…";
            statusColor = Theme.subtext;
            return;
        }
        closing = true;
        reveal = 0;
        hideTimer.restart();
    }

    Timer {
        id: hideTimer
        interval: Theme.motionFast + 20
        onTriggered: {
            shown = false;
            closing = false;
        }
    }

    Timer {
        id: pageFadeTimer
        interval: Theme.motionFast
        onTriggered: {
            previousPageLoader.opacity = 0;
            previousPageLoader.sourceComponent = null;
        }
    }

    Timer {
        id: navSwapTimer
        interval: Theme.motionBase
        onTriggered: root.navSwapping = false
    }

    Timer {
        id: resetConfirmTimer
        interval: 3200
        onTriggered: {
            confirmReset = false;
            status = statusIdle;
            statusColor = Theme.dim;
        }
    }

    Timer {
        id: revealTimer
        interval: Theme.motionBase + 40
        onTriggered: {
            const target = root.findSettingItem(pageLoader.item, root.pendingSearchLabel);
            if (target && scroller) {
                const pos = target.mapToItem(scroller.contentItem, 0, 0);
                const maxY = Math.max(0,
                    scroller.contentItem.contentHeight - scroller.height);
                scroller.contentItem.contentY = Math.max(0,
                    Math.min(maxY, pos.y - 72));
            }
            root.pendingSearchLabel = "";
        }
    }

    function toggle() {
        if (shown && !closing)
            close();
        else
            open();
    }

    function clearSearch() {
        searchQuery = "";
        pendingSearchLabel = "";
    }

    function focusSearch() {
        if (!searchField || !searchField.input)
            return;
        searchField.input.forceActiveFocus();
        searchField.input.selectAll();
    }

    function setPage(index) {
        if (root.searchActive)
            root.clearSearch();
        const next = Math.max(0, Math.min(pages.length - 1, index));
        if (next === page)
            return;
        page = next;
        confirmReset = false;
    }

    function setAppearanceSection(value) {
        if (root.searchActive)
            root.clearSearch();
        if (value === appearanceSection)
            return;
        appearanceSection = value;
        confirmReset = false;
        scroller.contentItem.contentY = 0;
    }

    function findSettingItem(item, label) {
        if (!item || !item.children)
            return null;
        for (let i = 0; i < item.children.length; i++) {
            const child = item.children[i];
            let childLabel = "";
            try {
                if (typeof child.label === "string")
                    childLabel = child.label;
                else if (typeof child.text === "string")
                    childLabel = child.text;
            } catch (e) {
                childLabel = "";
            }
            if (childLabel === label && child.visible)
                return child;
            const nested = root.findSettingItem(child, label);
            if (nested)
                return nested;
        }
        return null;
    }

    function revealSearchResult(entry) {
        if (!entry)
            return;
        root.clearSearch();
        root.setPage(entry.pageIndex);
        if (entry.pageIndex === 0 && entry.section)
            root.setAppearanceSection(entry.section);
        pendingSearchLabel = entry.label;
        scroller.contentItem.contentY = 0;
        revealTimer.restart();
    }

    function componentForPage(index) {
        switch (index) {
            case 0: return barPage;
            case 1: return windowsPage;
            case 2: return effectsPage;
            case 3: return inputPage;
            case 4: return keybindingsPage;
            case 5: return monitorsPage;
            case 6: return sessionPage;
            case 7: return notificationsPage;
            case 8: return autostartPage;
            case 9: return programsPage;
            case 10: return environmentPage;
            case 11: return rulesPage;
        }
        return barPage;
    }

    function handleReset() {
        if (!confirmReset) {
            confirmReset = true;
            status = "Click Reset again to restore defaults";
            statusColor = Theme.yellow;
            resetConfirmTimer.restart();
            return;
        }
        confirmReset = false;
        resetConfirmTimer.stop();
        resetAll();
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
            root.open();
            root.setPage(index);
        }
        // Alias for existing scripts: this selects a top-level page by index.
        function hsection(index: int): void {
            root.open();
            root.setPage(index);
        }
    }

    Timer {
        id: saveDebounce
        interval: 180
        onTriggered: root.saveSettings()
    }

    Timer {
        id: gtkAccentDebounce
        interval: 180
        onTriggered: {
            root.applyGtkTheme(themeMode);
            root.updateAutostartTheme(themeMode);
        }
    }

    Timer {
        id: managedDebounce
        interval: 250
        onTriggered: root.applyManaged()
    }

    Timer {
        id: statusTimer
        interval: 2600
        onTriggered: {
            root.status = statusIdle;
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
        id: themesFile
        path: root.themesPath
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: themesWriter
        path: root.themesPath
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

    FileView {
        id: alacrittyFile
        path: root.home + "/.config/alacritty/alacritty.toml"
        preload: true
        blockLoading: true
        printErrors: false
    }

    Process {
        id: applyProc
        running: false
        command: ["sh", "-c", root.pendingApplyScript]

        onExited: function (exitCode) {
            root.applying = false;
            if (exitCode === 0) {
                root.status = "Applied — Hyprland reloaded";
                root.statusColor = Theme.green;
            } else {
                root.status = "Apply failed (" + exitCode + ")";
                root.statusColor = Theme.red;
            }
            root.statusTimer.restart();

            if (root.pendingCloseAfterApply) {
                root.pendingCloseAfterApply = false;
                root.close();
            }
        }
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
        id: cursorScan
        running: false

        command: ["sh", "-c",
            "find \"$HOME/.icons\" \"$HOME/.local/share/icons\" \"$HOME/.local/share/hyprcursor\" "
            + "/usr/local/share/icons /usr/local/share/hyprcursor /usr/share/icons /usr/share/hyprcursor "
            + "-mindepth 1 -maxdepth 3 -type d \\( -name cursors -o -name hyprcursor \\) "
            + "-printf '%h\\n' 2>/dev/null | sed 's#.*/##' | sort -u; "
            + "[ -f /usr/share/icons/default/index.theme ] && echo default"]

        stdout: StdioCollector {
            onStreamFinished: {
                const themes = text.split("\n")
                    .map(function(value) { return value.trim(); })
                    .filter(function(value) { return value.length > 0; });
                if (themes.indexOf("default") < 0)
                    themes.unshift("default");
                if (root.cursorTheme && themes.indexOf(root.cursorTheme) < 0)
                    themes.push(root.cursorTheme);
                root.cursorThemes = themes;
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

    Process {
        id: wallpaperColorProcess
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                const match = String(text).match(/(\d{1,3})\s+(\d{1,3})\s+(\d{1,3})/);
                if (!match) {
                    root.status = "Could not sample wallpaper";
                    root.statusColor = Theme.red;
                    root.statusTimer.restart();
                    return;
                }
                root.applyWallpaperAverage(Number(match[1]), Number(match[2]), Number(match[3]));
            }
        }
    }

    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.shown && root.captureOwner === null
        onActivated: root.focusSearch()
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.shown && root.captureOwner === null
        onActivated: {
            if (root.searchActive) {
                root.clearSearch();
                return;
            }
            root.close();
        }
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
        WlrLayershell.namespace: "quickshell-settings-surface"

        Loader {
            anchors.fill: card
            z: 1000
            source: "SoftwareDimOverlay.qml"
            onLoaded: item.radius = Qt.binding(function() { return card.radius; })
        }
        WlrLayershell.keyboardFocus: root.shown
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card

            readonly property real fitScale: Math.max(0.1, Math.min(1,
                (parent.width - 80) / root.settingsBaseWidth,
                (parent.height - 60) / root.settingsBaseHeight))

            width: root.settingsBaseWidth
            height: root.settingsBaseHeight
            anchors.centerIn: parent
            radius: Theme.panelRadius
            color: Theme.panelFill(Theme.surface, "settings")
            border.width: 1
            border.color: Theme.border

            opacity: root.reveal
            scale: fitScale * (Theme.motionEnterScale + (1 - Theme.motionEnterScale) * root.reveal)
            transform: Translate {
                y: -(1 - root.reveal) * Theme.motionEnterOffset * card.fitScale
            }

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

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
                id: settingsLayout

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
                        Layout.maximumWidth: 330
                        spacing: 0

                        Text {
                            text: root.searchActive
                                ? "Settings / Search" : "Settings / " + root.currentPage.title
                            font.family: Theme.mono
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.searchActive
                                ? root.searchResults.length
                                    + (root.searchResults.length === 1
                                        ? " matching control" : " matching controls")
                                : root.currentPage.subtitle
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.dim
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: searchField

                        property alias input: searchInput

                        Layout.preferredWidth: 270
                        Layout.minimumWidth: 200
                        Layout.maximumWidth: 300
                        implicitHeight: 32
                        radius: Theme.controlRadius
                        color: Theme.bg
                        border.width: 1
                        border.color: searchInput.activeFocus ? Theme.accent : Theme.border

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.motionFast }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 6

                            Text {
                                text: "\uf002"
                                font.family: Theme.font
                                font.pixelSize: 13
                                color: Theme.dim
                            }

                            TextField {
                                id: searchInput

                                Layout.fillWidth: true
                                text: root.searchQuery
                                placeholderText: "Search settings  (Ctrl+F)"
                                placeholderTextColor: Theme.dim
                                color: Theme.text
                                font.family: Theme.mono
                                font.pixelSize: 11
                                selectByMouse: true
                                leftPadding: 0
                                rightPadding: 0
                                topPadding: 0
                                bottomPadding: 0
                                background: null
                                onTextEdited: root.searchQuery = text
                            }

                            Rectangle {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                radius: 8
                                visible: searchInput.text.length > 0
                                color: clearSearchMouse.containsMouse
                                    ? Theme.hover : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.family: Theme.mono
                                    font.pixelSize: 9
                                    color: Theme.dim
                                }

                                MouseArea {
                                    id: clearSearchMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = "";
                                        root.clearSearch();
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }

                    SettingsButton {
                        icon: "󰅙"
                        tooltip: "Close Settings"
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
                    id: bodyRow

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    ColumnLayout {
                        Layout.preferredWidth: 190
                        Layout.fillHeight: true
                        spacing: 4

                        Item {
                            id: navList

                            Layout.fillWidth: true
                            Layout.preferredHeight: navColumn.implicitHeight

                            Rectangle {
                                x: root.navHighlightRect.x
                                y: root.navHighlightRect.y
                                width: root.navHighlightRect.width
                                height: root.navHighlightRect.height
                                radius: Theme.controlRadius
                                color: Theme.active
                                visible: root.navHighlightVisible

                                Behavior on x {
                                    enabled: root.navHighlightAnimate
                                    NumberAnimation {
                                        duration: Theme.motionBase
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on y {
                                    enabled: root.navHighlightAnimate
                                    NumberAnimation {
                                        duration: Theme.motionBase
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on width {
                                    enabled: root.navHighlightAnimate
                                    NumberAnimation {
                                        duration: Theme.motionBase
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on height {
                                    enabled: root.navHighlightAnimate
                                    NumberAnimation {
                                        duration: Theme.motionBase
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Column {
                                id: navColumn

                                anchors.fill: parent
                                spacing: 3

                                Repeater {
                                    id: navRepeater
                                    model: root.pages

                                    NavItem {
                                        width: navColumn.width
                                        height: 36
                                        icon: modelData.icon
                                        label: modelData.title
                                        active: root.page === index
                                        swapping: root.navSwapping
                                        onClicked: root.setPage(index)
                                    }
                                }
                            }
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
                            text: "cyan1de\npowered by Quickshell + Hyprland"
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
                        Component.onCompleted: contentItem.boundsBehavior = Flickable.StopAtBounds
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        Item {
                            id: contentWrapper
                            width: scroller.availableWidth
                            height: implicitHeight
                            implicitHeight: pageLoader.implicitHeight + 32
                                + (root.page === 0 && !root.searchActive ? 50 : 0)

                            // Outgoing page stays mounted underneath while the
                            // incoming page fades in, so there is no empty frame.
                            Loader {
                                id: previousPageLoader
                                x: 16 + (1 - opacity) * 10
                                y: 16 + (root.previousWasBarPage ? 50 : 0)
                                width: parent.width - 32
                                opacity: 0
                                scale: 0.99 + 0.01 * opacity
                                transformOrigin: Item.TopLeft
                                enabled: false
                                z: 0

                                Behavior on opacity {
                                    enabled: !root.pageSwapSnap
                                    NumberAnimation {
                                        duration: Theme.motionFast
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Loader {
                                id: pageLoader
                                x: 16 + (1 - opacity) * 10
                                y: 16 + (root.page === 0 && !root.searchActive ? 50 : 0)
                                width: parent.width - 32
                                opacity: 1
                                scale: 0.99 + 0.01 * opacity
                                transformOrigin: Item.TopLeft
                                sourceComponent: root.searchActive
                                    ? searchResultsPage
                                    : root.componentForPage(root.renderedPage)
                                z: 1

                                Behavior on opacity {
                                    enabled: !root.pageSwapSnap
                                    NumberAnimation {
                                        duration: Theme.motionFast
                                        easing.type: Easing.OutCubic
                                    }
                                }
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
                        icon: "󰄲"
                        text: root.confirmReset ? "Confirm reset" : "Reset"
                        danger: true
                        tooltip: "Restore the shipped defaults (requires a second click)"
                        onClicked: root.handleReset()
                    }

                    SettingsButton {
                        icon: "󰄬"
                        text: "Apply"
                        primary: true
                        tooltip: "Write Hyprland settings and reload the compositor"
                        onClicked: root.applyAll()
                    }
                }
            }

            // Appearance section bar floats over page content only. It is
            // positioned from the scroll view so the section tabs stay clear.
            Rectangle {
                id: appearanceTabs

                x: settingsLayout.x + bodyRow.x + scroller.x
                y: settingsLayout.y + bodyRow.y + scroller.y
                width: scroller.width
                height: 40
                z: 5
                visible: root.page === 0 && !root.searchActive
                radius: Theme.panelRadius
                color: Theme.surfaceAlt
                border.width: 1
                border.color: Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 10

                    Text {
                        text: "SECTION"
                        font.family: Theme.mono
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                        color: Theme.dim
                    }

                    Segmented {
                        options: root.appearanceSections
                        value: root.appearanceSection
                        onSelected: value => root.setAppearanceSection(value)
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 240
                        horizontalAlignment: Text.AlignRight
                        text: String(root.appearanceSectionHints[root.appearanceSection] || "")
                        font.family: Theme.mono
                        font.pixelSize: 9
                        color: Theme.dim
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // The panel preview lifts its drag ghost into this full-screen layer
        // so it can follow the pointer outside the settings card.
        Item {
            id: dragOverlayLayer
            anchors.fill: parent
            enabled: false
            z: 100

            Component.onCompleted: root.dragOverlayHost = dragOverlayLayer
        }
    }

    Component {
        id: searchResultsPage

        ColumnLayout {
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: "MATCHING CONTROLS"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

            Text {
                Layout.fillWidth: true
                visible: root.searchResults.length === 0
                text: "No settings match “" + root.searchQuery + "”."
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.groupedSearchResults

                SectionCard {
                    Layout.fillWidth: true
                    title: String(modelData.pageTitle).toUpperCase()
                    subtitle: (modelData.sectionTitle
                            ? modelData.sectionTitle + " · " : "")
                        + modelData.items.length
                        + (modelData.items.length === 1 ? " control" : " controls")

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: modelData.items

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: resultRow.implicitHeight + 12
                                radius: Theme.controlRadius
                                color: resultMouse.containsMouse
                                    ? Theme.hover : Theme.surface
                                border.width: 1
                                border.color: Theme.border

                                RowLayout {
                                    id: resultRow

                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8

                                    Text {
                                        text: "\uf002"
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        color: Theme.accent
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.family: Theme.mono
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            color: Theme.text
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: modelData.detail !== ""
                                            text: modelData.detail
                                            font.family: Theme.mono
                                            font.pixelSize: 9
                                            color: Theme.dim
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: modelData.sectionTitle || modelData.pageTitle
                                        font.family: Theme.mono
                                        font.pixelSize: 9
                                        color: Theme.dim
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: "→"
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        color: Theme.accent
                                    }
                                }

                                MouseArea {
                                    id: resultMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.revealSearchResult(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: barPage
        BarPage {
            app: root
            section: root.appearanceSection
        }
    }

    Component {
        id: windowsPage
        WindowsPage { app: root }
    }

    Component {
        id: effectsPage
        EffectsPage { app: root }
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
        id: sessionPage
        SessionPage { app: root }
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
