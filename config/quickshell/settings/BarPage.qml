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

    readonly property var darkSurfacePresets: ["#0a0c11", "#11141b", "#171b24", "#1a202b", "#202634"]
    readonly property var lightSurfacePresets: ["#ffffff", "#f8fafc", "#f1f5f9", "#e8edf3", "#dde3ea", "#e6e8eb"]
    readonly property var darkPillPresets: ["#0a0c11", "#11141b", "#121722", "#171b24", "#1d2433"]
    readonly property var lightPillPresets: ["#ffffff", "#f8fafc", "#f1f5f9", "#e9edf2", "#dfe4ea", "#eef1f5"]

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
        text: "Appearance"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Wallpaper, Quickshell panels, and Hyprland look & feel. Quickshell changes are instant; window values apply with Apply. Pills only sit in the three marked spots."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "THEME"

        ToggleRow {
            Layout.fillWidth: true
            label: "Light mode"
            hint: "Quickshell, GTK and Qt"
            checked: root.app.themeMode === "light"
            onToggled: value => root.app.setThemeMode(value ? "light" : "dark")
        }
    }

    // ---- Live preview -------------------------------------------------
    Rectangle {
        id: preview

        Layout.fillWidth: true
        implicitHeight: 86
        radius: Theme.panelRadius
        color: Theme.bg
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
            color: Theme.pillFill
            border.width: 1
            border.color: Theme.pillBorder
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
                        border.color: Theme.accent
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
            color: Theme.pillFill
            border.width: 1
            border.color: Theme.pillBorder
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
            color: Theme.pillFill
            border.width: 1
            border.color: Theme.pillBorder
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
                    color: Theme.accent
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
                    color: Theme.accent
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
                presets: ["#7cc7f5", "#8ab4f8", "#60a5fa", "#38bdf8", "#68e0c8", "#5eead4", "#b9e6ff", "#9bd48b", "#e6c384", "#fbbf24", "#fb923c", "#e78a8a", "#f5a3c7", "#c6a0e8", "#a78bfa"]
                onEdited: value => { root.app.barAccent = value; root.app.queueSave() }
            }

            ColorField {
                Layout.fillWidth: true
                label: "Popup surface"
                value: root.app.barSurface
                presets: root.app.themeMode === "light" ? root.lightSurfacePresets : root.darkSurfacePresets
                onEdited: value => root.app.setBarColor("surface", value)
            }

            ColorField {
                Layout.fillWidth: true
                label: "Background"
                value: root.app.barPill
                presets: root.app.themeMode === "light" ? root.lightPillPresets : root.darkPillPresets
                onEdited: value => root.app.setBarColor("pill", value)
            }

            ColorField {
                Layout.fillWidth: true
                label: "Border"
                value: root.app.barPillBorder
                presets: ["#232a37", "#2b3547", "#33415c", "#3a4a63", "#465a78", "#4c6485", "#5b7fa6", "#1f4a5c", "#235f63", "#2e7d78", "#3f6f8f", "#68e0c8"]
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

    WallpaperPage {
        Layout.fillWidth: true
        app: root.app
    }

    SectionCard {
        Layout.fillWidth: true
        title: "WINDOW BORDERS"

        ColorField {
            Layout.fillWidth: true
            label: "Active border"
            value: root.app.hyprBorder1
            presets: ["#0292e3", "#01d6be", "#7cc7f5", "#c6a0e8", "#e78a8a", "#e6c384"]
            onEdited: value => root.app.hyprBorder1 = value
        }

        ColorField {
            Layout.fillWidth: true
            label: "Gradient end"
            value: root.app.hyprBorder2
            presets: ["#01d6be", "#0292e3", "#68e0c8", "#b9e6ff", "#c6a0e8"]
            onEdited: value => root.app.hyprBorder2 = value
        }

        ColorField {
            Layout.fillWidth: true
            label: "Inactive border"
            value: root.app.hyprInactive
            presets: ["#0f3246", "#1a202b", "#232a37", "#2b3547", "#3a4a63"]
            onEdited: value => root.app.hyprInactive = value
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Gradient border"
            checked: root.app.hyprGradient
            onToggled: value => root.app.hyprGradient = value
        }

        SliderField {
            Layout.fillWidth: true
            label: "Gradient angle"
            from: 0
            to: 90
            value: root.app.hyprAngle
            suffix: "°"
            enabled: root.app.hyprGradient
            opacity: enabled ? 1 : 0.45
            onMoved: value => root.app.hyprAngle = Math.round(value)
        }

        SliderField {
            Layout.fillWidth: true
            label: "Border size"
            from: 0
            to: 5
            value: root.app.hyprBorderSize
            suffix: "px"
            onMoved: value => root.app.hyprBorderSize = Math.round(value)
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "WINDOW SHAPE & GAPS"

        SliderField {
            Layout.fillWidth: true
            label: "Corner rounding"
            from: 0
            to: 20
            value: root.app.hyprRounding
            suffix: "px"
            onMoved: value => root.app.hyprRounding = Math.round(value)
        }

        SliderField {
            Layout.fillWidth: true
            label: "Inner gaps"
            from: 0
            to: 20
            value: root.app.hyprGapsIn
            suffix: "px"
            onMoved: value => root.app.hyprGapsIn = Math.round(value)
        }

        SliderField {
            Layout.fillWidth: true
            label: "Outer gaps"
            from: 0
            to: 20
            value: root.app.hyprGapsOut
            suffix: "px"
            onMoved: value => root.app.hyprGapsOut = Math.round(value)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SettingsButton {
            icon: "󰉋"
            text: "Open config folder"
            onClicked: root.app.openHyprFolder()
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "hyprland/ui_overrides.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }

}
