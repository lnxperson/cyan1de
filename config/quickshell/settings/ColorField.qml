import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Colour setting: label + button that opens an HSV colour picker popup.
// The picker edits saturation/value on a square, hue on a slider, and also
// accepts a typed hex value. Changes are emitted live as `edited(value)`.
RowLayout {
    id: root

    property string label: ""
    property string value: "#ffffff"
    property var app: null

    signal edited(string value)

    // Internal HSV state while the picker is open. Kept separate from `value`
    // so dragging hue at zero saturation doesn't reset the hue.
    property real hsvHue: 0
    property real hsvSat: 1
    property real hsvVal: 1

    spacing: 10

    function clamp01(v) {
        return Math.max(0, Math.min(1, v));
    }

    function hexToHsv(hex) {
        const m = /^#([0-9a-fA-F]{6})$/.exec(String(hex || "").trim());
        if (!m)
            return null;
        const n = parseInt(m[1], 16);
        const c = Qt.rgba(((n >> 16) & 255) / 255,
                          ((n >> 8) & 255) / 255,
                          (n & 255) / 255, 1);
        return { h: c.hsvHue * 360, s: c.hsvSaturation, v: c.hsvValue };
    }

    function hsvToHex(h, s, v) {
        const c = Qt.hsva(clamp01(h / 360), clamp01(s), clamp01(v), 1);
        const to = x => ("0" + Math.round(x * 255).toString(16)).slice(-2);
        return "#" + to(c.r) + to(c.g) + to(c.b);
    }

    function syncFromValue() {
        const hsv = hexToHsv(root.value);
        if (!hsv)
            return;
        root.hsvHue = hsv.h;
        root.hsvSat = hsv.s;
        root.hsvVal = hsv.v;
    }

    function emitCurrent() {
        const hex = hsvToHex(root.hsvHue, root.hsvSat, root.hsvVal);
        if (hexField && !hexField.activeFocus)
            hexField.text = hex;
        if (hex !== root.value)
            root.edited(hex);
    }

    function openPicker() {
        root.syncFromValue();
        if (hexField)
            hexField.text = root.value;
        if (root.app)
            root.app.captureOwner = picker;
        picker.open();
    }

    Component.onCompleted: root.syncFromValue()

    Text {
        Layout.preferredWidth: 132
        text: root.label
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        elide: Text.ElideRight
    }

    SettingsButton {
        id: openButton
        text: "Pick…"
        onClicked: root.openPicker()
    }

    Item { Layout.fillWidth: true }

    Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 6
        color: root.value
        border.width: 1
        border.color: "#40ffffff"
    }

    Text {
        Layout.preferredWidth: 66
        text: root.value.toUpperCase()
        font.family: Theme.mono
        font.pixelSize: 10
        color: Theme.dim
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
    }

    Popup {
        id: picker
        parent: root
        x: Math.max(0, Math.min(root.width - width, openButton.x))
        y: root.height + 6
        width: 268
        padding: 12
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onClosed: {
            if (root.app && root.app.captureOwner === picker)
                root.app.captureOwner = null;
        }

        background: Rectangle {
            color: Theme.surface
            radius: 10
            border.width: 1
            border.color: Theme.border
        }

        contentItem: ColumnLayout {
            spacing: 10

            // Saturation / value square
            Item {
                id: svArea
                Layout.preferredWidth: 244
                Layout.preferredHeight: 150

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Qt.hsva(root.hsvHue / 360, 1, 1, 1)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#ff000000" }
                    }
                }

                Rectangle {
                    x: root.hsvSat * svArea.width - 7
                    y: (1 - root.hsvVal) * svArea.height - 7
                    width: 14
                    height: 14
                    radius: 7
                    color: "transparent"
                    border.width: 2
                    border.color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    onPressed: pick(mouseX, mouseY)
                    onPositionChanged: if (pressed) pick(mouseX, mouseY)

                    function pick(px, py) {
                        root.hsvSat = root.clamp01(px / width);
                        root.hsvVal = root.clamp01(1 - py / height);
                        root.emitCurrent();
                    }
                }
            }

            // Hue slider
            Item {
                id: hueArea
                Layout.preferredWidth: 244
                Layout.preferredHeight: 14

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ff0000" }
                        GradientStop { position: 0.1667; color: "#ffff00" }
                        GradientStop { position: 0.3333; color: "#00ff00" }
                        GradientStop { position: 0.5; color: "#00ffff" }
                        GradientStop { position: 0.6667; color: "#0000ff" }
                        GradientStop { position: 0.8333; color: "#ff00ff" }
                        GradientStop { position: 1.0; color: "#ff0000" }
                    }
                }

                Rectangle {
                    x: root.hsvHue / 360 * hueArea.width - 3
                    width: 6
                    height: hueArea.height
                    radius: 3
                    color: "transparent"
                    border.width: 2
                    border.color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    onPressed: pick(mouseX)
                    onPositionChanged: if (pressed) pick(mouseX)

                    function pick(px) {
                        root.hsvHue = root.clamp01(px / width) * 360;
                        root.emitCurrent();
                    }
                }
            }

            // Hex entry + close
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Hex"
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.subtext
                }

                TextField {
                    id: hexField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    text: root.value
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 11
                    horizontalAlignment: TextInput.AlignHCenter
                    selectByMouse: true
                    leftPadding: 6
                    rightPadding: 6

                    background: Rectangle {
                        color: Theme.surfaceAlt
                        radius: 6
                        border.width: 1
                        border.color: hexField.activeFocus ? Theme.accent : Theme.border
                    }

                    onTextEdited: {
                        let v = text.trim().toLowerCase();
                        if (!v.startsWith("#"))
                            v = "#" + v;
                        if (/^#[0-9a-f]{6}$/.test(v)) {
                            const hsv = root.hexToHsv(v);
                            if (hsv) {
                                root.hsvHue = hsv.h;
                                root.hsvSat = hsv.s;
                                root.hsvVal = hsv.v;
                            }
                            root.edited(v);
                        }
                    }

                    onEditingFinished: text = root.value
                }

                SettingsButton {
                    text: "Done"
                    onClicked: picker.close()
                }
            }
        }
    }
}
