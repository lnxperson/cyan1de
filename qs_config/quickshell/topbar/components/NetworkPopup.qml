import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Networking

PopupWindow {
    id: popup

    property var bar
    property Item target
    property var selectedNetwork: null

    readonly property var wifiDevice: {
        const devices = Networking.devices.values;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    readonly property var networks: {
        if (!wifiDevice)
            return [];
        const list = wifiDevice.networks.values.slice();
        list.sort(function (a, b) {
            return (b.connected - a.connected) || (b.signalStrength - a.signalStrength);
        });
        return list;
    }

    readonly property var connectedNetwork: {
        for (let i = 0; i < networks.length; i++) {
            if (networks[i].connected)
                return networks[i];
        }
        return null;
    }

    implicitWidth: 380
    implicitHeight: surface.contentHeight
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: {
        if (!bar || !target)
            return 0;
        const p = target.mapToItem(bar.contentItem, 0, 0);
        return Math.round(Math.max(8, Math.min(p.x + target.width - width, bar.width - width - 8)));
    }
    anchor.rect.y: bar ? bar.height + 2 : 0

    function open() { visible = true; }
    function close() { visible = false; }

    function signalIcon(strength) {
        if (strength > 75) return "󰤨";
        if (strength > 50) return "󰤥";
        if (strength > 25) return "󰤢";
        if (strength > 0) return "󰤟";
        return "󰤯";
    }

    function connectSelected() {
        if (!selectedNetwork)
            return;

        if (selectedNetwork.known || selectedNetwork.security === WifiSecurityType.Open)
            selectedNetwork.connect();
        else
            selectedNetwork.connectWithPsk(passwordField.text);

        selectedNetwork = null;
        passwordField.text = "";
    }

    function rescan() {
        if (!wifiDevice)
            return;
        wifiDevice.scannerEnabled = false;
        Qt.callLater(function () { wifiDevice.scannerEnabled = true; });
    }

    onVisibleChanged: {
        if (visible) {
            if (wifiDevice)
                wifiDevice.scannerEnabled = true;
        } else {
            selectedNetwork = null;
            passwordField.text = "";
            if (wifiDevice)
                wifiDevice.scannerEnabled = false;
        }
    }

    PopupSurface {
        id: surface
        anchors.fill: parent

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰤨"
                font.family: Theme.font
                font.pixelSize: 18
                color: Networking.wifiEnabled ? Theme.accent : Theme.dim
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Wi-Fi"
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    text: Networking.wifiEnabled
                        ? (popup.connectedNetwork ? "Connected to " + popup.connectedNetwork.name : "Not connected")
                        : "Wi-Fi is off"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.subtext
                    elide: Text.ElideRight
                    Layout.maximumWidth: 210
                }
            }

            Item { Layout.fillWidth: true }

            ToggleSwitch {
                checked: Networking.wifiEnabled
                onToggled: function (value) { Networking.wifiEnabled = value; }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Network list
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(52, Math.min(288, popup.networks.length * 52))

            ListView {
                id: listView
                anchors.fill: parent
                clip: true
                spacing: 2
                model: popup.networks
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: networkRow

                    required property var modelData
                    readonly property var net: modelData

                    width: listView.width
                    height: 50
                    radius: 8
                    color: rowMouse.containsMouse ? Theme.hover : "transparent"

                    Behavior on color { ColorAnimation { duration: 100 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: popup.signalIcon(networkRow.net.signalStrength)
                            font.family: Theme.font
                            font.pixelSize: 17
                            color: networkRow.net.connected ? Theme.accent : Theme.subtext
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: networkRow.net.name
                                font.family: Theme.mono
                                font.pixelSize: 12
                                color: networkRow.net.connected ? Theme.accentSoft : Theme.text
                                elide: Text.ElideRight
                            }

                            Text {
                                text: {
                                    if (networkRow.net.state === ConnectionState.Connecting)
                                        return "Connecting…";
                                    if (networkRow.net.connected)
                                        return "Connected";
                                    if (networkRow.net.known)
                                        return "Saved";
                                    return networkRow.net.security === WifiSecurityType.Open ? "Open network" : "Secured";
                                }
                                font.family: Theme.mono
                                font.pixelSize: 9
                                color: networkRow.net.connected ? Theme.green : Theme.subtext
                            }
                        }

                        Text {
                            visible: networkRow.net.security !== WifiSecurityType.Open
                            text: "󰌾"
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.dim
                        }

                        Text {
                            visible: networkRow.net.connected
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
                        onClicked: {
                            if (networkRow.net.connected)
                                return;
                            if (networkRow.net.known || networkRow.net.security === WifiSecurityType.Open) {
                                networkRow.net.connect();
                            } else {
                                popup.selectedNetwork = networkRow.net;
                                passwordField.text = "";
                                Qt.callLater(function () { passwordField.forceActiveFocus(); });
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: listView.count === 0
                text: !Networking.wifiEnabled
                    ? "Turn on Wi-Fi to see networks"
                    : (popup.wifiDevice ? "Scanning for networks…" : "No Wi-Fi device found")
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
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
                icon: "󰑐"
                label: "Rescan"
                onClicked: popup.rescan()
            }

            Item { Layout.fillWidth: true }

            PillButton {
                visible: popup.connectedNetwork !== null
                icon: "󰅖"
                label: "Disconnect"
                danger: true
                onClicked: {
                    if (popup.connectedNetwork)
                        popup.connectedNetwork.disconnect();
                }
            }

            PillButton {
                icon: "󰒓"
                label: "Settings"
                onClicked: {
                    Quickshell.execDetached(["alacritty", "--command", "nmtui"]);
                    popup.close();
                }
            }
        }
    }

    // Password overlay
    Rectangle {
        anchors.fill: parent
        radius: surface.radius
            color: Theme.surface
            visible: popup.selectedNetwork !== null
            z: 20

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰌾"
                        font.family: Theme.font
                        font.pixelSize: 18
                        color: Theme.accent
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: "Connect to"
                            font.family: Theme.mono
                            font.pixelSize: 9
                            color: Theme.subtext
                        }

                        Text {
                            text: popup.selectedNetwork ? popup.selectedNetwork.name : ""
                            font.family: Theme.mono
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                            Layout.maximumWidth: 300
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    placeholderText: "Password"
                    placeholderTextColor: Theme.dim
                    echoMode: TextInput.Password
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 12
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    leftPadding: 12
                    rightPadding: 12

                    background: Rectangle {
                        radius: 8
                        color: Theme.surfaceAlt
                        border.width: 1
                        border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                    }

                    onAccepted: popup.connectSelected()
                    Keys.onEscapePressed: popup.selectedNetwork = null
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    PillButton {
                        label: "Cancel"
                        onClicked: popup.selectedNetwork = null
                    }

                    PillButton {
                        icon: "󰄬"
                        label: "Connect"
                        onClicked: popup.connectSelected()
                    }
                }
            }
        }
}
