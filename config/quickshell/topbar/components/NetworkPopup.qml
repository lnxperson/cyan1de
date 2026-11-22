import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Networking
import Quickshell.Wayland

Item {
    id: popup

    readonly property string actionKey: "network"
    property var bar
    property var host
    property Item target
    property alias popupSurface: surface
    property var selectedNetwork: null
    visible: false

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

    function prepare() {
        if (popup.wifiDevice)
            popup.wifiDevice.scannerEnabled = true;
    }

    function cleanup() {
        popup.selectedNetwork = null;
        passwordField.text = "";
        if (popup.wifiDevice)
            popup.wifiDevice.scannerEnabled = false;
    }

    function open() { if (popup.host) popup.host.openPopup(popup); }
    function close() { if (popup.host) popup.host.closePopup(popup); }

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
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: 0

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
                    property bool keyboardFocused: false

                    width: listView.width
                    height: 50
                    radius: 8
                    color: rowMouse.containsMouse || networkRow.activeFocus
                        || networkRow.keyboardFocused ? Theme.hover : "transparent"
                    border.width: networkRow.activeFocus || networkRow.keyboardFocused ? 1 : 0
                    border.color: Theme.accentSoft
                    activeFocusOnTab: true

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

                    function activate() {
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

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: networkRow.activate()
                    }

                    function keyboardActivate() { networkRow.activate(); }

                    Keys.onReturnPressed: {
                        event.accepted = true;
                        networkRow.activate();
                    }

                    Keys.onSpacePressed: {
                        event.accepted = true;
                        networkRow.activate();
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

                    onActiveFocusChanged: popup.popupSurface.keyboardPassthrough = passwordField.activeFocus
                    onAccepted: popup.connectSelected()
                    Keys.onEscapePressed: {
                        event.accepted = true;
                        popup.selectedNetwork = null;
                    }
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

    PopupDimOverlay {
        anchors.fill: surface
        radius: surface.radius
        reveal: surface.reveal
        active: popup.selectedNetwork !== null && surface.reveal > 0
        visible: popup.selectedNetwork !== null
    }
}
