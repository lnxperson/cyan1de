import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

PanelWindow {
    id: bar

    property var modelData
    property var shellRoot: null
    property var activePopup: null
    property bool switchingPopup: false

    // HyprlandFocusGrab routes popup keys to this bar. The popup windows stay
    // focusable by pointer, so keyboard navigation is dispatched from here
    // instead of giving the popups an xdg keyboard grab that swallowed clicks.
    Item {
        id: popupKeySink
        focus: true
        activeFocusOnTab: false

        Keys.onPressed: function (event) {
            const popup = bar.activePopup;
            if (!popup || !popup.popupSurface)
                return;
            popup.popupSurface.handleKey(event);
        }
    }

    // A fixed grab list avoids tearing down and reacquiring the focus grab on
    // every action-popup switch. Inactive popups are hidden, so they cannot
    // receive input even though they stay in the list.
    readonly property var allPopupWindows: [
        bar, calendarPopup, actionPopupHost
    ]

    // Keep the existing bar bindings while the action popups now live inside
    // one persistent host window.
    readonly property var volumePopup: actionPopupHost.volumePopup
    readonly property var brightnessPopup: actionPopupHost.brightnessPopup
    readonly property var bluetoothPopup: actionPopupHost.bluetoothPopup
    readonly property var networkPopup: actionPopupHost.networkPopup
    readonly property var batteryPopup: actionPopupHost.batteryPopup
    readonly property var powerPopup: actionPopupHost.powerPopup

    readonly property string notificationHistoryPath: Quickshell.env("HOME")
        + "/.config/quickshell/notification-history.json"
    property int notificationHistoryCount: 0

    function syncNotificationHistoryCount() {
        try {
            notificationHistoryFile.reload();
            const parsed = JSON.parse(notificationHistoryFile.text());
            bar.notificationHistoryCount = Array.isArray(parsed) ? parsed.length : 0;
        } catch (e) {
            // Keep the last good count if the file is missing or mid-write.
        }
    }

    // Island visibility is a compositor-level hard cut; this real value lets
    // the bar's contents fade while the window stays mapped for the exit.
    property real islandReveal: 1

    Behavior on islandReveal {
        NumberAnimation {
            duration: Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    // Layout switches cross-fade the previous panel into the new one and slide
    // the shared content into place, instead of snapping between layouts.
    property real pillsFade: bar.pills ? 1 : 0
    property real unifiedFade: bar.unified ? 1 : 0
    property real islandFade: bar.island ? 1 : 0

    Behavior on pillsFade {
        NumberAnimation {
            duration: Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }
    Behavior on unifiedFade {
        NumberAnimation {
            duration: Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }
    Behavior on islandFade {
        NumberAnimation {
            duration: Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: bar

        function onIslandRevealedChanged() {
            bar.islandReveal = bar.islandRevealed ? 1 : 0;
        }

        function onVisibleChanged() {
            if (!bar.visible) {
                bar.closePopup();
                actionPopupHost.hideAll();
            }
        }
    }

    Component.onCompleted: {
        bar.islandReveal = bar.islandRevealed ? 1 : 0;
        if (bar.shellRoot)
            bar.shellRoot.registerBar(bar);
    }

    Component.onDestruction: {
        if (bar.shellRoot)
            bar.shellRoot.unregisterBar(bar);
    }

    // Hide only the bar on the monitor whose active workspace is fullscreen.
    function fullscreenOnThisScreen() {
        const workspaces = Hyprland.workspaces.values;
        const monitor = screen ? Hyprland.monitorFor(screen) : null;

        for (let i = 0; i < workspaces.length; i++) {
            const workspace = workspaces[i];
            if (!workspace || !workspace.active || !workspace.hasFullscreen)
                continue;

            const wsMonitor = workspace.monitor;
            if (monitor && wsMonitor) {
                if (wsMonitor.id === monitor.id || wsMonitor.name === monitor.name)
                    return true;
                continue;
            }
            if (screen && wsMonitor && wsMonitor.name === screen.name)
                return true;
        }
        return false;
    }

    readonly property bool fullscreenHere: bar.fullscreenOnThisScreen()

    onFullscreenHereChanged: {
        if (!bar.fullscreenHere)
            return;
        bar.closePopup();
        if (TrayMenuState.current)
            TrayMenuState.current.hide();
    }

    // Global cursor position supplied by the shell root. The island layout
    // uses it to reveal itself only near its chosen screen edge.
    property int cursorX: -1
    property int cursorY: -1

    // Panel placement, mirrored from settings.json by Theme.
    readonly property string edge: Theme.barEdge
    readonly property bool vertical: Theme.barVertical
    readonly property bool island: Theme.barLayout === "island"
    readonly property bool wrap: Theme.barLayout === "unifiedWrap"
    readonly property bool cornersAttached: Theme.barLayout === "unifiedCorners"
        || bar.wrap
    readonly property bool unifiedRounded: Theme.barLayout === "unified"
    readonly property bool unified: bar.unifiedRounded || bar.cornersAttached
    readonly property bool pills: Theme.barLayout === "pills"
    readonly property bool bottom: edge === "bottom"

    // Bar position inside its monitor, used by the popup placement helpers.
    readonly property int screenOriginX: {
        const s = bar.screen;
        if (!s)
            return 0;
        if (bar.vertical)
            return bar.edge === "right" ? Math.round(s.width - bar.width) : 0;
        return bar.island ? Math.round((s.width - bar.width) / 2) : 0;
    }
    readonly property int screenOriginY: {
        const s = bar.screen;
        if (!s)
            return 0;
        if (!bar.vertical)
            return bar.bottom ? Math.round(s.height - bar.height) : 0;
        return bar.island ? Math.round((s.height - bar.height) / 2) : 0;
    }

    // Island is hidden until the pointer reaches its screen edge. The bar also
    // stays visible while the pointer is over it, an action popup is open, or
    // a tray menu launched from this bar is still showing. The tray menu is a
    // separate window, so without that last check moving into it would look
    // like leaving the island and fade the bar out.
    readonly property int edgeHotZone: 14
    readonly property bool cursorKnown: cursorX >= 0 && cursorY >= 0
    readonly property bool trayMenuOpenHere: TrayMenuState.current !== null
        && TrayMenuState.current.visible
        && TrayMenuState.current.ownerWindow === bar
    readonly property bool islandRevealed: !island
        || !cursorKnown
        || bar.cursorNearEdge()
        || bar.cursorInsideIsland()
        || activePopup !== null
        || trayMenuOpenHere

    // Shared spacing for the unified and island layouts.
    readonly property int pillPad: 7
    readonly property int contentInset: 12
    readonly property int sectionGap: 14

    // Vertical bars flank their stacked sections with short rulers.
    readonly property int rulerGap: 4
    readonly property int rulerLength: Math.max(10, Theme.panelHeight - 12)
    readonly property color rulerColor: Theme.pillBorder

    // Popups look up their buttons by element key, so moving an element does
    // not break its popup anchor.
    property var elementButtons: ({})
    readonly property var actionElementKeys: ["bluetooth", "network", "volume",
        "brightness", "battery", "power"]

    screen: modelData

    // Non-floating panels span the whole edge. An island only anchors to its
    // edge, which lets the compositor centre it on the other axis.
    anchors.top: edge === "top" || (vertical && !island)
    anchors.bottom: edge === "bottom" || (vertical && !island)
    anchors.left: edge === "left" || (!vertical && !island)
    anchors.right: edge === "right" || (!vertical && !island)

    // Reserved area keeps the original top gap while panelHeight controls the
    // visible bar thickness.
    implicitWidth: vertical
        ? Theme.barHeight
        : (island ? islandWidth : 0)
    implicitHeight: !vertical
        ? Theme.barHeight
        : (island ? islandHeight : 0)
    exclusiveZone: (bar.fullscreenHere || island) ? 0 : Theme.barHeight
    color: "transparent"
    visible: !bar.fullscreenHere
        && (!island || bar.islandRevealed || bar.islandReveal > 0.001)
    // OnDemand focus lets the QtWidgets tray menu receive keyboard input.
    focusable: true

    // The software dimmer uses this same layer but is created after the bar,
    // so it paints over the bar and the bar dims with the monitor.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-topbar-" + (screen ? screen.name : "x")

    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    readonly property var connectedNetwork: {
        if (!wifiDevice)
            return null;
        const list = wifiDevice.networks.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].connected)
                return list[i];
        }
        return null;
    }

    // NetworkManager can expose unmanaged virtual interfaces as wired; those
    // should not make the bar claim Ethernet is connected.
    readonly property var wiredDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];
            if (device.type !== DeviceType.Wired || device.nmManaged === false)
                continue;
            if (device.connected || (device.network && device.network.connected))
                return device;
        }
        return null;
    }

    readonly property string networkIcon: {
        if (connectedNetwork)
            return signalIcon(connectedNetwork.signalStrength);
        if (wiredDevice)
            return "󰈀";
        return (wifiDevice && Networking.wifiEnabled) ? "󰤯" : "󰤭";
    }

    readonly property string networkLabel: {
        if (connectedNetwork)
            return shorten(connectedNetwork.name, 20);
        if (wiredDevice)
            return "Ethernet";
        return "Offline";
    }

    readonly property var battery: UPower.displayDevice
    readonly property real batteryPercent: battery ? battery.percentage * 100 : 0

    // BlueZ connects asynchronously; these bindings pick the adapter up when
    // it appears rather than caching an empty list on first load.
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter && btAdapter.enabled

    readonly property var btConnectedDevices: {
        const all = Bluetooth.devices.values;
        const list = [];
        for (let i = 0; i < all.length; i++) {
            const device = all[i];
            if (device.connected
                && (!btAdapter || !device.adapter || device.adapter === btAdapter))
                list.push(device);
        }
        return list;
    }

    readonly property var btPrimaryDevice: btConnectedDevices.length > 0
        ? btConnectedDevices[0]
        : null

    readonly property string bluetoothLabel: btPrimaryDevice
        ? shorten(btPrimaryDevice.name || btPrimaryDevice.deviceName
                  || btPrimaryDevice.address, 14)
        : ""

    function bluetoothIcon() {
        if (btPrimaryDevice) {
            const icon = (btPrimaryDevice.icon || "").toLowerCase();
            return (icon.indexOf("audio") >= 0 || icon.indexOf("head") >= 0)
                ? "󰂰" : "󰂱";
        }
        if (btOn)
            return (btAdapter && btAdapter.discovering) ? "󰂴" : "󰂯";
        return "󰂲";
    }

    // Bind the audio nodes so their volume/mute state is available.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    function actionIconPoint(popup) {
        const key = bar.popupActionKey(popup);
        if (!key)
            return null;
        const item = bar.elementButton(key);
        if (!item)
            return null;
        const icon = item.activeIconItem && item.activeIconItem.visible
            ? item.activeIconItem : item;
        const p = item.mapToItem(bar.contentItem,
            item.iconVisualCenterX(), icon.height / 2);
        return Qt.point(p.x, p.y);
    }

    // Match the popup slide to the direction the bar's active-action indicator
    // travels. Vertical bars use the vertical axis instead.
    function actionSwitchMotion(from, to) {
        const a = bar.actionIconPoint(from);
        const b = bar.actionIconPoint(to);
        if (!a || !b)
            return { direction: 1, horizontal: !bar.vertical };

        const dx = b.x - a.x;
        const dy = b.y - a.y;
        if (bar.vertical || Math.abs(dy) > Math.abs(dx))
            return { direction: dy >= 0 ? 1 : -1, horizontal: false };
        return { direction: dx >= 0 ? 1 : -1, horizontal: true };
    }

    function togglePopup(popup) {
        if (activePopup === popup) {
            closePopup();
            return;
        }

        // Changing the focus-grab window list can briefly clear the grab. Keep
        // that from closing the popup we are switching to.
        switchingPopup = true;
        const fromKey = bar.popupActionKey(activePopup);
        const toKey = bar.popupActionKey(popup);

        if (fromKey && toKey) {
            const motion = bar.actionSwitchMotion(activePopup, popup);
            actionPopupHost.switchPopup(activePopup, popup,
                motion.direction, motion.horizontal);
            activePopup = popup;
        } else {
            if (activePopup)
                activePopup.close();
            activePopup = popup;
            popup.open();
        }
        popupKeySink.forceActiveFocus(Qt.PopupFocusReason);
        Qt.callLater(function () { bar.switchingPopup = false; });
    }

    function closePopup() {
        if (activePopup)
            activePopup.close();
        activePopup = null;
    }

    // Keyboard entry points used by the shell IPC handler.
    function cycleActionPopup() {
        const keys = actionPopupHost.cycleKeys;
        if (!keys.length)
            return;
        const currentKey = bar.popupActionKey(activePopup);
        const index = keys.indexOf(currentKey);
        const nextKey = keys[(index + 1) % keys.length];
        bar.togglePopup(actionPopupHost.contentFor(nextKey));
    }

    function toggleCalendar() {
        bar.togglePopup(calendarPopup);
    }

    function shorten(text, length) {
        if (!text)
            return "";
        return text.length > length ? text.substring(0, length - 1) + "…" : text;
    }

    // Settings store pill placement as 0..1 along the active edge axis. The
    // attached unified bar reaches the screen corners, so it uses the whole
    // edge instead of the detached bar's margin.
    function axisX(fraction, width, inset) {
        const pad = inset === undefined ? 0 : inset;
        const margin = (bar.cornersAttached ? 0 : Theme.sideMargin) + pad;
        const span = Math.max(0, bar.width - margin * 2 - width);
        const f = Math.min(1, Math.max(0, fraction));
        return margin + f * span;
    }

    function axisY(fraction, height, inset) {
        const pad = inset === undefined ? 0 : inset;
        const margin = (bar.cornersAttached ? 0 : Theme.sideMargin) + pad;
        const span = Math.max(0, bar.height - margin * 2 - height);
        const f = Math.min(1, Math.max(0, fraction));
        return margin + f * span;
    }

    // Elements can be reassigned to any section from the Appearance preview.
    // A section is only laid out when at least one of its elements is usable.
    function elementVisible(key) {
        switch (key) {
            case "appMenu": return Theme.showAppMenu;
            case "workspaces": return Theme.showWorkspaces;
            case "clock": return Theme.showClock;
            case "tray": return Theme.showTray && SystemTray.items.values.length > 0;
            case "bluetooth": return Theme.showBluetooth;
            // One status slot before Bluetooth. All active symbols are drawn
            // together: replay, recording, and the idle inhibitor.
            case "status":
                return RecordingState.active || ReplayState.active
                    || IdleState.active;
            case "network": return Theme.showNetwork;
            case "volume": return Theme.showVolume;
            case "brightness":
                return Theme.showBrightness && !!brightnessPopup
                    && brightnessPopup.available;
            case "battery":
                return Theme.showBattery && bar.battery !== null
                    && bar.battery.isPresent;
            case "power": return Theme.showPower;
        }
        return false;
    }

    function sectionElements(which) {
        const layout = Theme.elementLayout || ({});
        const list = layout[which] || [];
        const out = [];
        for (let i = 0; i < list.length; i++) {
            const key = list[i];
            if (bar.elementVisible(key) && out.indexOf(key) < 0)
                out.push(key);
        }
        return out;
    }

    function sectionVisible(which) {
        return bar.sectionElements(which).length > 0;
    }

    function sectionContent(which) {
        return which === "left" ? leftContent
            : (which === "center" ? centerContent : rightContent);
    }

    function sectionRulers(which) {
        const content = bar.sectionContent(which);
        if (!content)
            return [];

        const cx = content.x + content.implicitWidth / 2;
        const cy = content.y + content.implicitHeight / 2;

        // Horizontal bars used to get short ticks above and below each
        // section. They read as stray lines, so only vertical bars keep
        // rulers, where they flank the stack instead.
        if (!bar.vertical)
            return [];

        const half = bar.rulerLength / 2;
        return [
            Qt.rect(cx - content.implicitWidth / 2 - bar.rulerGap,
                cy - half, 1, bar.rulerLength),
            Qt.rect(cx + content.implicitWidth / 2 + bar.rulerGap - 1,
                cy - half, 1, bar.rulerLength)
        ];
    }

    function componentFor(key) {
        if (key === "appMenu") return appMenuComponent;
        if (key === "workspaces") return workspacesComponent;
        if (key === "clock") return bar.vertical ? clockVerticalComponent : clockComponent;
        if (key === "tray") return trayComponent;
        if (key === "bluetooth") return bluetoothComponent;
        if (key === "status") return statusComponent;
        if (key === "network") return networkComponent;
        if (key === "volume") return volumeComponent;
        if (key === "brightness") return brightnessComponent;
        if (key === "battery") return batteryComponent;
        if (key === "power") return powerComponent;
        return null;
    }

    function registerElement(key, item) {
        if (!item) return;
        const next = {};
        for (const k in elementButtons) next[k] = elementButtons[k];
        next[key] = item;
        elementButtons = next;
    }

    function unregisterElement(key, item) {
        if (elementButtons[key] !== item) return;
        const next = {};
        for (const k in elementButtons) {
            if (k !== key) next[k] = elementButtons[k];
        }
        elementButtons = next;
    }

    function elementButton(key) {
        return elementButtons[key] || null;
    }

    function powerHasLeading() {
        const layout = Theme.elementLayout || ({});
        const sections = ["left", "center", "right"];
        for (let s = 0; s < sections.length; s++) {
            const list = layout[sections[s]] || [];
            const idx = list.indexOf("power");
            if (idx <= 0) continue;
            for (let i = 0; i < idx; i++) {
                if (bar.elementVisible(list[i]))
                    return true;
            }
        }
        return false;
    }

    function statusHasTrailing() {
        const layout = Theme.elementLayout || ({});
        const sections = ["left", "center", "right"];
        for (let s = 0; s < sections.length; s++) {
            const list = layout[sections[s]] || [];
            const idx = list.indexOf("status");
            if (idx < 0) continue;
            for (let i = idx + 1; i < list.length; i++) {
                if (bar.elementVisible(list[i]))
                    return true;
            }
        }
        return false;
    }

    // Island sections keep their compact width but follow the order chosen by
    // the same left/center/right position controls used by the other layouts.

    function visibleSectionCount() {
        let count = 0;
        if (bar.sectionVisible("left")) count++;
        if (bar.sectionVisible("center")) count++;
        if (bar.sectionVisible("right")) count++;
        return count;
    }

    function sectionOrder() {
        const sections = [];
        if (bar.sectionVisible("left"))
            sections.push({ name: "left", fraction: Theme.pillLeft });
        if (bar.sectionVisible("center"))
            sections.push({ name: "center", fraction: Theme.pillCenter });
        if (bar.sectionVisible("right"))
            sections.push({ name: "right", fraction: Theme.pillRight });
        sections.sort((a, b) => a.fraction - b.fraction);
        return sections;
    }

    function sectionAxisSize(which) {
        if (which === "left")
            return bar.vertical ? leftContent.implicitHeight : leftContent.implicitWidth;
        if (which === "center")
            return bar.vertical ? centerContent.implicitHeight : centerContent.implicitWidth;
        return bar.vertical ? rightContent.implicitHeight : rightContent.implicitWidth;
    }

    function islandSectionStart(which) {
        const order = bar.sectionOrder();
        let start = 0;
        for (let i = 0; i < order.length; i++) {
            if (order[i].name === which)
                return start;
            start += bar.sectionAxisSize(order[i].name) + bar.sectionGap;
        }
        return start;
    }

    // hyprctl reports global coordinates, so compare against the screen's
    // global geometry rather than the bar window's local position.
    function cursorNearEdge() {
        if (!bar.cursorKnown || !screen)
            return false;
        const x0 = screen.x;
        const y0 = screen.y;
        const x1 = x0 + screen.width;
        const y1 = y0 + screen.height;
        if (bar.cursorX < x0 || bar.cursorX > x1
            || bar.cursorY < y0 || bar.cursorY > y1)
            return false;
        if (bar.edge === "top")
            return bar.cursorY - y0 <= bar.edgeHotZone;
        if (bar.edge === "bottom")
            return y1 - bar.cursorY <= bar.edgeHotZone;
        if (bar.edge === "left")
            return bar.cursorX - x0 <= bar.edgeHotZone;
        if (bar.edge === "right")
            return x1 - bar.cursorX <= bar.edgeHotZone;
        return false;
    }

    // The revealed island is centred on its edge by the compositor. Recreate
    // that geometry so the pointer can move from the edge onto the bar without
    // it disappearing.
    function islandBounds() {
        if (!screen)
            return { x: -1, y: -1, w: 0, h: 0 };
        const cross = Theme.barHeight;
        const active = bar.vertical ? islandHeight : islandWidth;
        return bar.vertical
            ? {
                x: bar.edge === "left" ? screen.x : screen.x + screen.width - cross,
                y: screen.y + (screen.height - active) / 2,
                w: cross,
                h: active
            }
            : {
                x: screen.x + (screen.width - active) / 2,
                y: bar.edge === "bottom" ? screen.y + screen.height - cross : screen.y,
                w: active,
                h: cross
            };
    }

    function cursorInsideIsland() {
        if (!bar.cursorKnown)
            return false;
        const b = bar.islandBounds();
        const pad = 6;
        return bar.cursorX >= b.x - pad && bar.cursorX <= b.x + b.w + pad
            && bar.cursorY >= b.y - pad && bar.cursorY <= b.y + b.h + pad;
    }

    // Popups attach to the inside of the bar, whichever edge it occupies.
    // align "center" centres on the target; "start" aligns the trailing edge.
    function popupX(item, popupWidth, align) {
        if (!item)
            return 0;
        if (bar.vertical)
            return bar.edge === "left" ? bar.width + 2 : -popupWidth - 2;
        const p = item.mapToItem(bar.contentItem, 0, 0);
        const x = align === "center"
            ? p.x + item.width / 2 - popupWidth / 2
            : p.x + item.width - popupWidth;
        return Math.round(Math.max(8, Math.min(x, bar.width - popupWidth - 8)));
    }

    function popupY(item, popupHeight, align) {
        if (!item)
            return 0;
        if (!bar.vertical)
            return bar.bottom ? -popupHeight - 2 : bar.height + 2;
        const p = item.mapToItem(bar.contentItem, 0, 0);
        const y = align === "center"
            ? p.y + item.height / 2 - popupHeight / 2
            : p.y + item.height - popupHeight;
        return Math.round(Math.max(8, Math.min(y, bar.height - popupHeight - 8)));
    }

    // All action popups share one anchor point: the middle of the visible
    // action icons. This stays fixed when switching between icons.
    function actionSectionCenter() {
        let min = Infinity;
        let max = -Infinity;

        for (let i = 0; i < bar.actionElementKeys.length; i++) {
            const item = bar.elementButton(bar.actionElementKeys[i]);
            if (!item || !item.visible)
                continue;

            const p = item.mapToItem(bar.contentItem, 0, 0);
            const start = bar.vertical ? p.y : p.x;
            const size = bar.vertical ? item.height : item.width;
            min = Math.min(min, start);
            max = Math.max(max, start + size);
        }

        if (max < min) {
            const p = rightContent.mapToItem(bar.contentItem, 0, 0);
            min = bar.vertical ? p.y : p.x;
            max = min + (bar.vertical ? rightContent.implicitHeight
                                      : rightContent.implicitWidth);
        }

        return (min + max) / 2;
    }

    function actionPopupX(popupWidth) {
        if (bar.vertical)
            return bar.edge === "left" ? bar.width + 2 : -popupWidth - 2;

        let x = bar.actionSectionCenter() - popupWidth / 2;
        const screenObj = bar.screen;
        if (screenObj) {
            const min = 8 - bar.screenOriginX;
            const max = screenObj.width - popupWidth - 8 - bar.screenOriginX;
            x = min <= max
                ? Math.max(min, Math.min(x, max))
                : (screenObj.width - popupWidth) / 2 - bar.screenOriginX;
        }
        return Math.round(x);
    }

    function actionPopupY(popupHeight) {
        if (!bar.vertical)
            return bar.bottom ? -popupHeight - 2 : bar.height + 2;

        let y = bar.actionSectionCenter() - popupHeight / 2;
        const screenObj = bar.screen;
        if (screenObj) {
            const min = 8 - bar.screenOriginY;
            const max = screenObj.height - popupHeight - 8 - bar.screenOriginY;
            y = min <= max
                ? Math.max(min, Math.min(y, max))
                : (screenObj.height - popupHeight) / 2 - bar.screenOriginY;
        }
        return Math.round(y);
    }

    function signalIcon(strength) {
        if (strength > 75) return "󰤨";
        if (strength > 50) return "󰤥";
        if (strength > 25) return "󰤢";
        if (strength > 0) return "󰤟";
        return "󰤯";
    }

    function volumeIcon() {
        const audio = volumePopup.sinkAudio;
        if (!audio)
            return "󰕾";
        if (audio.muted)
            return "󰖁";
        if (audio.volume <= 0.01)
            return "󰕿";
        if (audio.volume < 0.5)
            return "󰖀";
        return "󰕾";
    }

    function batteryIcon() {
        if (!battery || !battery.isPresent)
            return "󰂑";
        if (battery.state === UPowerDeviceState.Charging)
            return batteryPercent >= 95 ? "󰂅" : "󰂄";
        if (batteryPercent >= 90)
            return "󰁹";
        if (batteryPercent >= 70)
            return "󰂂";
        if (batteryPercent >= 50)
            return "󰁾";
        if (batteryPercent >= 30)
            return "󰁼";
        if (batteryPercent >= 15)
            return "󰁻";
        return "󰁺";
    }

    Connections {
        target: bar.activePopup
        ignoreUnknownSignals: true

        function onVisibleChanged() {
            if (bar.activePopup && !bar.activePopup.visible)
                bar.activePopup = null;
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: bar.activePopup !== null
        windows: bar.allPopupWindows
        onCleared: {
            if (!bar.switchingPopup)
                bar.closePopup();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ---- Content sections ---------------------------------------------
    // The same three sections are reused by all layouts. Elements are placed
    // into them from bar.elementLayout; only backgrounds and positions change.

    Flow {
        id: leftContent
        flow: bar.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: 2
        opacity: Math.max(bar.pillsFade, bar.unifiedFade, bar.islandFade)
            * (bar.island ? bar.islandReveal : 1)

        Behavior on x {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        x: {
            if (bar.island)
                return bar.vertical
                    ? islandBg.x + (islandBg.width - leftContent.implicitWidth) / 2
                    : islandBg.x + bar.pillPad + bar.islandSectionStart("left");
            if (bar.unified)
                return bar.vertical
                    ? bar.unifiedX + (bar.unifiedWidth - leftContent.implicitWidth) / 2
                    : bar.axisX(Theme.pillLeft, leftContent.implicitWidth, bar.contentInset);
            return leftPillBg.x + (leftPillBg.width - leftContent.implicitWidth) / 2;
        }
        y: {
            if (bar.island)
                return bar.vertical
                    ? islandBg.y + bar.pillPad + bar.islandSectionStart("left")
                    : islandBg.y + (islandBg.height - leftContent.implicitHeight) / 2;
            if (bar.unified)
                return bar.vertical
                    ? bar.axisY(Theme.pillLeft, leftContent.implicitHeight, bar.contentInset)
                    : bar.unifiedY + (bar.unifiedHeight - leftContent.implicitHeight) / 2;
            return leftPillBg.y + (leftPillBg.height - leftContent.implicitHeight) / 2;
        }

        Repeater {
            model: bar.sectionElements("left")
            delegate: Loader { sourceComponent: bar.componentFor(modelData) }
        }
    }

    Flow {
        id: centerContent
        flow: bar.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: 2
        opacity: Math.max(bar.pillsFade, bar.unifiedFade, bar.islandFade)
            * (bar.island ? bar.islandReveal : 1)

        Behavior on x {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        x: {
            if (bar.island)
                return bar.vertical
                    ? islandBg.x + (islandBg.width - centerContent.implicitWidth) / 2
                    : islandBg.x + bar.pillPad + bar.islandSectionStart("center");
            if (bar.unified)
                return bar.vertical
                    ? bar.unifiedX + (bar.unifiedWidth - centerContent.implicitWidth) / 2
                    : bar.axisX(Theme.pillCenter, centerContent.implicitWidth, bar.contentInset);
            return centerPillBg.x + (centerPillBg.width - centerContent.implicitWidth) / 2;
        }
        y: {
            if (bar.island)
                return bar.vertical
                    ? islandBg.y + bar.pillPad + bar.islandSectionStart("center")
                    : islandBg.y + (islandBg.height - centerContent.implicitHeight) / 2;
            if (bar.unified)
                return bar.vertical
                    ? bar.axisY(Theme.pillCenter, centerContent.implicitHeight, bar.contentInset)
                    : bar.unifiedY + (bar.unifiedHeight - centerContent.implicitHeight) / 2;
            return centerPillBg.y + (centerPillBg.height - centerContent.implicitHeight) / 2;
        }

        Repeater {
            model: bar.sectionElements("center")
            delegate: Loader { sourceComponent: bar.componentFor(modelData) }
        }
    }

    Flow {
        id: rightContent
        flow: bar.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: 2
        opacity: Math.max(bar.pillsFade, bar.unifiedFade, bar.islandFade)
            * (bar.island ? bar.islandReveal : 1)

        Behavior on x {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        x: {
            if (bar.island)
                return bar.vertical
                    ? islandBg.x + (islandBg.width - rightContent.implicitWidth) / 2
                    : islandBg.x + bar.pillPad + bar.islandSectionStart("right");
            if (bar.unified)
                return bar.vertical
                    ? bar.unifiedX + (bar.unifiedWidth - rightContent.implicitWidth) / 2
                    : bar.axisX(Theme.pillRight, rightContent.implicitWidth, bar.contentInset);
            return rightPillBg.x + (rightPillBg.width - rightContent.implicitWidth) / 2;
        }
        y: {
            if (bar.island)
                return bar.vertical
                    ? islandBg.y + bar.pillPad + bar.islandSectionStart("right")
                    : islandBg.y + (islandBg.height - rightContent.implicitHeight) / 2;
            if (bar.unified)
                return bar.vertical
                    ? bar.axisY(Theme.pillRight, rightContent.implicitHeight, bar.contentInset)
                    : bar.unifiedY + (bar.unifiedHeight - rightContent.implicitHeight) / 2;
            return rightPillBg.y + (rightPillBg.height - rightContent.implicitHeight) / 2;
        }

        Repeater {
            model: bar.sectionElements("right")
            delegate: Loader { sourceComponent: bar.componentFor(modelData) }
        }
    }

    // ---- Element components --------------------------------------------

    Component {
        id: appMenuComponent

        BarButton {
            id: appMenu
            vertical: bar.vertical
            icon: "󰀻"

            Component.onCompleted: bar.registerElement("appMenu", appMenu)
            Component.onDestruction: bar.unregisterElement("appMenu", appMenu)

            onClicked: Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/quickshell/launcher/toggle.sh"
            ])
        }
    }

    Component {
        id: workspacesComponent

        Workspaces {
            id: ws
            vertical: bar.vertical
            screen: bar.screen

            Component.onCompleted: bar.registerElement("workspaces", ws)
            Component.onDestruction: bar.unregisterElement("workspaces", ws)
        }
    }

    readonly property string clockBadgeText: bar.notificationHistoryCount > 0
        ? (bar.notificationHistoryCount > 9
            ? "9+" : String(bar.notificationHistoryCount))
        : ""

    FileView {
        id: notificationHistoryFile
        path: bar.notificationHistoryPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) bar.syncNotificationHistoryCount()
    }

    Timer {
        interval: 800
        repeat: true
        triggeredOnStart: true
        running: true
        onTriggered: bar.syncNotificationHistoryCount()
    }

    Component {
        id: clockComponent

        BarButton {
            id: clockBtn
            anchors.centerIn: parent
            vertical: bar.vertical
            active: calendarPopup.visible

            icon: ""
            badgeText: bar.clockBadgeText
            label: bar.vertical
                ? ""
                : Qt.formatDateTime(clock.date, "ddd dd MMM") + "   "
                    + Qt.formatDateTime(clock.date, "HH:mm")

            Component.onCompleted: bar.registerElement("clock", clockBtn)
            Component.onDestruction: bar.unregisterElement("clock", clockBtn)

            onClicked: bar.togglePopup(calendarPopup)
        }
    }

    // Vertical bars have no room for the horizontal date/time label, and the
    // old invisible icon left the clock blank. Show the date above a small
    // rule and the time as two stacked lines instead.
    Component {
        id: clockVerticalComponent

        Item {
            id: clockBtn
            anchors.centerIn: parent
            width: 26
            height: 74
            implicitWidth: 26
            implicitHeight: 74

            readonly property Item activeIconItem: clockStack
            function iconVisualCenterX() {
                return clockStack.x + clockStack.width / 2;
            }
            function iconVisualWidth() {
                return Math.min(18, Math.max(10, clockStack.width - 2));
            }

            Rectangle {
                anchors.fill: parent
                radius: 7
                color: calendarPopup.visible
                    ? Theme.active
                    : (mouse.containsMouse ? Theme.hover : "transparent")

                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            }

            Column {
                id: clockStack
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dd")
                    font.family: Theme.mono
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: calendarPopup.visible ? Theme.accentSoft : Theme.text
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "MMM").toLowerCase()
                    font.family: Theme.mono
                    font.pixelSize: 9
                    color: calendarPopup.visible ? Theme.accentSoft : Theme.subtext
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 16
                    height: 1
                    color: calendarPopup.visible ? Theme.accent : Theme.border
                }

                Column {
                    id: timeStack

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH")
                        font.family: Theme.mono
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: calendarPopup.visible ? Theme.accentSoft : Theme.text
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "mm")
                        font.family: Theme.mono
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: calendarPopup.visible ? Theme.accentSoft : Theme.text
                    }
                }
            }

            Rectangle {
                visible: bar.clockBadgeText !== ""
                anchors.bottom: parent.top
                anchors.bottomMargin: 7
                anchors.horizontalCenter: parent.horizontalCenter
                z: 2
                width: 16
                height: 16
                radius: width / 2
                color: Theme.surfaceAlt
                border.width: 1
                border.color: calendarPopup.visible ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: bar.clockBadgeText
                    font.family: Theme.mono
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: calendarPopup.visible ? Theme.accentSoft : Theme.text
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.togglePopup(calendarPopup)
            }

            Component.onCompleted: bar.registerElement("clock", clockBtn)
            Component.onDestruction: bar.unregisterElement("clock", clockBtn)
        }
    }

    Component {
        id: trayComponent

        Flow {
            id: trayGroup
            flow: bar.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: 0

            Component.onCompleted: bar.registerElement("tray", trayGroup)
            Component.onDestruction: bar.unregisterElement("tray", trayGroup)

            Repeater {
                model: SystemTray.items

                delegate: TrayIcon {
                    ownerBar: bar
                    item: modelData
                }
            }

            // Flow pins raw children to the group's leading edge, so give the
            // separator a full-height slot and centre the visible line inside
            // it to line up with the 26px buttons beside it.
            Item {
                width: bar.vertical ? 26 : 1
                height: bar.vertical ? 1 : 26

                Rectangle {
                    anchors.centerIn: parent
                    width: bar.vertical ? 16 : 1
                    height: bar.vertical ? 1 : 16
                    color: Theme.border
                }
            }
        }
    }

    Component {
        id: bluetoothComponent

        BarButton {
            id: bluetoothBtn
            vertical: bar.vertical
            active: bluetoothPopup.visible
            muted: !bar.btOn && bar.btPrimaryDevice === null

            icon: bar.bluetoothIcon()
            label: bar.bluetoothLabel

            Component.onCompleted: bar.registerElement("bluetooth", bluetoothBtn)
            Component.onDestruction: bar.unregisterElement("bluetooth", bluetoothBtn)

            onClicked: bar.togglePopup(bluetoothPopup)
        }
    }

    Component {
        id: statusComponent

        StatusIndicators {
            vertical: bar.vertical
            showSeparator: bar.statusHasTrailing()
        }
    }

    Component {
        id: networkComponent

        BarButton {
            id: networkBtn
            vertical: bar.vertical
            active: networkPopup.visible

            icon: bar.networkIcon
            label: bar.networkLabel

            Component.onCompleted: bar.registerElement("network", networkBtn)
            Component.onDestruction: bar.unregisterElement("network", networkBtn)

            onClicked: bar.togglePopup(networkPopup)
        }
    }

    Component {
        id: volumeComponent

        BarButton {
            id: volumeBtn
            vertical: bar.vertical
            active: volumePopup.visible

            icon: bar.volumeIcon()
            label: volumePopup.sinkAudio
                ? Math.round(volumePopup.sinkAudio.volume * 100) + "%"
                : "--"

            Component.onCompleted: bar.registerElement("volume", volumeBtn)
            Component.onDestruction: bar.unregisterElement("volume", volumeBtn)

            onClicked: bar.togglePopup(volumePopup)
        }
    }

    Component {
        id: brightnessComponent

        BarButton {
            id: brightnessBtn
            vertical: bar.vertical
            active: brightnessPopup.visible

            icon: "󰃠"
            label: brightnessPopup.percent + "%"

            Component.onCompleted: bar.registerElement("brightness", brightnessBtn)
            Component.onDestruction: bar.unregisterElement("brightness", brightnessBtn)

            onClicked: bar.togglePopup(brightnessPopup)
        }
    }

    Component {
        id: batteryComponent

        BarButton {
            id: batteryBtn
            vertical: bar.vertical
            active: batteryPopup.visible

            icon: bar.batteryIcon()
            label: bar.battery && bar.battery.isPresent
                ? Math.round(bar.batteryPercent) + "%"
                : ""

            Component.onCompleted: bar.registerElement("battery", batteryBtn)
            Component.onDestruction: bar.unregisterElement("battery", batteryBtn)

            onClicked: bar.togglePopup(batteryPopup)
        }
    }

    Component {
        id: powerComponent

        Flow {
            id: powerGroup
            flow: bar.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: 0

            Item {
                visible: bar.powerHasLeading()
                width: bar.vertical ? 26 : 1
                height: bar.vertical ? 1 : 26

                Rectangle {
                    anchors.centerIn: parent
                    width: bar.vertical ? 16 : 1
                    height: bar.vertical ? 1 : 16
                    color: Theme.border
                }
            }

            BarButton {
                id: powerBtn
                vertical: bar.vertical
                active: powerPopup.visible

                icon: "⏻"

                Component.onCompleted: bar.registerElement("power", powerBtn)
                Component.onDestruction: bar.unregisterElement("power", powerBtn)

                onClicked: bar.togglePopup(powerPopup)
            }
        }
    }

    // ---- Layout geometry ----------------------------------------------

    // Island size is the sum of its sections plus padding and gaps.
    readonly property int islandWidth: bar.visibleSectionCount() === 0 ? 1
        : (leftContent.implicitWidth + centerContent.implicitWidth
            + rightContent.implicitWidth + pillPad * 2
            + Math.max(0, bar.visibleSectionCount() - 1) * sectionGap)
    readonly property int islandHeight: bar.visibleSectionCount() === 0 ? 1
        : (leftContent.implicitHeight + centerContent.implicitHeight
            + rightContent.implicitHeight + pillPad * 2
            + Math.max(0, bar.visibleSectionCount() - 1) * sectionGap)

    // Unified panel target geometry. The background animates toward these and
    // the sections are positioned from them, so a layout swap moves both in
    // step instead of snapping the panel while the content slides.
    // Attached modes still follow panelHeight; they only remove the side
    // margins and rounding, not the thickness control. Detached modes use one
    // outer gap on both sides so the window gap can match the bottom.
    readonly property real unifiedX: bar.cornersAttached
        ? (bar.vertical && bar.edge === "right" ? bar.width - Theme.panelHeight : 0)
        : (bar.vertical
            ? (bar.edge === "right"
                ? bar.width - Theme.barOuterInset - Theme.panelHeight
                : Theme.barOuterInset)
            : Theme.sideMargin)
    readonly property real unifiedY: bar.cornersAttached
        ? (!bar.vertical && bar.bottom ? bar.height - Theme.panelHeight : 0)
        : (bar.vertical
            ? Theme.sideMargin
            : (bar.bottom
                ? bar.height - Theme.barOuterInset - Theme.panelHeight
                : Theme.barOuterInset))
    readonly property real unifiedWidth: bar.cornersAttached
        ? (bar.vertical ? Theme.panelHeight : bar.width)
        : (bar.vertical ? Theme.panelHeight : bar.width - Theme.sideMargin * 2)
    readonly property real unifiedHeight: bar.cornersAttached
        ? (bar.vertical ? bar.height : Theme.panelHeight)
        : (bar.vertical ? bar.height - Theme.sideMargin * 2 : Theme.panelHeight)
    readonly property real unifiedRadius: bar.cornersAttached ? 0 : Theme.pillRadius
    readonly property int unifiedBorderWidth: bar.cornersAttached ? 0 : 1

    // Backgrounds are declared before the sections so content draws on top.
    Rectangle {
        id: leftPillBg
        visible: (bar.pills || bar.pillsFade > 0.001)
            && bar.sectionVisible("left")
        opacity: bar.pillsFade
        width: bar.vertical
            ? Theme.panelHeight
            : leftContent.implicitWidth + bar.pillPad * 2
        height: bar.vertical
            ? leftContent.implicitHeight + bar.pillPad * 2
            : Theme.panelHeight
        x: bar.vertical
            ? (bar.edge === "left"
                ? Theme.barOuterInset
                : bar.width - Theme.barOuterInset - width)
            : bar.axisX(Theme.pillLeft, width)
        y: bar.vertical
            ? bar.axisY(Theme.pillLeft, height)
            : (bar.bottom
                ? bar.height - Theme.barOuterInset - height
                : Theme.barOuterInset)
        radius: Theme.pillRadius
        color: Theme.panelFill(Theme.pillFill, "topbar", 0.78)
        border.width: 1
        border.color: Theme.pillBorder
        z: -1
    }

    Rectangle {
        id: centerPillBg
        visible: (bar.pills || bar.pillsFade > 0.001)
            && bar.sectionVisible("center")
        opacity: bar.pillsFade
        width: bar.vertical
            ? Theme.panelHeight
            : centerContent.implicitWidth + bar.pillPad * 2
        height: bar.vertical
            ? centerContent.implicitHeight + bar.pillPad * 2
            : Theme.panelHeight
        x: bar.vertical
            ? (bar.edge === "left"
                ? Theme.barOuterInset
                : bar.width - Theme.barOuterInset - width)
            : bar.axisX(Theme.pillCenter, width)
        y: bar.vertical
            ? bar.axisY(Theme.pillCenter, height)
            : (bar.bottom
                ? bar.height - Theme.barOuterInset - height
                : Theme.barOuterInset)
        radius: Theme.pillRadius
        color: Theme.panelFill(Theme.pillFill, "topbar", 0.78)
        border.width: 1
        border.color: Theme.pillBorder
        z: -1
    }

    Rectangle {
        id: rightPillBg
        visible: (bar.pills || bar.pillsFade > 0.001)
            && bar.sectionVisible("right")
        opacity: bar.pillsFade
        width: bar.vertical
            ? Theme.panelHeight
            : rightContent.implicitWidth + bar.pillPad * 2
        height: bar.vertical
            ? rightContent.implicitHeight + bar.pillPad * 2
            : Theme.panelHeight
        x: bar.vertical
            ? (bar.edge === "left"
                ? Theme.barOuterInset
                : bar.width - Theme.barOuterInset - width)
            : bar.axisX(Theme.pillRight, width)
        y: bar.vertical
            ? bar.axisY(Theme.pillRight, height)
            : (bar.bottom
                ? bar.height - Theme.barOuterInset - height
                : Theme.barOuterInset)
        radius: Theme.pillRadius
        color: Theme.panelFill(Theme.pillFill, "topbar", 0.78)
        border.width: 1
        border.color: Theme.pillBorder
        z: -1
    }

    Rectangle {
        id: unifiedBg
        visible: (bar.unified || bar.unifiedFade > 0.001)
            && bar.visibleSectionCount() > 0
        opacity: bar.unifiedFade
        x: bar.unifiedX
        y: bar.unifiedY
        width: bar.unifiedWidth
        height: bar.unifiedHeight
        radius: bar.unifiedRadius
        color: Theme.panelFill(Theme.pillFill, "topbar", 0.78)
        border.width: bar.unifiedBorderWidth
        border.color: Theme.pillBorder
        z: -1

        // Morph between the rounded detached panel and the flush attached one.
        Behavior on x {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        Behavior on border.width {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: islandBg
        visible: (bar.island || bar.islandFade > 0.001)
            && bar.visibleSectionCount() > 0
        opacity: bar.islandFade * bar.islandReveal
        x: (bar.width - width) / 2
        y: (bar.height - height) / 2
        width: bar.vertical ? Theme.panelHeight : bar.islandWidth
        height: bar.vertical ? bar.islandHeight : Theme.panelHeight
        radius: Theme.pillRadius
        color: Theme.panelFill(Theme.pillFill, "topbar", 0.78)
        border.width: 1
        border.color: Theme.pillBorder
        z: -1
    }

    Repeater {
        model: ["left", "center", "right"]

        Item {
            property bool sectionIsVisible:
                (bar.unified || bar.unifiedFade > 0.001
                    || bar.island || bar.islandFade > 0.001)
                && bar.sectionVisible(modelData)
            readonly property var rects: sectionIsVisible
                ? bar.sectionRulers(modelData)
                : []

            opacity: Math.max(bar.unifiedFade, bar.islandFade)
                * (bar.island ? bar.islandReveal : 1)

            Repeater {
                model: parent.rects

                Rectangle {
                    x: modelData.x
                    y: modelData.y
                    width: modelData.width
                    height: modelData.height
                    color: bar.rulerColor
                }
            }
        }
    }

    ActionPopupHost {
        id: actionPopupHost
        bar: bar
    }

    CalendarPopup {
        id: calendarPopup
        bar: bar
        target: bar.elementButton("clock")
    }

    // ---- Active action indicator -------------------------------------

    property rect actionIndicatorRect: Qt.rect(0, 0, 0, 0)
    property bool actionIndicatorVisible: false
    property bool actionIndicatorAnimate: false
    property real actionIndicatorLeftNudge: 1

    function popupActionKey(popup) {
        if (!popup || popup === calendarPopup)
            return "";
        return popup.actionKey || "";
    }

    function actionIndicatorGeometry() {
        const key = bar.popupActionKey(bar.activePopup);
        if (!key)
            return null;

        const item = bar.elementButton(key);
        if (!item)
            return null;

        const icon = item.activeIconItem && item.activeIconItem.visible
            ? item.activeIconItem : item;
        const iconOrigin = icon.mapToItem(bar.contentItem, 0, 0);
        const iconCenter = item.mapToItem(bar.contentItem,
            item.iconVisualCenterX(), 0);
        const barWidth = item.iconVisualWidth();

        return Qt.rect(
            iconCenter.x - barWidth / 2 - bar.actionIndicatorLeftNudge,
            iconOrigin.y + icon.height - 2,
            barWidth,
            3
        );
    }

    function syncActionIndicator() {
        const rect = bar.actionIndicatorGeometry();
        if (!rect) {
            bar.actionIndicatorVisible = false;
            bar.actionIndicatorAnimate = false;
            return;
        }

        if (!bar.actionIndicatorVisible) {
            // A freshly opened popup snaps to its icon; only direct icon-to-
            // icon switches animate the bar across the action section.
            bar.actionIndicatorAnimate = false;
            bar.actionIndicatorRect = rect;
            bar.actionIndicatorVisible = true;
            Qt.callLater(function () {
                if (bar.actionIndicatorVisible)
                    bar.actionIndicatorAnimate = true;
            });
        } else {
            bar.actionIndicatorRect = rect;
        }
    }

    Connections {
        target: bar
        ignoreUnknownSignals: true

        function onActivePopupChanged() { bar.syncActionIndicator(); }
        function onElementButtonsChanged() { bar.syncActionIndicator(); }
    }

    Rectangle {
        x: bar.actionIndicatorRect.x
        y: bar.actionIndicatorRect.y
        width: bar.actionIndicatorRect.width
        height: bar.actionIndicatorRect.height
        radius: 2
        color: Theme.accent
        opacity: bar.actionIndicatorVisible ? 1 : 0
        z: 2

        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

        Behavior on x {
            enabled: bar.actionIndicatorAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            enabled: bar.actionIndicatorAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            enabled: bar.actionIndicatorAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: bar.actionIndicatorAnimate
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
    }
}
