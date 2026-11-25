import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

Item {
    id: popup

    readonly property string actionKey: "bluetooth"
    property var bar
    property var host
    property Item target
    property alias popupSurface: surface
    visible: false

    // The Bluetooth singleton connects to BlueZ asynchronously, so all of
    // these bindings are deliberately reactive rather than cached on load.
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: Bluetooth.adapters.values.length > 0
    readonly property bool btOn: btAdapter && btAdapter.enabled
    readonly property bool btScanning: btAdapter && btAdapter.discovering

    property bool wantScan: false
    property int scanAttempts: 0

    readonly property var devices: {
        const all = Bluetooth.devices.values;
        const list = [];
        for (let i = 0; i < all.length; i++) {
            const device = all[i];
            if (popup.btAdapter && device.adapter && device.adapter !== popup.btAdapter)
                continue;
            list.push(device);
        }
        list.sort(function (a, b) {
            const rank = function (device) {
                return device.connected ? 0 : (device.paired ? 1 : 2);
            };
            return (rank(a) - rank(b))
                || String(a.name || a.deviceName || a.address).localeCompare(
                   String(b.name || b.deviceName || b.address));
        });
        return list;
    }

    readonly property var connectedDevices: {
        const list = [];
        for (let i = 0; i < popup.devices.length; i++) {
            if (popup.devices[i].connected)
                list.push(popup.devices[i]);
        }
        return list;
    }

    readonly property string statusText: {
        if (!popup.hasAdapter)
            return "No Bluetooth adapter found";
        if (!popup.btOn)
            return "Bluetooth is off";
        if (popup.connectedDevices.length > 0) {
            const first = popup.connectedDevices[0];
            const name = first.name || first.deviceName || first.address;
            return popup.connectedDevices.length > 1
                ? "Connected to " + name + " +" + (popup.connectedDevices.length - 1)
                : "Connected to " + name;
        }
        return popup.btScanning ? "Scanning for devices…" : "On — no devices connected";
    }

    function prepare() { popup.requestScan(); }

    function cleanup() {
        popup.wantScan = false;
        if (popup.btAdapter && popup.btScanning)
            popup.btAdapter.discovering = false;
    }

    function open() { if (popup.host) popup.host.openPopup(popup); }
    function close() { if (popup.host) popup.host.closePopup(popup); }

    function requestScan() {
        if (!popup.btOn)
            return;
        popup.scanAttempts = 0;
        popup.wantScan = true;
    }

    function setPower(value) {
        if (!popup.btAdapter)
            return;
        popup.btAdapter.enabled = value;
        if (value)
            popup.requestScan();
        else {
            popup.wantScan = false;
            popup.btAdapter.discovering = false;
        }
    }

    function toggleScan() {
        if (!popup.btAdapter || !popup.btOn)
            return;
        const next = !popup.btScanning;
        popup.wantScan = next;
        popup.scanAttempts = 0;
        popup.btAdapter.discovering = next;
    }

    function deviceIcon(device) {
        const icon = (device.icon || "").toLowerCase();
        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0
            || icon.indexOf("audio") >= 0)
            return "󰋋";
        if (icon.indexOf("mouse") >= 0)
            return "󰄀";
        if (icon.indexOf("keyboard") >= 0)
            return "󰌌";
        if (icon.indexOf("phone") >= 0)
            return "󰅑";
        return device.connected ? "󰂱" : "󰂯";
    }

    function deviceStatus(device) {
        if (device.pairing)
            return "Pairing…";
        if (device.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (device.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (device.connected) {
            const battery = device.batteryAvailable
                ? " · " + Math.round(device.battery * 100) + "%"
                : "";
            return "Connected" + battery;
        }
        if (device.paired)
            return "Paired · click to connect";
        return "Click to pair";
    }

    function activateDevice(device) {
        if (device.connected)
            device.disconnect();
        else if (device.paired)
            device.connect();
        else
            device.pair();
    }

    // Enabling the adapter is asynchronous, so retry discovery until BlueZ
    // reports the adapter as actually discovering.
    Timer {
        interval: 500
        repeat: true
        running: popup.visible && popup.wantScan && popup.btOn && !popup.btScanning
        onTriggered: {
            if (!popup.btAdapter)
                return;
            popup.btAdapter.discovering = true;
            if (popup.btScanning || ++popup.scanAttempts > 12)
                popup.wantScan = false;
        }
    }

    PopupSurface {
        id: surface
        window: popup.host
        controller: popup.host
        owner: popup
        manageWindow: false
        anchors.fill: parent

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: popup.btOn ? "󰂯" : "󰂲"
                font.family: Theme.font
                font.pixelSize: 18
                color: popup.btOn ? Theme.accent : Theme.dim
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Bluetooth"
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    Layout.fillWidth: true
                    text: popup.statusText
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.subtext
                    elide: Text.ElideRight
                }
            }

            ToggleSwitch {
                checked: popup.btOn
                onToggled: function (value) { popup.setPower(value); }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Device list
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: 0

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: 2
                model: popup.devices
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: deviceRow

                    required property var modelData
                    readonly property var device: modelData
                    property bool keyboardFocused: false

                    width: listView.width
                    height: 50
                    radius: Theme.controlRadius
                    color: rowMouse.containsMouse || deviceRow.activeFocus
                        || deviceRow.keyboardFocused ? Theme.hover : "transparent"
                    border.width: deviceRow.activeFocus || deviceRow.keyboardFocused ? 1 : 0
                    border.color: Theme.accentSoft
                    activeFocusOnTab: true

                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: deviceRow.device.paired ? 38 : 10
                        spacing: 10

                        Text {
                            text: popup.deviceIcon(deviceRow.device)
                            font.family: Theme.font
                            font.pixelSize: 17
                            color: deviceRow.device.connected ? Theme.accent : Theme.subtext
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: deviceRow.device.name || deviceRow.device.deviceName
                                      || deviceRow.device.address
                                font.family: Theme.mono
                                font.pixelSize: 12
                                color: deviceRow.device.connected ? Theme.accentSoft : Theme.text
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: popup.deviceStatus(deviceRow.device)
                                font.family: Theme.mono
                                font.pixelSize: 9
                                color: deviceRow.device.connected ? Theme.green : Theme.subtext
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            visible: deviceRow.device.connected
                            text: "󰄬"
                            font.family: Theme.font
                            font.pixelSize: 15
                            color: Theme.green
                        }

                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popup.activateDevice(deviceRow.device)
                    }

                    function keyboardActivate() { popup.activateDevice(deviceRow.device); }

                    Keys.onReturnPressed: {
                        event.accepted = true;
                        popup.activateDevice(deviceRow.device);
                    }

                    Keys.onSpacePressed: {
                        event.accepted = true;
                        popup.activateDevice(deviceRow.device);
                    }

                    // Sibling placed after the row MouseArea so its own
                    // MouseArea receives forget clicks first.
                    Rectangle {
                        visible: deviceRow.device.paired
                        z: 2
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Theme.controlRadius
                        property bool keyboardFocused: false
                        color: forgetMouse.containsMouse || activeFocus
                            || keyboardFocused ? "#2a181b" : "transparent"
                        border.width: activeFocus || keyboardFocused ? 1 : 0
                        border.color: Theme.red
                        activeFocusOnTab: visible

                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            font.family: Theme.font
                            font.pixelSize: 13
                            color: forgetMouse.containsMouse ? Theme.red : Theme.dim
                        }

                        MouseArea {
                            id: forgetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: deviceRow.device.forget()
                        }

                        function keyboardActivate() { deviceRow.device.forget(); }

                        Keys.onReturnPressed: {
                            event.accepted = true;
                            deviceRow.device.forget();
                        }

                        Keys.onSpacePressed: {
                            event.accepted = true;
                            deviceRow.device.forget();
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: !popup.hasAdapter
                    ? "No Bluetooth adapter found"
                    : (!popup.btOn
                        ? "Turn on Bluetooth to see devices"
                        : (popup.btScanning
                            ? "Scanning for devices…"
                            : "No devices found — press Scan to search"))
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.dim
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Footer
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PillButton {
                icon: "󰂴"
                label: popup.btScanning ? "Stop" : "Scan"
                onClicked: popup.toggleScan()
            }

            Item { Layout.fillWidth: true }

            PillButton {
                icon: "󰒓"
                label: "Advanced"
                onClicked: {
                    Quickshell.execDetached(["alacritty", "--command", "bluetoothctl"]);
                    popup.close();
                }
            }
        }
    }
}
