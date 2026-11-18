import QtQuick
import QtQuick.Layouts

// Quickshell appearance controls with a live, draggable pill preview.
ColumnLayout {
    id: root

    property var app

    // All preview pills share one width. That lets the three magnetic fields
    // be larger than the pills while still centering each pill perfectly.
    readonly property int previewPillWidth: 210
    readonly property int slotWidth: 230
    // Pull the two outer fields slightly inward so they don't sit flush
    // against the preview edges.
    readonly property int fieldInset: 10
    property string draggingPill: ""
    property int activeSlot: -1

    // Offset belongs to the slot, not the pill, so pills stay centred even
    // after they swap places.
    function slotInset(fraction) {
        if (fraction <= 0.0001) return fieldInset;
        if (fraction >= 0.9999) return -fieldInset;
        return 0;
    }

    function slotX(index) {
        if (!root.app) return 0;
        const margin = root.app.barSideMargin;
        const span = Math.max(0, preview.width - margin * 2 - previewPillWidth);
        // Pill centre at this slot, shifted back by half the field width.
        return margin + index * 0.5 * span + (previewPillWidth - slotWidth) / 2
            + slotInset(index * 0.5);
    }

    function beginDrag(which) {
        root.draggingPill = which;
    }

    function endDrag() {
        root.draggingPill = "";
        root.activeSlot = -1;
    }

    function dragTo(which, area, grabOffset) {
        if (!root.app || !area.pressed) return;
        const margin = root.app.barSideMargin;
        const span = Math.max(1, preview.width - margin * 2 - area.parent.width);
        const absoluteX = area.mapToItem(preview, area.mouseX, area.mouseY).x;
        const raw = (absoluteX - grabOffset - margin) / span;
        const slot = root.app.barPillSnapSlot(raw);
        root.activeSlot = slot < 0 ? -1 : Math.round(slot * 2);
        root.app.setBarPillPosition(which, raw);
    }

    function pillFraction(which) {
        if (!root.app) return 0;
        if (which === "center") return root.app.barPillCenter;
        if (which === "right") return root.app.barPillRight;
        return root.app.barPillLeft;
    }

    function previewX(which, pillWidth) {
        if (!root.app) return 0;
        const margin = root.app.barSideMargin;
        const span = Math.max(0, preview.width - margin * 2 - pillWidth);
        const fraction = pillFraction(which);
        return margin + fraction * span + slotInset(fraction);
    }

    spacing: 14

    Text {
        text: "Quickshell"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Everything here updates Quickshell panels instantly and is saved automatically. Pills only sit in the three marked spots; drop onto an occupied spot to swap pills."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // ---- Live preview -------------------------------------------------
    Rectangle {
        id: preview

        Layout.fillWidth: true
        implicitHeight: 86
        radius: Theme.panelRadius
        color: "#05070a"
        border.width: 1
        border.color: Theme.border

        // Three shared magnetic drop spots. Any pill can land in any spot.
        Repeater {
            model: 3

            Rectangle {
                x: root.slotX(index)
                anchors.verticalCenter: parent.verticalCenter
                width: root.slotWidth
                height: preview.height - 16
                radius: Theme.panelRadius
                color: "transparent"
                border.width: root.activeSlot === index ? 2 : 1
                border.color: Theme.accent
                opacity: root.activeSlot === index
                    ? 0.9
                    : (root.draggingPill !== "" ? 0.38 : 0.16)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: ["LEFT", "CENTER", "RIGHT"][index]
                    font.family: Theme.mono
                    font.pixelSize: 8
                    color: Theme.accent
                }
            }
        }

        Rectangle {
            id: leftPill

            x: root.previewX("left", width)
            anchors.verticalCenter: parent.verticalCenter
            width: root.previewPillWidth
            height: root.app.barPillHeight
            radius: root.app.barPillRadius
            color: root.app.barPill
            border.width: 1
            border.color: root.app.barPillBorder
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 1.0 - root.app.barPillOpacity
            }

            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: 10
                    delegate: Rectangle {
                        required property int index
                        width: 15
                        height: 16
                        radius: 4
                        color: index === 1 ? Theme.active : "transparent"
                        border.width: index === 1 ? 1 : 0
                        border.color: root.app.barAccent
                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            font.family: Theme.mono
                            font.pixelSize: Math.max(7, root.app.barFontSize - 2)
                            color: index === 1 ? root.app.barAccent : Theme.dim
                        }
                    }
                }
            }

            MouseArea {
                id: leftDrag
                property real grabOffset: 0

                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPressed: {
                    grabOffset = mapToItem(preview, mouseX, mouseY).x - parent.x;
                    root.beginDrag("left");
                }
                onPositionChanged: root.dragTo("left", leftDrag, grabOffset)
                onReleased: root.endDrag()
                onCanceled: root.endDrag()
            }
        }

        Rectangle {
            id: centerPill

            x: root.previewX("center", width)
            anchors.verticalCenter: parent.verticalCenter
            width: root.previewPillWidth
            height: root.app.barPillHeight
            radius: root.app.barPillRadius
            color: root.app.barPill
            border.width: 1
            border.color: root.app.barPillBorder
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 1.0 - root.app.barPillOpacity
            }

            Text {
                anchors.centerIn: parent
                text: "󰥔  Tue 17 Nov  19:42"
                font.family: Theme.mono
                font.pixelSize: root.app.barFontSize
                color: Theme.text
            }

            MouseArea {
                id: centerDrag
                property real grabOffset: 0

                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPressed: {
                    grabOffset = mapToItem(preview, mouseX, mouseY).x - parent.x;
                    root.beginDrag("center");
                }
                onPositionChanged: root.dragTo("center", centerDrag, grabOffset)
                onReleased: root.endDrag()
                onCanceled: root.endDrag()
            }
        }

        Rectangle {
            id: rightPill

            x: root.previewX("right", width)
            anchors.verticalCenter: parent.verticalCenter
            width: root.previewPillWidth
            height: root.app.barPillHeight
            radius: root.app.barPillRadius
            color: root.app.barPill
            border.width: 1
            border.color: root.app.barPillBorder
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 1.0 - root.app.barPillOpacity
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "󰂯"
                    font.family: Theme.font
                    font.pixelSize: root.app.barFontSize
                    color: root.app.barAccent
                }
                Text {
                    text: "󰤨  WiFi"
                    font.family: Theme.mono
                    font.pixelSize: Math.max(10, root.app.barFontSize - 2)
                    color: Theme.text
                }
                Text {
                    text: "󰕾  45%"
                    font.family: Theme.mono
                    font.pixelSize: Math.max(10, root.app.barFontSize - 2)
                    color: Theme.text
                }
                Text {
                    text: "󰃠  70%"
                    font.family: Theme.mono
                    font.pixelSize: Math.max(10, root.app.barFontSize - 2)
                    color: Theme.text
                }
                Text {
                    text: "⏻"
                    font.family: Theme.font
                    font.pixelSize: root.app.barFontSize + 1
                    color: root.app.barAccent
                }
            }

            MouseArea {
                id: rightDrag
                property real grabOffset: 0

                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                onPressed: {
                    grabOffset = mapToItem(preview, mouseX, mouseY).x - parent.x;
                    root.beginDrag("right");
                }
                onPositionChanged: root.dragTo("right", rightDrag, grabOffset)
                onReleased: root.endDrag()
                onCanceled: root.endDrag()
            }
        }
    }

    // ---- Colours ------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: colorsColumn.implicitHeight + 28
        radius: Theme.panelRadius
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: colorsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                text: "COLOURS"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

            ColorField {
                Layout.fillWidth: true
                label: "Accent"
                value: root.app.barAccent
                presets: ["#7cc7f5", "#68e0c8", "#c6a0e8", "#f5a3c7", "#e6c384", "#9bd48b", "#e78a8a"]
                onEdited: value => { root.app.barAccent = value; root.app.queueSave() }
            }

            ColorField {
                Layout.fillWidth: true
                label: "Popup surface"
                value: root.app.barSurface
                presets: ["#0a0c11", "#11141b", "#171b24", "#1a202b", "#202634"]
                onEdited: value => { root.app.barSurface = value; root.app.queueSave() }
            }

            ColorField {
                Layout.fillWidth: true
                label: "Pill background"
                value: root.app.barPill
                presets: ["#0a0c11", "#11141b", "#121722", "#171b24", "#1d2433"]
                onEdited: value => { root.app.barPill = value; root.app.queueSave() }
            }

            ColorField {
                Layout.fillWidth: true
                label: "Pill border"
                value: root.app.barPillBorder
                presets: ["#232a37", "#2b3547", "#3a4a63", "#4c6485", "#68e0c8"]
                onEdited: value => { root.app.barPillBorder = value; root.app.queueSave() }
            }
        }
    }

    // ---- Geometry -----------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: geometryColumn.implicitHeight + 28
        radius: Theme.panelRadius
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: geometryColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                text: "GEOMETRY"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

            SliderField {
                Layout.fillWidth: true
                label: "Pill height"
                from: 26
                to: 44
                value: root.app.barPillHeight
                suffix: "px"
                onMoved: value => { root.app.barPillHeight = Math.round(value); root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Corner radius"
                from: 0
                to: 18
                value: root.app.barPillRadius
                suffix: "px"
                onMoved: value => { root.app.barPillRadius = Math.round(value); root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Side margin"
                from: 0
                to: 24
                value: root.app.barSideMargin
                suffix: "px"
                onMoved: value => { root.app.barSideMargin = Math.round(value); root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Text size"
                from: 9
                to: 15
                value: root.app.barFontSize
                suffix: "px"
                onMoved: value => { root.app.barFontSize = Math.round(value); root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Icon size"
                from: 11
                to: 20
                value: root.app.barIconSize
                suffix: "px"
                onMoved: value => { root.app.barIconSize = Math.round(value); root.app.queueSave() }
            }

            SliderField {
                Layout.fillWidth: true
                label: "Pill opacity"
                from: 0.3
                to: 1.0
                stepSize: 0.05
                decimals: 2
                value: root.app.barPillOpacity
                onMoved: value => { root.app.barPillOpacity = value; root.app.queueSave() }
            }
        }
    }
}
