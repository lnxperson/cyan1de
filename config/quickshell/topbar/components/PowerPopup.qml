import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup


    property var bar
    property Item target
    property string pending: ""
    property var pendingCommand: null

    implicitWidth: 400
    // Fixed so every action popup shares one consistent size.
    implicitHeight: 320
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: bar ? bar.actionPopupX(width) : 0
    anchor.rect.y: bar ? bar.actionPopupY(height) : 0

    function open() { surface.open(); }
    function close() {
        surface.close();
        pending = "";
        pendingCommand = null;
    }

    function runNow(command) {
        Quickshell.execDetached(command);
        close();
    }

    function request(name, command) {
        if (pending === name) {
            pending = "";
            pendingCommand = null;
            runNow(command);
        } else {
            pending = name;
            pendingCommand = command;
            confirmTimer.restart();
        }
    }

    onVisibleChanged: {
        if (!visible) {
            surface.reset();
            pending = "";
            pendingCommand = null;
        }
    }

    Timer {
        id: confirmTimer
        interval: 3000
        onTriggered: {
            popup.pending = "";
            popup.pendingCommand = null;
        }
    }

    PopupSurface {
        id: surface
        window: popup
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "⏻"
                font.family: Theme.font
                font.pixelSize: 18
                color: Theme.red
            }

            Text {
                text: "Power"
                font.family: Theme.mono
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: popup.pending !== ""
                text: "Click again to confirm"
                font.family: Theme.mono
                font.pixelSize: 9
                color: Theme.yellow
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
            columnSpacing: 8

            ActionButton {
                Layout.fillWidth: true
                icon: "󰌾"
                label: "Lock"
                accent: Theme.accent
                onClicked: popup.runNow([Quickshell.env("HOME") + "/.config/quickshell/lockscreen/lock.sh"])
            }

            ActionButton {
                Layout.fillWidth: true
                icon: "󰒲"
                label: "Suspend"
                accent: Theme.mauve
                onClicked: popup.runNow(["systemctl", "suspend"])
            }

            ActionButton {
                Layout.fillWidth: true
                icon: "󰍃"
                label: popup.pending === "logout" ? "Confirm?" : "Log out"
                accent: popup.pending === "logout" ? Theme.red : Theme.yellow
                danger: popup.pending === "logout"
                onClicked: popup.request("logout", ["hyprctl", "dispatch", "exit"])
            }

            ActionButton {
                Layout.fillWidth: true
                icon: "󰜉"
                label: popup.pending === "reboot" ? "Confirm?" : "Reboot"
                accent: popup.pending === "reboot" ? Theme.red : Theme.yellow
                danger: popup.pending === "reboot"
                onClicked: popup.request("reboot", ["systemctl", "reboot"])
            }

            ActionButton {
                Layout.fillWidth: true
                Layout.columnSpan: 2
                icon: "󰐥"
                label: popup.pending === "shutdown" ? "Confirm?" : "Shut down"
                accent: Theme.red
                danger: popup.pending === "shutdown"
                onClicked: popup.request("shutdown", ["systemctl", "poweroff"])
            }
        }
    }
}
