import QtQuick
import QtQuick.Layouts
import Quickshell
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
    property var activePopup: null

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"
    focusable: false

    // Same layer as the software dimmer so the bar dims with the monitor.
    WlrLayershell.layer: WlrLayer.Top
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

    function togglePopup(popup) {
        if (activePopup === popup) {
            closePopup();
            return;
        }
        if (activePopup)
            activePopup.close();
        activePopup = popup;
        popup.open();
    }

    function closePopup() {
        if (activePopup)
            activePopup.close();
        activePopup = null;
    }

    function shorten(text, length) {
        if (!text)
            return "";
        return text.length > length ? text.substring(0, length - 1) + "…" : text;
    }

    // Settings stores pill placement as 0..1 across the available bar width.
    function pillX(fraction, pillWidth) {
        const margin = Theme.sideMargin;
        const span = Math.max(0, bar.width - margin * 2 - pillWidth);
        const f = Math.min(1, Math.max(0, fraction));
        return margin + f * span;
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
        windows: {
            const list = [bar];
            if (bar.activePopup)
                list.push(bar.activePopup);
            return list;
        }
        onCleared: bar.closePopup()
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Three floating pills
    Rectangle {
        id: leftPill

        x: bar.pillX(Theme.pillLeft, implicitWidth)
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: leftRow.implicitWidth + 14
        implicitHeight: Theme.pillHeight
        radius: Theme.pillRadius
        color: Theme.pillFill
        border.width: 1
        border.color: Theme.pillBorder

        Row {
            id: leftRow
            anchors.centerIn: parent
            spacing: 3

            Workspaces {
                anchors.verticalCenter: parent.verticalCenter
                screen: bar.screen
            }
        }
    }

    Rectangle {
        id: centerPill

        x: bar.pillX(Theme.pillCenter, implicitWidth)
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: clockButton.implicitWidth + 14
        implicitHeight: Theme.pillHeight
        radius: Theme.pillRadius
        color: Theme.pillFill
        border.width: 1
        border.color: Theme.pillBorder

        BarButton {
            id: clockButton
            anchors.centerIn: parent
            active: calendarPopup.visible

            icon: "󰥔"
            label: Qt.formatDateTime(clock.date, "ddd dd MMM") + "   " + Qt.formatDateTime(clock.date, "HH:mm")

            onClicked: bar.togglePopup(calendarPopup)
        }
    }

    Rectangle {
        id: rightPill

        x: bar.pillX(Theme.pillRight, implicitWidth)
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: rightRow.implicitWidth + 14
        implicitHeight: Theme.pillHeight
        radius: Theme.pillRadius
        color: Theme.pillFill
        border.width: 1
        border.color: Theme.pillBorder

        Row {
            id: rightRow
            anchors.centerIn: parent
            spacing: 2

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                visible: SystemTray.items.values.length > 0

                Repeater {
                    model: SystemTray.items

                    TrayIcon {
                        bar: bar
                        item: modelData
                    }
                }
            }

            Rectangle {
                visible: SystemTray.items.values.length > 0
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.border
            }

            BarButton {
                id: bluetoothButton
                anchors.verticalCenter: parent.verticalCenter
                active: bluetoothPopup.visible
                muted: !bar.btOn && bar.btPrimaryDevice === null

                icon: bar.bluetoothIcon()
                label: bar.bluetoothLabel

                onClicked: bar.togglePopup(bluetoothPopup)
            }

            BarButton {
                id: networkButton
                anchors.verticalCenter: parent.verticalCenter
                active: networkPopup.visible

                icon: bar.networkIcon
                label: bar.networkLabel

                onClicked: bar.togglePopup(networkPopup)
            }

            BarButton {
                id: volumeButton
                anchors.verticalCenter: parent.verticalCenter
                active: volumePopup.visible

                icon: bar.volumeIcon()
                label: volumePopup.sinkAudio
                    ? Math.round(volumePopup.sinkAudio.volume * 100) + "%"
                    : "--"

                onClicked: bar.togglePopup(volumePopup)
            }

            BarButton {
                id: brightnessButton
                anchors.verticalCenter: parent.verticalCenter
                visible: brightnessPopup.available
                active: brightnessPopup.visible

                icon: "󰃠"
                label: brightnessPopup.percent + "%"

                onClicked: bar.togglePopup(brightnessPopup)
            }

            BarButton {
                id: batteryButton
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.battery !== null && bar.battery.isPresent
                active: batteryPopup.visible

                icon: bar.batteryIcon()
                label: bar.battery && bar.battery.isPresent
                    ? Math.round(bar.batteryPercent) + "%"
                    : ""

                onClicked: bar.togglePopup(batteryPopup)
            }

            Rectangle {
                width: 1
                height: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.border
            }

            BarButton {
                id: powerButton
                anchors.verticalCenter: parent.verticalCenter
                active: powerPopup.visible

                icon: "⏻"

                onClicked: bar.togglePopup(powerPopup)
            }
        }
    }

    VolumePopup {
        id: volumePopup
        bar: bar
        target: volumeButton
    }

    BrightnessPopup {
        id: brightnessPopup
        bar: bar
        target: brightnessButton
    }

    BluetoothPopup {
        id: bluetoothPopup
        bar: bar
        target: bluetoothButton
    }

    NetworkPopup {
        id: networkPopup
        bar: bar
        target: networkButton
    }

    BatteryPopup {
        id: batteryPopup
        bar: bar
        target: batteryButton
    }

    CalendarPopup {
        id: calendarPopup
        bar: bar
        target: clockButton
    }

    PowerPopup {
        id: powerPopup
        bar: bar
        target: powerButton
    }
}
