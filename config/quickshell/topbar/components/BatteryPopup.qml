import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland

PopupWindow {
    id: popup


    property var bar
    property Item target

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

    implicitWidth: 400
    // Fixed so every action popup shares one consistent size.
    implicitHeight: 320
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: bar ? bar.actionPopupX(width) : 0
    anchor.rect.y: bar ? bar.actionPopupY(height) : 0

    function open() { surface.open(); }
    function close() { surface.close(); }

    onVisibleChanged: if (!visible) surface.reset()

    PopupSurface {
        id: surface
        window: popup
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

                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 6
                        color: selected ? Theme.active : Theme.surfaceAlt
                        border.width: 1
                        border.color: selected ? Theme.accent : Theme.border

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
