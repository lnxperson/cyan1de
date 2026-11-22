import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Replacement for fuzzel: a Quickshell application launcher.
// Runs as a daemon and is toggled over IPC by SUPER+SPACE.
ShellRoot {
    id: root

    property bool shown: false
    property real reveal: 0
    property bool closing: false
    property string query: ""
    property int selected: 0

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property bool webMode: root.query.trim().charAt(0) === "'"
    readonly property bool calcMode: !root.webMode && root.query.trim().charAt(0) === "="
    readonly property bool fileMode: !root.webMode && !root.calcMode && root.query.trim().charAt(0) === ":"
    readonly property string webTerm: root.webMode
        ? root.query.trim().slice(1).trim()
        : ""
    readonly property string calcExpr: root.calcMode
        ? root.query.trim().slice(1).trim()
        : ""
    readonly property string fileTerm: root.fileMode
        ? root.query.trim().slice(1).trim()
        : ""
    property var fileResults: []
    property bool searching: false

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    // Defaults mirror Settings -> Programs; refreshed from programs.lua on open.
    property string terminalCmd: "alacritty"
    property string fileManagerCmd: "nautilus"
    property string browserCmd: "firefox"
    property string textEditorCmd: "gnome-text-editor"
    property string imageViewerCmd: "loupe"
    property string pdfViewerCmd: "papers"

    readonly property var results: {
        if (root.webMode) {
            if (root.webTerm === "")
                return [];
            return [{
                name: "Search the web for “" + root.webTerm + "”",
                genericName: "Open in " + (root.command("browser")[0] || "default browser"),
                icon: "󰖟",
                isWeb: true,
                term: root.webTerm
            }];
        }
        if (root.calcMode) {
            if (root.calcExpr === "")
                return [];
            const calc = root.calculate(root.calcExpr);
            return [{
                name: calc.text,
                genericName: calc.ok ? root.calcExpr + " = " + calc.text : calc.error,
                icon: "󰓎",
                isCalc: true,
                result: calc.ok ? calc.text : ""
            }];
        }

        if (root.fileMode)
            return root.fileResults;

        const source = DesktopEntries.applications.values;
        const q = root.query.trim().toLowerCase();
        const matches = [];

        for (let i = 0; i < source.length; i++) {
            const entry = source[i];
            if (!entry || entry.noDisplay)
                continue;

            if (q === "") {
                matches.push(entry);
                continue;
            }

            const name = (entry.name || "").toLowerCase();
            const generic = (entry.genericName || "").toLowerCase();
            const comment = (entry.comment || "").toLowerCase();

            if (name.includes(q) || generic.includes(q) || comment.includes(q))
                matches.push(entry);
        }

        function score(entry) {
            if (q === "")
                return 0;
            const name = (entry.name || "").toLowerCase();
            if (name.startsWith(q))
                return 0;
            if (name.includes(q))
                return 1;
            return 2;
        }

        matches.sort(function (a, b) {
            return score(a) - score(b) || a.name.localeCompare(b.name);
        });

        return matches;
    }

    function open() {
        if (root.shown && !root.closing) {
            focusTimer.restart();
            return;
        }

        exitTimer.stop();
        if (!root.shown) {
            field.text = "";
            root.query = "";
            root.selected = 0;
        }
        root.closing = false;
        root.shown = true;
        root.reveal = 1;
        programsProbe.running = false;
        programsProbe.running = true;
        focusTimer.restart();
    }

    function close() {
        if (!root.shown || root.closing)
            return;
        root.closing = true;
        root.reveal = 0;
        focusTimer.stop();
        exitTimer.restart();
    }

    Timer {
        id: exitTimer
        interval: Theme.motionFast + 20
        onTriggered: {
            shown = false;
            closing = false;
            fileSearchDebounce.stop();
            searching = false;
            field.text = "";
            query = "";
            selected = 0;
        }
    }

    function toggle() {
        if (root.shown && !root.closing)
            root.close();
        else
            root.open();
    }

    function move(delta) {
        if (root.results.length === 0)
            return;

        root.selected = Math.max(0, Math.min(root.results.length - 1, root.selected + delta));
        list.positionViewAtIndex(root.selected, ListView.Contain);
    }

    function expandHome(path) {
        const s = String(path || "");
        return s.indexOf("~/") === 0 ? root.home + s.slice(1) : s;
    }

    function splitCommand(raw) {
        const src = String(raw || "").trim();
        const parts = [];
        let cur = "";
        let quote = "";

        for (let i = 0; i < src.length; i++) {
            const c = src.charAt(i);
            if (quote.length > 0) {
                if (c === quote) quote = "";
                else cur += c;
            } else if (c === '"' || c === "'") {
                quote = c;
            } else if (c === " " || c === "\t") {
                if (cur.length > 0) {
                    parts.push(root.expandHome(cur));
                    cur = "";
                }
            } else {
                cur += c;
            }
        }
        if (cur.length > 0) parts.push(root.expandHome(cur));
        return parts;
    }

    // Small recursive-descent calculator. Supports + - * /, ^, parentheses,
    // sqrt() and mod() without handing user input to a shell or eval().
    function formatCalcNumber(value) {
        if (!isFinite(value))
            return value > 0 ? "∞" : "-∞";
        if (value % 1 === 0)
            return String(value);
        return String(Number(value.toPrecision(12)));
    }

    function calculate(expression) {
        const src = String(expression || "").trim();
        if (src === "")
            return { ok: false, text: "Empty expression", error: "Type an expression" };

        let pos = 0;

        function skip() {
            while (pos < src.length && /\s/.test(src.charAt(pos)))
                pos++;
        }

        function consume(text) {
            skip();
            if (src.substr(pos, text.length) === text) {
                pos += text.length;
                return true;
            }
            return false;
        }

        function expect(text) {
            if (!consume(text))
                throw new Error("Expected “" + text + "”");
        }

        function parseExpression() {
            let value = parseTerm();
            while (true) {
                skip();
                const c = src.charAt(pos);
                if (c === "+") {
                    pos++;
                    value += parseTerm();
                } else if (c === "-") {
                    pos++;
                    value -= parseTerm();
                } else {
                    break;
                }
            }
            return value;
        }

        function parseTerm() {
            let value = parseUnary();
            while (true) {
                skip();
                const c = src.charAt(pos);

                if (c === "*" || c === "/") {
                    pos++;
                    const rhs = parseUnary();
                    if (c === "/" && rhs === 0)
                        throw new Error("Division by zero");
                    value = c === "*" ? value * rhs : value / rhs;
                } else if (src.substr(pos, 3).toLowerCase() === "mod") {
                    pos += 3;
                    const rhs = parseUnary();
                    if (rhs === 0)
                        throw new Error("Modulo by zero");
                    value %= rhs;
                } else {
                    break;
                }
            }
            return value;
        }

        function parseUnary() {
            skip();
            if (src.charAt(pos) === "-") {
                pos++;
                return -parseUnary();
            }
            if (src.charAt(pos) === "+") {
                pos++;
                return parseUnary();
            }
            return parsePower();
        }

        function parsePower() {
            const base = parsePrimary();
            skip();
            if (src.charAt(pos) === "^") {
                pos++;
                return Math.pow(base, parseUnary());
            }
            return base;
        }

        function parsePrimary() {
            skip();
            const c = src.charAt(pos);

            if (c === "(") {
                pos++;
                const value = parseExpression();
                expect(")");
                return value;
            }

            if (/[0-9.]/.test(c))
                return parseNumber();

            const rest = src.slice(pos).toLowerCase();
            const names = ["sqrt", "mod"];
            for (let i = 0; i < names.length; i++) {
                const name = names[i];
                if (rest.indexOf(name) !== 0)
                    continue;

                pos += name.length;
                expect("(");
                const a = parseExpression();
                let value;

                if (name === "sqrt") {
                    if (a < 0)
                        throw new Error("Square root of a negative number");
                    value = Math.sqrt(a);
                } else {
                    expect(",");
                    const b = parseExpression();
                    if (b === 0)
                        throw new Error("Modulo by zero");
                    value = a % b;
                }

                expect(")");
                return value;
            }

            throw new Error(c === "" ? "Incomplete expression" : "Unexpected “" + c + "”");
        }

        function parseNumber() {
            const m = src.slice(pos).match(/^(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?/);
            if (!m)
                throw new Error("Expected a number");
            pos += m[0].length;
            return parseFloat(m[0]);
        }

        try {
            const value = parseExpression();
            skip();
            if (pos !== src.length)
                throw new Error("Unexpected “" + src.slice(pos) + "”");
            if (!isFinite(value))
                throw new Error("Result is not finite");
            return { ok: true, text: root.formatCalcNumber(value), error: "" };
        } catch (err) {
            return { ok: false, text: "Invalid expression", error: err.message || "Invalid expression" };
        }
    }

    function copyToClipboard(text) {
        const script = "printf '%s' \"$1\" | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || xsel --clipboard --input 2>/dev/null)";
        Quickshell.execDetached(["sh", "-c", script, "launcher-copy", String(text || "")]);
    }

    function command(name) {
        return root.splitCommand(root[name + "Cmd"] || "");
    }

    function luaField(text, key) {
        const re = new RegExp("^[ \\t]*" + key.replace(/\./g, "\\.") + "[ \\t]*=[ \\t]*(.+?)[ \\t]*$", "m");
        const m = String(text || "").match(re);
        return m ? m[1].trim() : "";
    }

    function luaValue(raw, fallback) {
        const s = String(raw || "").trim();
        let m = s.match(/^"(.*)"$/);
        if (m) return m[1].replace(/\\"/g, '"');
        m = s.match(/^'(.*)'$/);
        if (m) return m[1];
        m = s.match(/os\.getenv\("HOME"\)\s*\.\.\s*"(.*)"$/);
        if (m) return root.home + m[1];
        return s.length > 0 ? s : fallback;
    }

    function parsePrograms(text) {
        const t = String(text || "");
        root.terminalCmd = root.luaValue(root.luaField(t, "M.terminal"), "alacritty");
        root.fileManagerCmd = root.luaValue(root.luaField(t, "M.fileManager"), "nautilus");
        root.browserCmd = root.luaValue(root.luaField(t, "M.browser"), "firefox");
        root.textEditorCmd = root.luaValue(root.luaField(t, "M.textEditor"), "gnome-text-editor");
        root.imageViewerCmd = root.luaValue(root.luaField(t, "M.imageViewer"), "loupe");
        root.pdfViewerCmd = root.luaValue(root.luaField(t, "M.pdfViewer"), "papers");
    }

    function launchFile(entry) {
        const path = entry.path;
        const kind = entry.kind || "file";
        let cmd = [];

        if (kind === "dir") {
            cmd = root.command("fileManager");
        } else if (kind === "exec") {
            const term = root.command("terminal");
            if (term.length > 0) {
                Quickshell.execDetached(term.concat(["-e", path]));
                return;
            }
        } else {
            const bits = path.split(".");
            const ext = bits.length > 1 ? bits[bits.length - 1].toLowerCase() : "";
            const images = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "ico",
                            "tif", "tiff", "heic", "avif", "ppm", "pgm"];
            const texts = ["txt", "md", "rst", "log", "conf", "config", "cfg", "ini",
                           "json", "jsonc", "yaml", "yml", "toml", "xml", "csv", "tsv",
                           "env", "sh", "bash", "zsh", "fish", "py", "js", "jsx", "ts",
                           "tsx", "qml", "lua", "c", "h", "cpp", "hpp", "cc", "rs", "go",
                           "java", "kt", "rb", "pl", "php", "html", "htm", "css", "scss",
                           "sql", "desktop", "service", "socket", "timer", "rules",
                           "properties", "nix", "vim", "tex", "diff", "patch", "lock"];

            if (images.indexOf(ext) >= 0)
                cmd = root.command("imageViewer");
            else if (ext === "pdf")
                cmd = root.command("pdfViewer");
            else if (texts.indexOf(ext) >= 0)
                cmd = root.command("textEditor");
        }

        if (cmd.length > 0)
            Quickshell.execDetached(cmd.concat([path]));
        else
            Quickshell.execDetached(["xdg-open", path]);
    }

    function openWebSearch(term) {
        const browser = root.command("browser");
        const url = "https://www.google.com/search?q=" + encodeURIComponent(term);

        if (browser.length > 0) {
            const exe = browser[0].split("/").pop().toLowerCase();
            if (exe.indexOf("firefox") >= 0)
                Quickshell.execDetached(browser.concat(["--search", term]));
            else
                Quickshell.execDetached(browser.concat([url]));
        } else {
            Quickshell.execDetached(["xdg-open", url]);
        }
    }

    function launchCurrent() {
        const entry = root.results[root.selected];
        if (!entry)
            return;

        root.close();

        if (entry.isWeb) {
            root.openWebSearch(entry.term);
            return;
        }

        if (entry.isCalc) {
            if (entry.result !== "")
                root.copyToClipboard(entry.result);
            return;
        }

        if (entry.isFile) {
            root.launchFile(entry);
            return;
        }

        const command = Array.from(entry.command);
        if (command.length === 0)
            return;

        if (entry.runInTerminal) {
            const term = root.command("terminal");
            const prefix = term.length > 0 ? term : ["alacritty"];
            Quickshell.execDetached(prefix.concat(["-e"], command));
        } else {
            Quickshell.execDetached(command);
        }
    }

    onResultsChanged: root.selected = 0

    function runFileSearch() {
        if (!root.fileMode || root.fileTerm === "") {
            root.fileResults = [];
            root.searching = false;
            return;
        }

        root.searching = true;
        fileSearchProcess.running = false;
        fileSearchProcess.running = true;
    }

    readonly property string fileSearchScript:
        "term=\"$1\"\n"
        + "[ -z \"$term\" ] && exit 0\n"
        + "{\n"
        + "  rg --files --hidden --no-messages -g '!.cache/**' -g '!.git/**' -g '!node_modules/**' -g '!.local/share/Trash/**' -g '!target/**' \"$HOME\" 2>/dev/null | grep -i -F -- \"$term\" | head -n 40\n"
        + "  rg -i -l -F --hidden --no-messages --max-depth 8 --max-filesize 1M -g '!.git/**' -g '!node_modules/**' -g '!target/**' -- \"$term\" \"$HOME/Documents\" \"$HOME/Desktop\" \"$HOME/Projects\" \"$HOME/cyan1de\" \"$HOME/.config\" \"$HOME/Downloads\" 2>/dev/null | head -n 40\n"
        + "  find \"$HOME\" -maxdepth 3 -type d 2>/dev/null | grep -i -F -- \"$term\" | head -n 15\n"
        + "} | awk '!seen[$0]++' | head -n 60 | while IFS= read -r p; do\n"
        + "  [ -n \"$p\" ] || continue\n"
        + "  kind=file\n"
        + "  if [ -d \"$p\" ]; then kind=dir\n"
        + "  elif [ -f \"$p\" ]; then\n"
        + "    case \"${p##*/}\" in *.AppImage|*.appimage|*.APPIMAGE) kind=exec ;; esac\n"
        + "    if [ \"$kind\" = file ] && [ -x \"$p\" ]; then\n"
        + "      magic=$(LC_ALL=C head -c 4 \"$p\" 2>/dev/null | od -An -tx1 2>/dev/null | tr -d ' \\n')\n"
        + "      [ \"$magic\" = 7f454c46 ] && kind=exec\n"
        + "    fi\n"
        + "  fi\n"
        + "  printf '%s\\t%s\\n' \"$kind\" \"$p\"\n"
        + "done\n"

    Timer {
        id: fileSearchDebounce
        interval: 180
        onTriggered: root.runFileSearch()
    }

    Process {
        id: fileSearchProcess
        running: false

        command: ["sh", "-c", root.fileSearchScript, "launcher-file-search", root.fileTerm]

        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                if (!root.fileMode)
                    return;

                const query = root.fileTerm.toLowerCase();
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                root.fileResults = lines
                    .map(function(line) {
                        const fields = line.split("\t");
                        const kind = fields.length > 1 ? fields[0] : "file";
                        const full = (fields.length > 1 ? fields[1] : fields[0]).trim();
                        if (full.length === 0)
                            return null;
                        const parts = full.split("/");
                        const name = parts[parts.length - 1] || full;
                        const short = full.indexOf(root.home + "/") === 0
                            ? "~" + full.slice(root.home.length)
                            : full;
                        const byName = name.toLowerCase().includes(query);
                        const icon = kind === "dir" ? "󰉋" : (kind === "exec" ? "󰀻" : "󰈤");
                        return {
                            path: full,
                            name: name,
                            kind: kind,
                            genericName: short + (byName ? "" : "  · text match"),
                            icon: icon,
                            isFile: true
                        };
                    })
                    .filter(Boolean);
            }
        }
    }

    // programs.lua is the source of truth for Settings -> Programs. Read it
    // fresh each time the launcher opens so Apply takes effect immediately.
    Process {
        id: programsProbe
        running: false

        command: ["sh", "-c", "cat \"$HOME/.config/hypr/hyprland/programs.lua\" 2>/dev/null || true"]

        stdout: StdioCollector {
            onStreamFinished: root.parsePrograms(text)
        }

        Component.onCompleted: running = true
    }

    IpcHandler {
        target: "launcher"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.toggle() }
    }

    Timer {
        id: focusTimer
        interval: 40
        onTriggered: field.forceActiveFocus()
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
        WlrLayershell.namespace: "quickshell-launcher-surface"
        WlrLayershell.keyboardFocus: root.shown
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            anchors.fill: card
            anchors.margins: -1
            radius: card.radius + 1
            color: "#66000000"
            opacity: root.reveal
            z: -1
        }

        Rectangle {
            id: card

            width: 640
            height: 500
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -30
            radius: Theme.panelRadius
            color: Theme.panelFill(Theme.surface, "launcher")
            border.width: 1
            border.color: Theme.border

            opacity: root.reveal
            scale: Theme.motionEnterScale + (1 - Theme.motionEnterScale) * root.reveal
            transform: Translate {
                y: -(1 - root.reveal) * Theme.motionEnterOffset
            }

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.webMode
                            ? "󰖟"
                            : (root.calcMode ? "󰓎" : (root.fileMode ? "󰱽" : "󰍉"))
                        font.family: Theme.font
                        font.pixelSize: 18
                        color: Theme.dim
                    }

                    TextField {
                        id: field

                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        placeholderText: root.webMode
                            ? "Search the web…"
                            : (root.calcMode
                                ? "Calculate — e.g. =16*11 or =sqrt(9)^2"
                                : (root.fileMode
                                    ? "Search files by name or content…"
                                    : "Search applications…"))
                        placeholderTextColor: Theme.dim
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: 15
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bg
                        leftPadding: 0
                        rightPadding: 0
                        background: Rectangle { color: "transparent" }

                        onTextChanged: {
                            root.query = text;
                            if (!root.fileMode || root.fileTerm === "") {
                                fileSearchDebounce.stop();
                                root.fileResults = [];
                                root.searching = false;
                                return;
                            }
                            fileSearchDebounce.restart();
                        }
                        onAccepted: root.launchCurrent()

                        Keys.onEscapePressed: root.close()
                        Keys.onUpPressed: root.move(-1)
                        Keys.onDownPressed: root.move(1)
                        Keys.onPressed: function (event) {
                            if (event.key === Qt.Key_PageUp) {
                                root.move(-6);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_PageDown) {
                                root.move(6);
                                event.accepted = true;
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.border
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: list

                        anchors.fill: parent
                        clip: true
                        model: root.results
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds

                        add: Transition {
                            NumberAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                property: "scale"
                                from: Theme.motionEnterScale
                                to: 1
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }
                        remove: Transition {
                            NumberAnimation {
                                property: "opacity"
                                to: 0
                                duration: Theme.motionFast
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                property: "scale"
                                to: Theme.motionEnterScale
                                duration: Theme.motionFast
                                easing.type: Easing.OutCubic
                            }
                        }
                        displaced: Transition {
                            NumberAnimation {
                                property: "y"
                                duration: Theme.motionBase
                                easing.type: Easing.OutCubic
                            }
                        }

                        delegate: Rectangle {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool highlighted: root.selected === index
                            readonly property string iconName: row.modelData.icon || ""
                            // Nerd Font glyphs live outside the BMP (or in the
                            // private use area); render those as text instead
                            // of handing them to the icon provider.
                            readonly property bool iconIsGlyph: iconName.length > 0 &&
                                iconName.charCodeAt(0) > 0xd7ff

                            width: list.width
                            height: 46
                            radius: 9
                            color: highlighted
                                ? Theme.active
                                : (rowMouse.containsMouse ? Theme.hover : "transparent")
                            scale: 1 - 0.02 * (rowMouse.containsPress ? 1 : 0)

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.motionFast
                                    easing.type: Easing.OutCubic
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    visible: row.iconIsGlyph
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    text: row.iconName
                                    font.family: Theme.mono
                                    font.pixelSize: 20
                                    color: Theme.accent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Image {
                                    visible: !row.iconIsGlyph
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    sourceSize.width: 52
                                    sourceSize.height: 52
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    source: Quickshell.iconPath(row.iconName, "application-x-executable")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.name
                                        font.family: Theme.mono
                                        font.pixelSize: 13
                                        font.weight: row.highlighted ? Font.DemiBold : Font.Normal
                                        color: row.highlighted ? Theme.accentSoft : Theme.text
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: row.modelData.genericName || row.modelData.comment || ""
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                        color: Theme.subtext
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onContainsMouseChanged: {
                                    if (containsMouse)
                                        root.selected = row.index;
                                }

                                onClicked: {
                                    root.selected = row.index;
                                    root.launchCurrent();
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: {
                            if (root.webMode) {
                                if (root.webTerm === "")
                                    return "Type a query to search the web…";
                                return "Press ↵ to search…";
                            }
                            if (root.calcMode) {
                                if (root.calcExpr === "")
                                    return "Type an expression — e.g. =16*11…";
                                return "Press ↵ to copy the result…";
                            }
                            if (root.fileMode) {
                                if (root.fileTerm === "")
                                    return "Type a file name or text to search…";
                                if (root.searching)
                                    return "Searching files…";
                                return "No files match “" + root.fileTerm + "”";
                            }
                            return root.query === ""
                                ? "Loading applications…"
                                : "No applications match “" + root.query + "”";
                        }
                        font.family: Theme.mono
                        font.pixelSize: 12
                        color: Theme.subtext
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: {
                            const unit = root.webMode || root.calcMode
                                ? (root.results.length === 1 ? " result" : " results")
                                : root.fileMode
                                    ? (root.results.length === 1 ? " file" : " files")
                                    : (root.results.length === 1 ? " application" : " applications");
                            return root.results.length + unit;
                        }
                        font.family: Theme.mono
                        font.pixelSize: 10
                        color: Theme.dim
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 12

                        Item {
                            id: calcHint
                            Layout.preferredWidth: calcHintText.width
                            Layout.preferredHeight: calcHintText.height
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: calcHintText
                                text: "= calc"
                                font.family: Theme.mono
                                font.pixelSize: 10
                                color: Theme.dim
                            }

                            MouseArea {
                                id: calcHintArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.HelpCursor
                            }

                            ToolTip {
                                visible: calcHintArea.containsMouse
                                text: "Calculator — + - * / ^ sqrt() mod()"
                                delay: 250
                            }
                        }

                        Item {
                            id: fileHint
                            Layout.preferredWidth: fileHintText.width
                            Layout.preferredHeight: fileHintText.height
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: fileHintText
                                text: ": files"
                                font.family: Theme.mono
                                font.pixelSize: 10
                                color: Theme.dim
                            }

                            MouseArea {
                                id: fileHintArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.HelpCursor
                            }

                            ToolTip {
                                visible: fileHintArea.containsMouse
                                text: "File search — find files by name or contents in your home folder"
                                delay: 250
                            }
                        }

                        Item {
                            id: webHint
                            Layout.preferredWidth: webHintText.width
                            Layout.preferredHeight: webHintText.height
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: webHintText
                                text: "' web"
                                font.family: Theme.mono
                                font.pixelSize: 10
                                color: Theme.dim
                            }

                            MouseArea {
                                id: webHintArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.HelpCursor
                            }

                            ToolTip {
                                visible: webHintArea.containsMouse
                                text: "Web search — open the query in your default browser"
                                delay: 250
                            }
                        }

                        Text {
                            text: "↑↓ navigate    ↵ open    esc close"
                            font.family: Theme.mono
                            font.pixelSize: 10
                            color: Theme.dim
                        }
                    }
                }
            }
        }
    }
}
