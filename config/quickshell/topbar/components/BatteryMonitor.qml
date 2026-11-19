import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Sends one low-battery notification per discharge cycle. Polling lives in a
// plain component because singleton Timers do not tick on Quickshell 0.3.2.
QtObject {
    id: root

    property bool warned: false

    readonly property var battery: {
        const list = UPower.devices.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].isLaptopBattery)
                return list[i];
        }
        return UPower.displayDevice;
    }

    property Timer pollTimer: Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.check()
    }

    Component.onCompleted: root.check()

    function check() {
        if (!Theme.lowBatteryEnabled) {
            root.warned = false;
            return;
        }

        const dev = root.battery;
        if (!dev)
            return;

        const state = dev.state;
        if (state === UPowerDeviceState.Charging
            || state === UPowerDeviceState.FullyCharged
            || state === UPowerDeviceState.PendingCharge) {
            root.warned = false;
            return;
        }
        if (state !== UPowerDeviceState.Discharging
            && state !== UPowerDeviceState.PendingDischarge)
            return;

        const pct = Math.round((Number(dev.percentage) || 0) * 100);
        if (pct > Theme.lowBatteryThreshold) {
            root.warned = false;
            return;
        }
        if (root.warned)
            return;

        root.warned = true;
        Quickshell.execDetached([
            "notify-send", "-u", "critical", "-a", "Battery",
            "-i", "battery-low", "Low battery",
            "Battery is at " + pct + "%. Plug in your charger soon."
        ]);
    }
}
