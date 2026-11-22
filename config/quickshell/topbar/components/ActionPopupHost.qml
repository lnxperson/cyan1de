import QtQuick
import Quickshell

// One persistent popup surface for the six action-section popups. Keeping the
// window mapped and the content items alive removes the compositor map/unmap
// and QML construction that made switching between actions feel like a cold
// start.
PopupWindow {
    id: host

    property var bar

    implicitWidth: 400
    implicitHeight: 320
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: bar ? bar.actionPopupX(width) : 0
    anchor.rect.y: bar ? bar.actionPopupY(height) : 0

    property string activeKey: ""
    property var activeContent: null

    readonly property var contentKeys: [
        "bluetooth", "network", "volume", "brightness", "battery", "power"
    ]

    // SUPER + A follows the bar's visual action order. Battery is skipped on
    // machines without a detected battery.
    readonly property var cycleKeys: {
        const keys = ["bluetooth", "network", "volume", "brightness", "power"];
        const battery = host.bar ? host.bar.battery : null;
        if (battery && battery.isPresent) {
            keys.splice(4, 0, "battery");
        }
        return keys;
    }

    readonly property var volumePopup: volumeLoader.item
    readonly property var brightnessPopup: brightnessLoader.item
    readonly property var bluetoothPopup: bluetoothLoader.item
    readonly property var networkPopup: networkLoader.item
    readonly property var batteryPopup: batteryLoader.item
    readonly property var powerPopup: powerLoader.item

    Loader {
        id: volumeLoader
        source: "VolumePopup.qml"
        active: true
        anchors.fill: parent
        onLoaded: item.host = host
    }

    Loader {
        id: brightnessLoader
        source: "BrightnessPopup.qml"
        active: true
        anchors.fill: parent
        onLoaded: item.host = host
    }

    Loader {
        id: bluetoothLoader
        source: "BluetoothPopup.qml"
        active: true
        anchors.fill: parent
        onLoaded: item.host = host
    }

    Loader {
        id: networkLoader
        source: "NetworkPopup.qml"
        active: true
        anchors.fill: parent
        onLoaded: item.host = host
    }

    Loader {
        id: batteryLoader
        source: "BatteryPopup.qml"
        active: true
        anchors.fill: parent
        onLoaded: item.host = host
    }

    Loader {
        id: powerLoader
        source: "PowerPopup.qml"
        active: true
        anchors.fill: parent
        onLoaded: item.host = host
    }

    function contentFor(key) {
        if (key === "volume") return volumeLoader.item;
        if (key === "brightness") return brightnessLoader.item;
        if (key === "bluetooth") return bluetoothLoader.item;
        if (key === "network") return networkLoader.item;
        if (key === "battery") return batteryLoader.item;
        if (key === "power") return powerLoader.item;
        return null;
    }

    function visibleContentCount() {
        let count = 0;
        for (let i = 0; i < host.contentKeys.length; i++) {
            const content = host.contentFor(host.contentKeys[i]);
            if (content && content.visible)
                count++;
        }
        return count;
    }

    function ensureVisible() {
        host.visible = true;
    }

    function prepareContent(content) {
        if (content && typeof content.prepare === "function")
            content.prepare();
    }

    function cleanupContent(content) {
        if (content && typeof content.cleanup === "function")
            content.cleanup();
    }

    function openPopup(content) {
        if (!content || content === host.activeContent)
            return;
        if (host.activeContent && host.activeContent !== content) {
            host.cleanupContent(host.activeContent);
            host.activeContent.popupSurface.close();
        }

        host.activeKey = content.actionKey || "";
        host.activeContent = content;
        content.visible = true;
        host.prepareContent(content);
        content.popupSurface.open();
    }

    function switchPopup(from, to, direction, horizontal) {
        if (!from || !to || from === to)
            return;

        host.cleanupContent(from);
        host.activeKey = to.actionKey || "";
        host.activeContent = to;
        to.visible = true;
        host.prepareContent(to);

        from.popupSurface.slideOut(direction, horizontal);
        to.popupSurface.slideIn(direction, horizontal);
    }

    function closePopup(content) {
        if (!content)
            return;
        host.cleanupContent(content);
        content.popupSurface.close();
        if (host.activeContent === content) {
            host.activeContent = null;
            host.activeKey = "";
        }
    }

    function surfaceHidden(surface) {
        const owner = surface.owner;
        if (owner)
            owner.visible = false;
        if (owner && owner === host.activeContent) {
            host.activeContent = null;
            host.activeKey = "";
        }
        if (host.visibleContentCount() === 0)
            host.visible = false;
    }

    // A hidden bar cannot map popups, and its surface timers can stop ticking.
    // Clear the shared host explicitly so a later bar reveal cannot show stale
    // popup content that never got its normal hide callback.
    function hideAll() {
        for (let i = 0; i < host.contentKeys.length; i++) {
            const content = host.contentFor(host.contentKeys[i]);
            if (!content)
                continue;
            host.cleanupContent(content);
            content.popupSurface.reset();
            content.visible = false;
        }
        host.activeContent = null;
        host.activeKey = "";
        host.visible = false;
    }
}
