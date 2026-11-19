import QtQuick
import QtQuick.Layouts

// Autodetected monitor arrangement and per-output settings.
ColumnLayout {
    id: root

    property var app
    property int selected: app.selectedMonitor
    property var current: (app.monitorRevision >= 0 && app.monitorCount > 0 &&
                           selected >= 0 && selected < app.monitorCount)
        ? app.monitorAt(selected) : null

    spacing: 12

    function bestModeFor(res: string): string {
        if (!root.current) return res + "@60.00Hz";
        const modes = root.current.modes || [];
        let best = "", bestHz = -1;
        for (let i = 0; i < modes.length; i++) {
            const parts = String(modes[i]).split("@");
            if (parts[0] !== res) continue;
            const hz = parseFloat(parts[1]);
            if (hz > bestHz) { bestHz = hz; best = String(modes[i]); }
        }
        return best !== "" ? best : (res + "@60.00Hz");
    }

    Text {
        text: "Monitors"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Drag displays to arrange them, then choose a resolution, refresh rate and scale for each output."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "DISPLAY ARRANGEMENT"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: canvas

                // Fixed-size board. Monitors are drawn smaller than the
                // board so there is clear empty grid space around them.
                width: 720
                height: 300
                Layout.preferredWidth: 720
                Layout.preferredHeight: 300
                Layout.fillWidth: false
                Layout.fillHeight: false
                Layout.alignment: Qt.AlignHCenter
                radius: 10
                color: Theme.bg
                border.width: 1
                border.color: Theme.border
                clip: true

                property var geo: computeGeo(app.monitorList, width, height)

                // Fixed virtual origin: dragging one display never shifts
                // the others, so movement stays predictable and 1:1.
                property real originX: 0
                property real originY: 0

                // Scale is derived only from monitor SIZES, never their
                // positions. Dragging a display therefore cannot rescale the
                // board, so tiles track the cursor 1:1 without jumping.
                function computeGeo(model, w, h) {
                    if (!model || model.count === 0)
                        return { scale: 0.2 };
                    let totalW = 0, maxH = 1;
                    for (let i = 0; i < model.count; i++) {
                        const m = model.get(i).mon;
                        totalW += Math.max(1, app.monitorWidth(m));
                        maxH = Math.max(maxH, app.monitorHeight(m));
                    }
                    // The hard cap keeps tiles small relative to the fixed
                    // board, leaving visible grid space around them.
                    const scale = Math.max(0.05,
                        Math.min((w - 40) / totalW, (h - 40) / maxH, 0.12));
                    return { scale: scale };
                }

                // Live feedback while dragging: does the tile's current
                // position collide with any other output?
                function overlapsAt(index, rx, ry) {
                    if (!app || app.monitorCount === 0) return false;
                    const self = app.monitorAt(index);
                    if (!self) return false;
                    for (let i = 0; i < app.monitorCount; i++) {
                        if (i === index) continue;
                        const o = app.monitorAt(i);
                        const ox = Math.min(rx + app.monitorWidth(self), o.x + app.monitorWidth(o)) - Math.max(rx, o.x);
                        const oy = Math.min(ry + app.monitorHeight(self), o.y + app.monitorHeight(o)) - Math.max(ry, o.y);
                        if (ox > 0 && oy > 0) return true;
                    }
                    return false;
                }

                // Guide lines meeting at all four corners of the board.
                Repeater {
                    model: [
                        { x: 20, y: 0, w: 1, h: canvas.height },
                        { x: canvas.width - 21, y: 0, w: 1, h: canvas.height },
                        { x: 0, y: 20, w: canvas.width, h: 1 },
                        { x: 0, y: canvas.height - 21, w: canvas.width, h: 1 }
                    ]
                    Rectangle {
                        x: modelData.x
                        y: modelData.y
                        width: modelData.w
                        height: modelData.h
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                        visible: app.monitorCount > 0
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: app.monitorCount === 0
                    text: "No monitors detected"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.dim
                }

                Repeater {
                    model: app.monitorList

                    delegate: Rectangle {
                        id: tile
                        required property int index
                        required property var mon

                        // drag.target writes x/y directly and breaks the
                        // bindings, so restore them after every drag.
                        function bindGeometry() {
                            tile.x = Qt.binding(function() {
                                return (mon.x - canvas.originX) * canvas.geo.scale + 20;
                            });
                            tile.y = Qt.binding(function() {
                                return (mon.y - canvas.originY) * canvas.geo.scale + 20;
                            });
                        }

                        x: (mon.x - canvas.originX) * canvas.geo.scale + 20
                        y: (mon.y - canvas.originY) * canvas.geo.scale + 20
                        width: Math.max(24, app.monitorWidth(mon) * canvas.geo.scale)
                        height: Math.max(18, app.monitorHeight(mon) * canvas.geo.scale)
                        radius: 5
                        opacity: mon.disabled ? 0.4 : 1

                        property bool colliding: dragArea.drag.active && canvas.overlapsAt(index,
                            (tile.x - 20) / canvas.geo.scale + canvas.originX,
                            (tile.y - 20) / canvas.geo.scale + canvas.originY)

                        color: root.selected === index ? Theme.active : Theme.surfaceAlt
                        border.width: colliding ? 2 : 1
                        border.color: colliding ? "#ff6b6b"
                            : (root.selected === index ? Theme.accent : Theme.pillBorder)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: mon.name
                                font.family: Theme.mono
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.accentSoft
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillHeight: true }
                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const t = Number(mon.transform) || 0;
                                    const suffix = t ? "  " + (t * 90) + "°" : "";
                                    return app.monitorWidth(mon) + "x" + app.monitorHeight(mon)
                                        + " @" + (Math.round(mon.refresh * 100) / 100) + suffix;
                                }
                                font.family: Theme.mono
                                font.pixelSize: 9
                                color: Theme.subtext
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor

                            // Qt's own drag moves the tile one screen pixel
                            // per mouse pixel. The model is only touched on
                            // release, so the delegate never churns mid-drag.
                            drag.target: tile
                            drag.axis: Drag.XAndYAxis
                            drag.smoothed: false

                            onPressed: {
                                root.selected = index;
                                app.selectedMonitor = index;
                            }
                            onReleased: {
                                const scale = canvas.geo.scale;
                                const realX = (tile.x - 20) / scale + canvas.originX;
                                const realY = (tile.y - 20) / scale + canvas.originY;
                                app.setMonitorPos(index, realX, realY);
                                tile.bindGeometry();
                            }
                            onCanceled: tile.bindGeometry()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "Rotated displays are drawn upright. Drag a display to move it; overlaps are blocked and positions snap to a 10 px grid."
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.dim
                    wrapMode: Text.WordWrap
                }

                SettingsButton {
                    icon: "󰓅"
                    text: "Re-detect"
                    onClicked: app.detectMonitors()
                }
            }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "SELECTED DISPLAY"
        visible: root.current !== null

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Segmented {
                options: {
                    const list = [];
                    for (let i = 0; i < app.monitorCount; i++)
                        list.push({ label: app.monitorAt(i).name, value: String(i) });
                    return list;
                }
                value: String(root.selected)
                onSelected: v => {
                    root.selected = parseInt(v, 10);
                    app.selectedMonitor = root.selected;
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.current ? root.current.description : ""
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.dim
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.preferredWidth: 132
                    text: "Resolution"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.subtext
                }
                OptionCombo {
                    Layout.fillWidth: true
                    options: app.monitorModeOptions(root.selected)
                    selected: root.current ? String(root.current.mode).split("@")[0] : ""
                    onPicked: v => app.setMonitorMode(root.selected, bestModeFor(v))
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.preferredWidth: 132
                    text: "Refresh rate"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.subtext
                }
                OptionCombo {
                    Layout.fillWidth: true
                    options: root.current
                        ? app.monitorRefreshOptions(root.selected, String(root.current.mode).split("@")[0])
                        : []
                    selected: root.current ? ((Math.round(root.current.refresh * 100) / 100) + " Hz") : ""
                    onPicked: v => {
                        if (!root.current) return;
                        const res = String(root.current.mode).split("@")[0];
                        const hz = parseFloat(v);
                        app.setMonitorMode(root.selected, res + "@" + hz.toFixed(2) + "Hz");
                    }
                }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Scale"
                from: 0.5
                to: 2
                stepSize: 0.25
                decimals: 2
                value: root.current ? root.current.scale : 1
                onMoved: v => app.updateMonitor(root.selected, "scale", Math.round(v * 100) / 100)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.preferredWidth: 132
                    text: "Rotation"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.subtext
                }
                Segmented {
                    options: [
                        { label: "0°", value: "0" },
                        { label: "90°", value: "1" },
                        { label: "180°", value: "2" },
                        { label: "270°", value: "3" }
                    ]
                    value: root.current ? String(root.current.transform) : "0"
                    onSelected: v => app.updateMonitor(root.selected, "transform", parseInt(v, 10))
                }
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Enabled"
                hint: "Turn this output off"
                checked: root.current ? !root.current.disabled : true
                onToggled: v => app.updateMonitor(root.selected, "disabled", !v)
            }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "IDLE & LOCK"

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            ToggleRow {
                Layout.fillWidth: true
                label: "Auto dim and lock"
                hint: "Generate ~/.config/hypr/hypridle.conf on Apply"
                checked: app.idleEnabled
                onToggled: value => { app.idleEnabled = value; app.queueSave() }
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Dim screen"
                hint: "Lower brightness when idle"
                checked: app.idleDimEnabled
                onToggled: value => { app.idleDimEnabled = value; app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Dim after"
                from: 30
                to: 900
                stepSize: 30
                suffix: "s"
                value: app.idleDimTimeout
                onMoved: value => { app.idleDimTimeout = Math.round(value); app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Dim brightness"
                from: 1
                to: 50
                stepSize: 1
                suffix: "%"
                value: app.idleDimLevel
                onMoved: value => { app.idleDimLevel = Math.round(value); app.queueSave() }
            }

            ToggleRow {
                Layout.fillWidth: true
                label: "Lock screen"
                hint: "Lock the session when idle"
                checked: app.idleLockEnabled
                onToggled: value => { app.idleLockEnabled = value; app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Lock after"
                from: 60
                to: 1800
                stepSize: 30
                suffix: "s"
                value: app.idleLockTimeout
                onMoved: value => { app.idleLockTimeout = Math.round(value); app.queueSave() }
            }

            Text {
                Layout.fillWidth: true
                text: "Display-off (330s) and suspend (900s) are kept as power-saving follow-ups. Press Apply layout to rewrite hypridle.conf."
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.dim
                wrapMode: Text.WordWrap
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SettingsButton {
            icon: "󰉋"
            text: "Open config folder"
            onClicked: app.openHyprFolder()
        }

        Item { Layout.fillWidth: true }

        SettingsButton {
            icon: "󰄬"
            text: "Apply layout"
            primary: true
            onClicked: app.applyAll()
        }
    }
}
