import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland

Item {
    id: popup

    readonly property string actionKey: "battery"
    property var bar
    property var host
    property Item target
    property alias popupSurface: surface
    visible: false

    readonly property var battery: UPower.displayDevice
    readonly property var device: {
        const list = UPower.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].isLaptopBattery)
                return list[i];
        }
        return battery;
    }
    readonly property real percent: battery ? battery.percentage * 100 : 0

    readonly property string stateLabel: {
        if (!battery)
            return "Unknown";
        switch (battery.state) {
        case UPowerDeviceState.Charging:
            return "Charging";
        case UPowerDeviceState.Discharging:
            return "Discharging";
        case UPowerDeviceState.Empty:
            return "Empty";
        case UPowerDeviceState.FullyCharged:
            return "Fully charged";
        case UPowerDeviceState.PendingCharge:
            return "Charging soon";
        case UPowerDeviceState.PendingDischarge:
            return "On battery soon";
        default:
            return "Unknown";
        }
    }

    function formatDuration(seconds) {
        if (!seconds || seconds <= 0 || !isFinite(seconds))
            return "—";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round((seconds % 3600) / 60);
        if (hours > 0)
            return hours + "h " + minutes + "m";
        return minutes + "m";
    }

    function prepare() {}
    function cleanup() {}
    function open() { if (popup.host) popup.host.openPopup(popup); }
    function close() { if (popup.host) popup.host.closePopup(popup); }

    PopupSurface {
        id: surface
        window: popup.host
        controller: popup.host
        owner: popup
        manageWindow: false
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: {
                    if (!popup.battery)
                        return "󰂑";
                    if (popup.battery.state === UPowerDeviceState.Charging)
                        return "󰂄";
                    if (popup.percent < 20)
                        return "󰁺";
                    if (popup.percent < 50)
                        return "󰁼";
                    if (popup.percent < 80)
                        return "󰁾";
                    return "󰁹";
                }
                font.family: Theme.font
                font.pixelSize: 20
                color: popup.battery && popup.percent < 20
                    ? Theme.red
                    : Theme.green
            }

            ColumnLayout {
                spacing: 0

                Text {
                    text: "Battery"
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.text
                }

                Text {
                    text: popup.stateLabel
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: popup.battery && popup.battery.state === UPowerDeviceState.Charging
                        ? Theme.green
                        : Theme.subtext
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: popup.battery ? Math.round(popup.percent) + "%" : "—"
                font.family: Theme.mono
                font.pixelSize: 22
                font.weight: Font.Light
                color: Theme.text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Theme.surfaceAlt
            border.width: 1
            border.color: Theme.border

            Rectangle {
                width: parent.width * (popup.battery ? Math.max(0, Math.min(1, popup.percent / 100)) : 0)
                height: parent.height
                radius: parent.radius
                color: popup.battery && popup.percent < 20
                    ? Theme.red
                    : (popup.battery && popup.battery.state === UPowerDeviceState.Charging
                        ? Theme.green
                        : Theme.accent)

                Behavior on width { NumberAnimation { duration: 250 } }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 16

            Text {
                text: "Time remaining"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            Text {
                Layout.alignment: Qt.AlignRight
                text: popup.battery
                    ? (popup.battery.state === UPowerDeviceState.Charging
                        ? popup.formatDuration(popup.battery.timeToFull)
                        : popup.formatDuration(popup.battery.timeToEmpty))
                    : "—"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.text
            }

            Text {
                text: "Health"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            Text {
                Layout.alignment: Qt.AlignRight
                text: popup.battery && popup.device && popup.device.healthSupported
                    ? Math.round(popup.device.healthPercentage) + "%"
                    : "—"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.text
            }

            Text {
                text: "Model"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            Text {
                Layout.alignment: Qt.AlignRight
                Layout.maximumWidth: 170
                text: popup.device ? (popup.device.model || "—") : "—"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.text
                elide: Text.ElideRight
            }
        }

        // Only show profile controls when power-profiles-daemon actually answers.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
            visible: PowerProfileControl.available === true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: PowerProfileControl.available === true

            Text {
                text: "POWER PROFILE"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.subtext
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: PowerProfileControl.profileOptions

                    delegate: Rectangle {
                        required property var modelData

                        readonly property bool selected: PowerProfileControl.profile === modelData
                        property bool keyboardFocused: false

                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: Theme.controlRadius
                        color: selected ? Theme.active : Theme.surfaceAlt
                        border.width: activeFocus || keyboardFocused ? 2 : 1
                        border.color: activeFocus || keyboardFocused
                            ? Theme.accentSoft
                            : (selected ? Theme.accent : Theme.border)
                        activeFocusOnTab: true

                        Text {
                            anchors.centerIn: parent
                            text: PowerProfileControl.labelFor(modelData)
                            font.family: Theme.mono
                            font.pixelSize: 9
                            color: selected ? Theme.accentSoft : Theme.subtext
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfileControl.setProfile(modelData)
                        }

                        function keyboardActivate() { PowerProfileControl.setProfile(modelData); }

                        Keys.onReturnPressed: {
                            event.accepted = true;
                            PowerProfileControl.setProfile(modelData);
                        }

                        Keys.onSpacePressed: {
                            event.accepted = true;
                            PowerProfileControl.setProfile(modelData);
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: PowerProfileControl.statusHint
                font.family: Theme.mono
                font.pixelSize: 9
                color: Theme.dim
                wrapMode: Text.WordWrap
            }
        }
    }
}
