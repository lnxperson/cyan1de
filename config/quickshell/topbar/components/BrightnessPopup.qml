import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup


    property var bar
    property Item target

    readonly property int percent: Brightness.percent
    readonly property bool available: Brightness.available
    readonly property var displays: Brightness.displays

    implicitWidth: 400
    // Fixed so every action popup shares one consistent size.
    implicitHeight: 320
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: bar ? bar.actionPopupX(width) : 0
    anchor.rect.y: bar ? bar.actionPopupY(height) : 0

    function open() {
        surface.open();
        Brightness.refresh();
    }
    function close() { surface.close(); }

    onVisibleChanged: {
        if (visible)
            Brightness.refresh();
        else
            surface.reset();
    }

    PopupSurface {
        id: surface
        window: popup
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

        Text {
            Layout.fillWidth: true
            visible: popup.displays.count === 0
            text: "No controllable displays found"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.dim
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: popup.displays.count > 0

            Repeater {
                model: Brightness.displays

                SliderRow {
                    Layout.fillWidth: true
                    icon: model.mode === "software" ? "󰗼" : "󰃠"
                    label: (Brightness.displays.count === 1 ? "Display" : model.label)
                        + (model.mode === "software" ? " (software)" : "")
                    accent: Theme.yellow
                    showMute: false
                    value: model.percent / 100

                    onMoved: function (value) {
                        Brightness.previewPercent(model.uid, value * 100);
                    }
                    onCommitted: function (value) {
                        Brightness.applyPercent(model.uid, value * 100);
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: popup.displays.count > 0
            spacing: 8

            Repeater {
                model: [25, 50, 75, 100]

                PillButton {
                    required property int modelData
                    Layout.fillWidth: true
                    label: modelData + "%"
                    onClicked: Brightness.applyAll(modelData)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󱩌"
                font.family: Theme.font
                font.pixelSize: Theme.iconSize + 1
                color: NightLight.enabled ? Theme.yellow : Theme.dim
            }

            Text {
                text: "Night light"
                font.family: Theme.mono
                font.pixelSize: 12
                color: Theme.subtext
            }

            Item { Layout.fillWidth: true }

            Text {
                text: !NightLight.available
                    ? "Unavailable"
                    : (NightLight.enabled
                        ? NightLight.intensity + "% · " + NightLight.temperature + " K"
                        : "Off")
                font.family: Theme.mono
                font.pixelSize: 11
                color: !NightLight.available
                    ? Theme.red
                    : (NightLight.enabled ? Theme.text : Theme.dim)
            }

            ToggleSwitch {
                checked: NightLight.enabled
                onToggled: function (checked) { NightLight.setEnabled(checked); }
            }
        }

        SliderRow {
            Layout.fillWidth: true
            visible: NightLight.enabled
            icon: "󰃚"
            label: "Intensity"
            accent: Theme.yellow
            showMute: false
            value: NightLight.intensity / 100

            onMoved: function (value) {
                NightLight.previewIntensity(value * 100);
            }
            onCommitted: function (value) {
                NightLight.setIntensity(value * 100);
            }
        }
    }
}
