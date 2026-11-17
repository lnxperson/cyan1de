import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PopupWindow {
    id: popup

    property var bar
    property Item target
    property int percent: 50
    property bool available: true

    implicitWidth: 340
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

    function open() {
        visible = true;
        readBrightness.running = true;
    }
    function close() { visible = false; }

    function applyPercent(value) {
        const v = Math.round(Math.max(0, Math.min(100, value)));
        percent = v;
        Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", v + "%"]);
    }

    onVisibleChanged: if (visible) readBrightness.running = true

    Process {
        id: readBrightness
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null | head -n1 | cut -d, -f4 | tr -d '%'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseInt(text.trim(), 10);
                if (!isNaN(value))
                    popup.percent = value;
            }
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: popup.visible
        onTriggered: readBrightness.running = true
    }

    PopupSurface {
        id: surface
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰃠"
                font.family: Theme.font
                font.pixelSize: 18
                color: Theme.yellow
            }

            Text {
                text: "Brightness"
                font.family: Theme.mono
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Item { Layout.fillWidth: true }

            Text {
                text: popup.available ? popup.percent + "%" : "Unavailable"
                font.family: Theme.mono
                font.pixelSize: 12
                color: popup.available ? Theme.text : Theme.red
            }
        }

        SliderRow {
            Layout.fillWidth: true
            icon: "󰃞"
            label: "Display"
            accent: Theme.yellow
            showMute: false
            value: popup.percent / 100

            onMoved: function (value) { popup.percent = Math.round(value * 100); }
            onCommitted: function (value) { popup.applyPercent(value * 100); }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [25, 50, 75, 100]

                PillButton {
                    required property int modelData
                    Layout.fillWidth: true
                    label: modelData + "%"
                    onClicked: popup.applyPercent(modelData)
                }
            }
        }
    }
}
