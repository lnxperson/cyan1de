import QtQuick
import QtQuick.Layouts

// Fixed three-slot editor for the panel. The preview deliberately ignores
// the live layout (pills / unified / island) and always shows three pills,
// so section dragging stays predictable in every mode.
Rectangle {
    id: root

    property var app
    property string mode: "sections"
    property Item overlayHost: null

    readonly property bool vertical: app
        && (app.barEdge === "left" || app.barEdge === "right")
    readonly property Item ghostHost: overlayHost ? overlayHost : monitor
    readonly property int previewWidth: monitor.width
    readonly property int previewHeight: monitor.height
    readonly property bool dragging: draggingSection !== ""
        || draggingElement !== ""
    readonly property int thickness: app
        ? Math.max(24, Math.min(48, app.barPanelHeight)) : 34
    readonly property int gap: 4
    readonly property int slotGap: 8
    readonly property int slotInset: 4
    readonly property int slotPadding: 8

    property string draggingSection: ""
    property string draggingElement: ""
    property string dragElementSection: ""
    property string elementSection: "right"
    property var roleSections: ({
        workspace: "left",
        notification: "center",
        action: "right"
    })
    // Several elements can be parked in the transfer tray at once. Each
    // entry keeps its original section so it can be put back without losing
    // track of where it came from.
    property var heldElements: []
    readonly property var heldKeys: {
        const keys = [];
        for (let i = 0; i < root.heldElements.length; i++)
            keys.push(root.heldElements[i].key);
        return keys;
    }
    property real dragCenterX: 0
    property real dragCenterY: 0
    property real dragLastX: 0
    property real dragLastY: 0
    property int activeSlot: -1
    property bool overTransfer: false
    property string dropTargetElement: ""
    property var sectionItems: ({})

    implicitHeight: (vertical ? 420 : 160)
        + (mode === "elements" ? 40 : 0)
    radius: Theme.panelRadius
    color: Theme.bg
    border.width: 1
    border.color: Theme.border

    Component.onCompleted: root.refreshRoleSections()

    Connections {
        target: root.app

        // Settings load asynchronously; keep roles current until the user
        // enters Elements mode, where the map is intentionally frozen.
        function onBarElementLayoutChanged() {
            if (root.mode !== "elements")
                root.refreshRoleSections();
        }
    }

    function elementVisible(key) {
        if (!app) return false;
        switch (key) {
            case "appMenu": return app.barShowAppMenu;
            case "workspaces": return app.barShowWorkspaces;
            case "clock": return app.barShowClock;
            case "tray": return app.barShowTray;
            case "bluetooth": return app.barShowBluetooth;
            case "network": return app.barShowNetwork;
            case "volume": return app.barShowVolume;
            case "brightness": return app.barShowBrightness;
            case "battery": return app.barShowBattery;
            case "power": return app.barShowPower;
            case "updates": return app.barShowUpdates;
        }
        return false;
    }

    function isHeld(key) {
        for (let i = 0; i < root.heldElements.length; i++) {
            if (root.heldElements[i].key === key)
                return true;
        }
        return false;
    }

    function heldSource(key) {
        for (let i = 0; i < root.heldElements.length; i++) {
            if (root.heldElements[i].key === key)
                return root.heldElements[i].from;
        }
        return "";
    }

    function stageElement(key, from) {
        if (root.isHeld(key))
            return;
        const next = [];
        for (let i = 0; i < root.heldElements.length; i++)
            next.push(root.heldElements[i]);
        next.push({ key: key, from: from || root.elementSection });
        root.heldElements = next;
    }

    function unstageElement(key) {
        const next = [];
        for (let i = 0; i < root.heldElements.length; i++) {
            if (root.heldElements[i].key !== key)
                next.push(root.heldElements[i]);
        }
        root.heldElements = next;
    }

    function isActionKey(key) {
        return key === "tray" || key === "bluetooth" || key === "network"
            || key === "volume" || key === "brightness" || key === "battery"
            || key === "power";
    }

    function baseElementSize(key) {
        if (root.vertical) {
            if (key === "workspaces" || key === "clock") return 26;
            if (key === "tray") return 14;
            return 12;
        }
        if (root.isActionKey(key)) {
            const perSlot = (root.slotAxisSize() - root.slotPadding * 2
                - root.gap * 6) / 7;
            return Math.max(18, Math.min(24, Math.floor(perSlot)));
        }
        switch (key) {
            case "appMenu": return 26;
            case "workspaces": return 144;
            case "clock": return 164;
        }
        return 40;
    }

    // Elements mode gives the selected section the whole preview, so its
    // elements are drawn much larger than the compact bar-sized ones used by
    // Sections mode. The scale is capped so a crowded section still fits.
    function elementScale() {
        if (root.mode !== "elements") return 1;
        const keys = root.visibleElements(root.elementSection);
        let base = 0;
        for (let i = 0; i < keys.length; i++)
            base += root.baseElementSize(keys[i]);
        if (base <= 0) return 2;
        const gapTotal = Math.max(0, keys.length - 1) * root.gap;
        const budget = root.axisLength() - root.slotPadding * 2 - gapTotal;
        return Math.min(2, Math.max(1, budget / base));
    }

    function elementSize(key) {
        return Math.round(root.baseElementSize(key) * root.elementScale());
    }

    function elementChipCrossSize() {
        return root.mode === "elements"
            ? Math.max(28, root.thickness + 12)
            : Math.max(10, root.thickness - 10);
    }

    function elementChipWidth(key) {
        return root.vertical
            ? root.elementChipCrossSize() : root.elementSize(key);
    }

    function elementChipHeight(key) {
        return root.vertical
            ? root.elementSize(key) : root.elementChipCrossSize();
    }

    function elementFontSize(key) {
        const scale = root.mode === "elements" ? 1.8 : 1;
        if (!root.elementIsIcon(key))
            return Math.max(8, Math.round((app.barFontSize - 2) * scale));
        if (root.vertical)
            return Math.max(root.mode === "elements" ? 16 : 8,
                Math.round((app.barFontSize - 4) * scale));
        return Math.max(root.mode === "elements" ? 18 : 10,
            Math.round(app.barFontSize * scale));
    }

    function verticalIcon(key) {
        switch (key) {
            case "appMenu": return "󰀻";
            case "workspaces": return "󰘶";
            case "clock": return "󰥔";
            case "tray": return "󰱛";
            case "bluetooth": return "󰂯";
            case "network": return "󰤨";
            case "volume": return "󰕾";
            case "brightness": return "󰃠";
            case "battery": return "󰂂";
            case "power": return "⏻";
            case "updates": return "↑";
        }
        return "•";
    }

    function elementLabel(key) {
        // The action cluster stays icon-only in horizontal previews so it
        // reads as one compact group instead of dwarfing the other sections.
        if (root.vertical || root.isActionKey(key))
            return root.verticalIcon(key);
        switch (key) {
            case "appMenu": return "󰀻";
            case "workspaces": return "1 2 3 4 5 6 7 8 9 10";
            case "clock": return "󰥔  Tue 17 Nov  19:42";
            case "updates": return "↑ 12";
        }
        return key;
    }

    function elementIsIcon(key) {
        return root.vertical || key === "appMenu" || root.isActionKey(key);
    }

    function visibleElements(section) {
        if (!app) return [];
        const layout = app.barElementLayout || ({});
        const list = layout[section] || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const key = list[i];
            if (root.isHeld(key))
                continue;
            if (root.elementVisible(key) && out.indexOf(key) < 0)
                out.push(key);
        }
        return out;
    }

    function sectionSize(section) {
        const keys = root.visibleElements(section);
        let total = 0;
        for (let i = 0; i < keys.length; i++)
            total += root.elementSize(keys[i]);
        return total + Math.max(0, keys.length - 1) * root.gap;
    }

    function sectionVisible(section) {
        return root.visibleElements(section).length > 0;
    }

    // Roles follow the elements the user actually placed, not a fixed
    // left/center/right mapping. This keeps "Workspace" and "Notification"
    // correct even after the two sections have been swapped.
    function findRoleSection(layout, used, keys) {
        const sections = ["left", "center", "right"];
        for (let k = 0; k < keys.length; k++) {
            for (let s = 0; s < sections.length; s++) {
                const section = sections[s];
                if (used[section])
                    continue;
                const list = layout[section] || [];
                if (list.indexOf(keys[k]) >= 0)
                    return section;
            }
        }
        return "";
    }

    function computeRoleSections() {
        const layout = app && app.barElementLayout
            ? app.barElementLayout : ({});
        const used = {};
        const out = {};

        function claim(role, keys, fallback) {
            let section = root.findRoleSection(layout, used, keys);
            if (!section) {
                const order = [fallback, "left", "center", "right"];
                for (let i = 0; i < order.length; i++) {
                    if (!used[order[i]]) {
                        section = order[i];
                        break;
                    }
                }
            }
            if (!section)
                section = fallback;
            used[section] = true;
            out[role] = section;
        }

        claim("workspace", ["workspaces"], "left");
        claim("notification", ["clock"], "center");
        claim("action", ["tray", "bluetooth", "network", "volume",
            "brightness", "battery", "updates", "power"], "right");
        return out;
    }

    function refreshRoleSections() {
        root.roleSections = root.computeRoleSections();
    }

    function roleOrder() {
        return [root.roleSections.workspace,
            root.roleSections.notification, root.roleSections.action];
    }

    function roleLabels() {
        const map = root.roleSections;
        const out = {};
        out[map.workspace] = "Workspace";
        out[map.notification] = "Notification";
        out[map.action] = "Action";
        return out;
    }

    function sectionDisplayName(section) {
        const map = root.roleSections;
        if (map.workspace === section) return "Workspace";
        if (map.notification === section) return "Notification";
        return "Action";
    }

    function visibleSections() {
        return root.mode === "elements"
            ? [root.elementSection] : ["left", "center", "right"];
    }

    function fraction(section) {
        return app ? app.barPillFraction(section) : 0;
    }

    function axisLength() {
        return root.vertical ? monitor.height : monitor.width;
    }

    function axisMargin() {
        return 12;
    }

    function slotAxisSize() {
        return Math.max(1, (root.axisLength() - root.axisMargin() * 2
            - root.slotGap * 2) / 3);
    }

    function slotStart(index) {
        return root.axisMargin() + index * (root.slotAxisSize() + root.slotGap);
    }

    function crossPos() {
        return (root.vertical ? monitor.width : monitor.height) / 2
            - root.thickness / 2;
    }

    // Elements mode expands the one visible section to the whole preview,
    // so its pill, drop field and hit area all use the full monitor instead
    // of the narrow one-third slot used by Sections mode.
    function editorAxisSize() {
        return root.mode === "elements"
            ? root.axisLength() : root.slotAxisSize();
    }

    function editorCrossSize() {
        return root.mode === "elements"
            ? (root.vertical ? monitor.width : monitor.height)
            : root.thickness;
    }

    function editorStart(index) {
        return root.mode === "elements" ? 0 : root.slotStart(index);
    }

    function editorCrossStart() {
        return root.mode === "elements" ? 0 : root.crossPos();
    }

    function sectionSlot(section) {
        const f = Math.min(1, Math.max(0, root.fraction(section)));
        return Math.max(0, Math.min(2, Math.round(f * 2)));
    }

    function pillAxisSize(section) {
        if (root.mode === "elements") return root.editorAxisSize();
        const maxSize = Math.max(1, root.slotAxisSize() - root.slotInset * 2);
        return Math.min(maxSize,
            Math.max(48, root.sectionSize(section) + root.slotPadding * 2));
    }

    function sectionScale(section) {
        const content = root.sectionSize(section);
        if (content <= 0) return 1;
        const available = Math.max(1,
            root.pillAxisSize(section) - root.slotPadding * 2);
        return Math.min(1, available / content);
    }

    // The big field is a visual guide. The actual magnet is the small centre
    // target inside it, so pulling away is quick and deliberate.
    function fieldAxisSize() {
        if (root.mode === "elements") return root.editorAxisSize();
        return Math.max(72, root.slotAxisSize() - root.slotInset * 2);
    }

    function fieldCrossSize() {
        if (root.mode === "elements") return root.editorCrossSize();
        return root.thickness + 32;
    }

    function fieldStart(index) {
        if (root.mode === "elements") return 0;
        return root.slotStart(index)
            + (root.slotAxisSize() - root.fieldAxisSize()) / 2;
    }

    function fieldCrossStart() {
        if (root.mode === "elements") return 0;
        return (root.vertical ? monitor.width : monitor.height) / 2
            - root.fieldCrossSize() / 2;
    }

    function magnetAxisSize() {
        return 30;
    }

    function magnetCrossSize() {
        return 30;
    }

    function magnetStart(index) {
        return root.slotStart(index)
            + (root.slotAxisSize() - root.magnetAxisSize()) / 2;
    }

    function magnetCrossStart() {
        return (root.vertical ? monitor.width : monitor.height) / 2
            - root.magnetCrossSize() / 2;
    }

    function dragAxis() {
        return root.vertical ? root.dragCenterY : root.dragCenterX;
    }

    function dragCross() {
        return root.vertical ? root.dragCenterX : root.dragCenterY;
    }

    function slotAtPosition(axisPos, crossPos) {
        const crossStart = root.magnetCrossStart();
        if (crossPos < crossStart
            || crossPos > crossStart + root.magnetCrossSize())
            return -1;
        for (let i = 0; i < 3; i++) {
            const start = root.magnetStart(i);
            if (axisPos >= start && axisPos <= start + root.magnetAxisSize())
                return i;
        }
        return -1;
    }

    function pointInSelectedField(x, y) {
        const index = root.sectionSlot(root.elementSection);
        const axisStart = root.fieldStart(index);
        const axisEnd = axisStart + root.fieldAxisSize();
        const crossStart = root.fieldCrossStart();
        const crossEnd = crossStart + root.fieldCrossSize();
        if (root.vertical)
            return y >= axisStart && y <= axisEnd
                && x >= crossStart && x <= crossEnd;
        return x >= axisStart && x <= axisEnd
            && y >= crossStart && y <= crossEnd;
    }

    function pointInTransferZone() {
        if (!transferZone.visible) return false;
        const p = monitor.mapToItem(transferZone,
            root.dragCenterX, root.dragCenterY);
        return p.x >= 0 && p.x <= transferZone.width
            && p.y >= 0 && p.y <= transferZone.height;
    }

    function updateElementDropState() {
        root.overTransfer = root.pointInTransferZone();
        root.activeSlot = root.pointInSelectedField(
            root.dragCenterX, root.dragCenterY)
            ? root.sectionSlot(root.elementSection) : -1;
        root.dropTargetElement = root.hoveredDropTarget();
    }

    function finishElementDrag(elementKey, area, mouseX, mouseY) {
        const targetSection = root.elementSection;
        if (root.overTransfer) {
            root.stageElement(elementKey, root.dragElementSection);
            root.clearDrag();
            return;
        }
        if (root.pointInSelectedField(root.dragCenterX, root.dragCenterY)) {
            const section = root.sectionItems[targetSection];
            const index = section
                ? section.insertIndexFor(area, mouseX, mouseY)
                : root.visibleElements(targetSection).length;
            app.moveBarElement(elementKey, targetSection, index);
            if (root.isHeld(elementKey))
                root.unstageElement(elementKey);
        }
        root.clearDrag();
    }

    function clearHeld() {
        root.heldElements = [];
    }

    function sectionAtSlot(index) {
        return ["left", "center", "right"][index] || "left";
    }

    // Return the index of the element whose slot is directly under the
    // pointer, using the slots as they are currently drawn. The dragged
    // chip's slot is still visible, so keeping it here prevents the target
    // from shifting one element to the right. The same index is used for the
    // drop, so the highlighted element is where the chip lands.
    function insertIndex(section, localAxisPos) {
        const keys = root.visibleElements(section);
        let offset = 0;
        for (let i = 0; i < keys.length; i++) {
            const size = root.elementSize(keys[i]);
            if (localAxisPos < offset + size) return i;
            offset += size + root.gap;
        }
        return keys.length;
    }

    // The element the dragged chip would displace at its current position.
    // This is also the one highlighted while the pointer is over it.
    function hoveredDropTarget() {
        if (root.draggingElement === "" || root.activeSlot < 0)
            return "";
        const section = root.sectionItems[root.elementSection];
        if (!section || !section.dropIndexForPoint)
            return "";
        const index = section.dropIndexForPoint({
            x: root.dragCenterX, y: root.dragCenterY
        });
        const keys = root.visibleElements(root.elementSection);
        if (keys.length === 0) return "";
        const target = index >= keys.length
            ? keys[keys.length - 1] : (keys[index] || "");
        return target === root.draggingElement ? "" : target;
    }

    function mapPoint(area, mouseX, mouseY) {
        return area.mapToItem(monitor, mouseX, mouseY);
    }

    function registerSection(key, item) {
        if (!item) return;
        const next = {};
        for (const k in sectionItems) next[k] = sectionItems[k];
        next[key] = item;
        sectionItems = next;
    }

    function unregisterSection(key, item) {
        if (sectionItems[key] !== item) return;
        const next = {};
        for (const k in sectionItems) {
            if (k !== key) next[k] = sectionItems[k];
        }
        sectionItems = next;
    }

    function clearDrag() {
        draggingSection = "";
        draggingElement = "";
        dragElementSection = "";
        dragCenterX = 0;
        dragCenterY = 0;
        dragLastX = 0;
        dragLastY = 0;
        activeSlot = -1;
        overTransfer = false;
        dropTargetElement = "";
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "ARRANGE"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

            Segmented {
                options: [
                    { label: "Sections", value: "sections" },
                    { label: "Elements", value: "elements" }
                ]
                value: root.mode
                onSelected: value => {
                    if (value !== "elements")
                        root.clearHeld();
                    else
                        root.refreshRoleSections();
                    root.mode = value;
                    root.clearDrag();
                }
            }

            OptionCombo {
                visible: root.mode === "elements"
                Layout.preferredWidth: 150
                options: root.roleOrder()
                labels: root.roleLabels()
                selected: root.elementSection
                onPicked: value => {
                    root.elementSection = value;
                    root.clearDrag();
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                Layout.maximumWidth: 300
                text: (app ? app.barEdge.toUpperCase() + " EDGE · " : "")
                    + (root.mode === "sections"
                        ? "Lift a section, then drop it on a centre magnet."
                        : "Edit one section at a time. Use the transfer tray "
                            + "to move elements between sections.")
                font.family: Theme.mono
                font.pixelSize: 9
                color: Theme.dim
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            id: monitor
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            radius: Theme.panelRadius
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
            clip: true

            // Three large drop fields, each with a tiny centre magnet. Only
            // the centre magnet is a valid drop target.
            Repeater {
                model: 3

                delegate: Rectangle {
                    readonly property int zoneAxis: root.fieldAxisSize()
                    readonly property int zoneCross: root.fieldCrossSize()

                    visible: root.mode === "sections"
                        || index === root.sectionSlot(root.elementSection)
                    x: root.vertical ? (monitor.width - zoneCross) / 2
                        : root.fieldStart(index)
                    y: root.vertical ? root.fieldStart(index)
                        : (monitor.height - zoneCross) / 2
                    width: root.vertical ? zoneCross : zoneAxis
                    height: root.vertical ? zoneAxis : zoneCross
                    radius: Theme.panelRadius
                    color: "transparent"
                    border.width: root.activeSlot === index ? 2 : 1
                    border.color: root.activeSlot === index
                        ? "#7fe0b0" : Theme.accent
                    opacity: root.dragging
                        ? (root.activeSlot === index ? 0.75 : 0.18) : 0.08
                    enabled: false
                    z: 3

                    Behavior on opacity {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        readonly property bool active: root.activeSlot === index

                        visible: root.mode === "sections"
                        width: root.magnetAxisSize()
                        height: root.magnetCrossSize()
                        anchors.centerIn: parent
                        radius: Math.min(width, height) / 2
                        color: active ? "#337fe0b0" : "transparent"
                        border.width: active ? 2 : 1
                        border.color: active ? "#7fe0b0" : Theme.accent
                        opacity: root.dragging ? 1 : 0.45
                        scale: active ? 1.2 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 100
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            anchors.centerIn: parent
                            color: parent.active ? "#7fe0b0" : Theme.accent
                            opacity: 0.85
                        }
                    }

                    Text {
                        visible: !root.vertical
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        text: root.mode === "elements"
                            ? root.sectionDisplayName(root.elementSection)
                                .toUpperCase()
                            : ["LEFT", "CENTER", "RIGHT"][index]
                        font.family: Theme.mono
                        font.pixelSize: 8
                        color: root.activeSlot === index
                            ? "#7fe0b0" : Theme.accent
                    }
                }
            }

            // Sections mode shows all three pills. Elements mode shows only
            // the section selected in the dropdown next to the mode switch.
            Repeater {
                model: root.visibleSections()

                delegate: Item {
                    required property string modelData

                    readonly property string sectionKey: modelData
                    readonly property int slotIndex: root.sectionSlot(sectionKey)
                    readonly property int pillAxis: root.pillAxisSize(sectionKey)
                    readonly property bool hasContent:
                        root.sectionVisible(sectionKey)
                    readonly property bool sectionDragging:
                        root.draggingSection === sectionKey

                    x: root.vertical ? root.editorCrossStart()
                        : root.editorStart(slotIndex)
                            + (root.editorAxisSize() - pillAxis) / 2
                    y: root.vertical
                        ? root.editorStart(slotIndex)
                            + (root.editorAxisSize() - pillAxis) / 2
                        : root.editorCrossStart()
                    width: root.vertical ? root.editorCrossSize() : pillAxis
                    height: root.vertical ? pillAxis : root.editorCrossSize()
                    z: sectionDragging ? 5 : 1

                    Component.onCompleted: root.registerSection(sectionKey, this)
                    Component.onDestruction: root.unregisterSection(sectionKey, this)

                    function insertIndexFor(area, mouseX, mouseY) {
                        const p = area.mapToItem(elementFlow, mouseX, mouseY);
                        return root.insertIndex(sectionKey,
                            root.vertical ? p.y : p.x);
                    }

                    function dropIndexForPoint(point) {
                        const p = elementFlow.mapFromItem(monitor,
                            point.x, point.y);
                        return root.insertIndex(sectionKey,
                            root.vertical ? p.y : p.x);
                    }

                    Item {
                        id: visual
                        anchors.fill: parent
                        opacity: sectionDragging ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: root.mode === "elements"
                                ? Theme.panelRadius
                                : (app ? app.barPillRadius : Theme.panelRadius)
                            color: Theme.pillFill
                            border.width: 1
                            border.color: Theme.pillBorder
                            opacity: hasContent ? 1 : 0.35
                        }

                        Rectangle {
                            visible: root.mode === "elements" && hasContent
                            anchors.fill: parent
                            radius: root.mode === "elements"
                                ? Theme.panelRadius
                                : (app ? app.barPillRadius : Theme.panelRadius)
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.accent
                            opacity: 0.25
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !hasContent
                            text: "EMPTY"
                            font.family: Theme.mono
                            font.pixelSize: 8
                            color: Theme.dim
                        }

                        Flow {
                            id: elementFlow
                            anchors.centerIn: parent
                            flow: root.vertical
                                ? Flow.TopToBottom : Flow.LeftToRight
                            spacing: root.gap
                            scale: root.sectionScale(sectionKey)

                            Repeater {
                                model: root.visibleElements(sectionKey)

                                delegate: Item {
                                    required property string modelData

                                    readonly property string elementKey: modelData
                                    readonly property bool elementDragging:
                                        root.draggingElement === elementKey
                                    readonly property bool dropTarget:
                                        root.draggingElement !== ""
                                        && !elementDragging
                                        && root.dropTargetElement === elementKey

                                    width: root.elementChipWidth(elementKey)
                                    height: root.elementChipHeight(elementKey)
                                    opacity: elementDragging ? 0 : 1
                                    z: elementDragging ? 10 : 2

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 80
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: elementDragging
                                            ? Theme.active
                                            : dropTarget
                                                ? "#337fe0b0"
                                                : (elementMouse.containsMouse
                                                    && root.mode === "elements"
                                                    ? Theme.hover : "transparent")
                                        border.width: dropTarget ? 2
                                            : (root.mode === "elements"
                                                && (elementMouse.containsMouse
                                                    || elementDragging) ? 1 : 0)
                                        border.color: dropTarget
                                            ? "#7fe0b0" : Theme.accent

                                        Behavior on color {
                                            ColorAnimation { duration: 90 }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width
                                            - (root.mode === "elements" ? 10 : 4)
                                        text: root.elementLabel(elementKey)
                                        font.family: root.elementIsIcon(elementKey)
                                            ? Theme.font : Theme.mono
                                        font.pixelSize: root.elementFontSize(elementKey)
                                        color: root.elementIsIcon(elementKey)
                                            ? Theme.accent : Theme.text
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    MouseArea {
                                        id: elementMouse
                                        anchors.fill: parent
                                        enabled: root.mode === "elements"
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: Qt.SizeAllCursor

                                        onPressed: {
                                            const p = root.mapPoint(
                                                elementMouse, mouseX, mouseY);
                                            const c = elementMouse.mapToItem(
                                                monitor, elementMouse.width / 2,
                                                elementMouse.height / 2);
                                            root.draggingSection = "";
                                            root.draggingElement = elementKey;
                                            root.dragElementSection = sectionKey;
                                            root.dragCenterX = c.x;
                                            root.dragCenterY = c.y;
                                            root.dragLastX = p.x;
                                            root.dragLastY = p.y;
                                            root.updateElementDropState();
                                        }
                                        onPositionChanged: {
                                            const p = root.mapPoint(
                                                elementMouse, mouseX, mouseY);
                                            root.dragCenterX += p.x - root.dragLastX;
                                            root.dragCenterY += p.y - root.dragLastY;
                                            root.dragLastX = p.x;
                                            root.dragLastY = p.y;
                                            root.updateElementDropState();
                                        }
                                        onReleased: {
                                            root.finishElementDrag(
                                                elementKey, elementMouse,
                                                mouseX, mouseY);
                                        }
                                        onCanceled: root.clearDrag()
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: sectionMouse
                        anchors.fill: parent
                        enabled: root.mode === "sections" && hasContent
                        preventStealing: true
                        cursorShape: Qt.SizeAllCursor

                        onPressed: {
                            const p = root.mapPoint(
                                sectionMouse, mouseX, mouseY);
                            const c = sectionMouse.mapToItem(
                                monitor, sectionMouse.width / 2,
                                sectionMouse.height / 2);
                            root.draggingSection = sectionKey;
                            root.draggingElement = "";
                            root.dragElementSection = "";
                            root.dragCenterX = c.x;
                            root.dragCenterY = c.y;
                            root.dragLastX = p.x;
                            root.dragLastY = p.y;
                            root.activeSlot = root.slotAtPosition(
                                root.dragAxis(), root.dragCross());
                        }
                        onPositionChanged: {
                            const p = root.mapPoint(
                                sectionMouse, mouseX, mouseY);
                            root.dragCenterX += p.x - root.dragLastX;
                            root.dragCenterY += p.y - root.dragLastY;
                            root.dragLastX = p.x;
                            root.dragLastY = p.y;
                            root.activeSlot = root.slotAtPosition(
                                root.dragAxis(), root.dragCross());
                        }
                        onReleased: {
                            const target = root.activeSlot;
                            if (target >= 0 && target !== slotIndex)
                                app.setBarPillPosition(sectionKey, target * 0.5);
                            root.clearDrag();
                        }
                        onCanceled: root.clearDrag()
                    }
                }
            }

            // Lifted section follows the pointer, with a slight lift scale.
            // It lives in the full-screen overlay when one is available.
            Item {
                id: sectionGhost
                visible: root.draggingSection !== ""
                parent: root.ghostHost

                readonly property string sectionKey: root.draggingSection
                readonly property point ghostPoint: monitor.mapToItem(
                    root.ghostHost, root.dragCenterX, root.dragCenterY)

                width: root.vertical
                    ? root.thickness : root.pillAxisSize(sectionKey)
                height: root.vertical
                    ? root.pillAxisSize(sectionKey) : root.thickness
                x: ghostPoint.x - width / 2
                y: ghostPoint.y - height / 2
                z: 30
                scale: root.draggingSection !== "" ? 1.04 : 1
                Behavior on scale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: (app ? app.barPillRadius : Theme.panelRadius) + 4
                    color: "#66000000"
                    z: -1
                }

                Rectangle {
                    anchors.fill: parent
                    radius: app ? app.barPillRadius : Theme.panelRadius
                    color: Theme.pillFill
                    border.width: 1
                    border.color: Theme.accent
                }

                Flow {
                    anchors.centerIn: parent
                    flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                    spacing: root.gap
                    scale: root.sectionScale(sectionGhost.sectionKey)

                    Repeater {
                        model: root.visibleElements(sectionGhost.sectionKey)

                        delegate: Item {
                            required property string modelData

                            readonly property string elementKey: modelData

                            width: root.elementChipWidth(elementKey)
                            height: root.elementChipHeight(elementKey)

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 4
                                text: root.elementLabel(elementKey)
                                font.family: root.elementIsIcon(elementKey)
                                    ? Theme.font : Theme.mono
                                font.pixelSize: root.elementFontSize(elementKey)
                                color: root.elementIsIcon(elementKey)
                                    ? Theme.accent : Theme.text
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }

            // Lifted element chip follows the pointer independently.
            Item {
                id: elementGhost
                visible: root.draggingElement !== ""
                parent: root.ghostHost

                readonly property string elementKey: root.draggingElement
                readonly property point ghostPoint: monitor.mapToItem(
                    root.ghostHost, root.dragCenterX, root.dragCenterY)

                width: root.elementChipWidth(elementKey)
                height: root.elementChipHeight(elementKey)
                x: ghostPoint.x - width / 2
                y: ghostPoint.y - height / 2
                z: 31
                scale: root.draggingElement !== ""
                    ? root.sectionScale(root.dragElementSection) * 1.08 : 1
                Behavior on scale {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 7
                    color: "#66000000"
                    z: -1
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: Theme.active
                    border.width: 1
                    border.color: Theme.accent
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 4
                    text: root.elementLabel(elementGhost.elementKey)
                    font.family: root.elementIsIcon(elementGhost.elementKey)
                        ? Theme.font : Theme.mono
                    font.pixelSize: root.elementFontSize(elementGhost.elementKey)
                    color: root.elementIsIcon(elementGhost.elementKey)
                        ? Theme.accent : Theme.text
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Elements can be parked here while the user switches sections.
        Rectangle {
            id: transferZone
            visible: root.mode === "elements"
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 32 : 0
            radius: 6
            color: root.overTransfer ? Theme.active : Theme.surfaceAlt
            border.width: 1
            border.color: root.overTransfer ? "#7fe0b0" : Theme.border

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: root.heldElements.length === 0
                        ? "TRANSFER TRAY · drag elements here, switch "
                            + "sections, then drag them into the preview"
                        : "HOLDING " + root.heldElements.length
                            + (root.heldElements.length === 1
                                ? " element" : " elements")
                            + " · switch sections, then drag them into the preview"
                    font.family: Theme.mono
                    font.pixelSize: 9
                    color: root.overTransfer ? "#7fe0b0" : Theme.dim
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: root.heldKeys

                    delegate: Rectangle {
                        required property string modelData

                        readonly property string heldKey: modelData

                        Layout.preferredWidth: Math.max(34,
                            Math.min(150, root.elementChipWidth(heldKey)))
                        Layout.preferredHeight: Math.max(18,
                            Math.min(22, root.elementChipHeight(heldKey)))
                        radius: 4
                        color: Theme.active
                        border.width: 1
                        border.color: Theme.accent
                        opacity: root.draggingElement === heldKey
                            && root.draggingElement !== "" ? 0.25 : 1

                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 4
                            text: root.elementLabel(heldKey)
                            font.family: root.elementIsIcon(heldKey)
                                ? Theme.font : Theme.mono
                            // Tray chips stay compact even when preview
                            // elements are scaled up for editing.
                            font.pixelSize: Math.min(
                                root.elementFontSize(heldKey), 12)
                            color: root.elementIsIcon(heldKey)
                                ? Theme.accent : Theme.text
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id: heldMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.SizeAllCursor

                            onPressed: {
                                const p = root.mapPoint(heldMouse, mouseX, mouseY);
                                const c = heldMouse.mapToItem(monitor,
                                    heldMouse.width / 2, heldMouse.height / 2);
                                root.draggingSection = "";
                                root.draggingElement = heldKey;
                                root.dragElementSection = root.heldSource(heldKey)
                                    || root.elementSection;
                                root.dragCenterX = c.x;
                                root.dragCenterY = c.y;
                                root.dragLastX = p.x;
                                root.dragLastY = p.y;
                                root.updateElementDropState();
                            }
                            onPositionChanged: {
                                const p = root.mapPoint(heldMouse, mouseX, mouseY);
                                root.dragCenterX += p.x - root.dragLastX;
                                root.dragCenterY += p.y - root.dragLastY;
                                root.dragLastX = p.x;
                                root.dragLastY = p.y;
                                root.updateElementDropState();
                            }
                            onReleased: {
                                root.finishElementDrag(heldKey, heldMouse,
                                    mouseX, mouseY);
                            }
                            onCanceled: root.clearDrag()
                        }
                    }
                }
            }
        }
    }
}
