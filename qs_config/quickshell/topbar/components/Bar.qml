import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
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

    readonly property var battery: UPower.displayDevice
    readonly property real batteryPercent: battery ? battery.percentage * 100 : 0

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

        anchors.left: parent.left
        anchors.leftMargin: Theme.sideMargin
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

        anchors.horizontalCenter: parent.horizontalCenter
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

        anchors.right: parent.right
        anchors.rightMargin: Theme.sideMargin
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
                id: networkButton
                anchors.verticalCenter: parent.verticalCenter
                active: networkPopup.visible

                icon: bar.connectedNetwork
                    ? bar.signalIcon(bar.connectedNetwork.signalStrength)
                    : (bar.wifiDevice && Networking.wifiEnabled ? "󰤯" : "󰤭")
                label: bar.connectedNetwork ? bar.shorten(bar.connectedNetwork.name, 20) : "Offline"

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
