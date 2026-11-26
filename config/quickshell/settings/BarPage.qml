import QtQuick
import QtQuick.Layouts

// Quickshell appearance controls with a live, draggable pill preview.
ColumnLayout {
    id: root

    property var app
    property string section: "panel"

    readonly property var sectionHints: ({
        panel: "Layout, elements and the live drag preview.",
        style: "Theme mode, panel colours and sizing.",
        themes: "Save and reload complete appearance presets.",
        cursor: "Pointer theme and size, applied instantly.",
        wallpaper: "Choose the wallpaper and how it fills the screen."
    })

    // Displays offered by the panel placement controls. The saved value is
    // kept selectable even when that display is temporarily unplugged.
    readonly property var panelDisplayOptions: {
        const list = ["all"];
        for (let i = 0; i < root.app.monitorCount; i++) {
            const mon = root.app.monitorAt(i);
            if (mon && mon.name && list.indexOf(mon.name) < 0)
                list.push(mon.name);
        }
        if (root.app.barDisplay !== "all" &&
            list.indexOf(root.app.barDisplay) < 0)
            list.push(root.app.barDisplay);
        return list;
    }
    readonly property var panelDisplayLabels: {
        const labels = { "all": "All displays" };
        for (let i = 1; i < root.panelDisplayOptions.length; i++)
            labels[root.panelDisplayOptions[i]] = root.panelDisplayOptions[i];
        return labels;
    }

    spacing: 14

    SettingLabel {
        text: String(root.sectionHints[root.section] || "")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "style"
        title: "STYLE"
        subtitle: "The accent colour also themes GTK, libadwaita and Qt applications."

        ToggleRow {
            Layout.fillWidth: true
            label: "Light mode"
            hint: "Quickshell, GTK and Qt"
            checked: root.app.themeMode === "light"
            onToggled: value => root.app.setThemeMode(value ? "light" : "dark")
        }
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "themes"
        title: "THEMES"
        subtitle: "Save the current Quickshell appearance and Hyprland window styling, then load it back in one click."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TextFieldRow {
                Layout.fillWidth: true
                label: "Save as"
                labelWidth: 90
                placeholder: "Theme name"
                value: root.app.newThemeName
                onEdited: value => root.app.newThemeName = value
            }

            SettingsButton {
                text: "Save"
                primary: true
                enabled: root.app.newThemeName.trim().length > 0
                tooltip: "Save current appearance and window settings"
                onClicked: root.app.saveTheme(root.app.newThemeName)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 10
            columnSpacing: 10

            Repeater {
                model: root.app.themeNames

                Rectangle {
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 132
                    radius: Theme.panelRadius
                    color: Theme.surface
                    border.width: 1
                    border.color: mouse.containsMouse ? Theme.accent : Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            font.family: Theme.mono
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.text
                            elide: Text.ElideRight
                            maximumLineCount: 2
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: Theme.controlRadius
                                color: root.app.themePreviews[modelData]
                                    ? root.app.themePreviews[modelData].accent : Theme.accent
                                border.width: 1
                                border.color: Theme.border
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: Theme.controlRadius
                                color: root.app.themePreviews[modelData]
                                    ? root.app.themePreviews[modelData].surface : Theme.surfaceAlt
                                border.width: 1
                                border.color: Theme.border
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: Theme.controlRadius
                                color: root.app.themePreviews[modelData]
                                    ? root.app.themePreviews[modelData].pill : Theme.bg
                                border.width: 1
                                border.color: Theme.border
                            }

                            Rectangle {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                radius: Theme.controlRadius
                                color: root.app.themePreviews[modelData]
                                    ? root.app.themePreviews[modelData].border1 : Theme.accentAlt
                                border.width: 1
                                border.color: Theme.border
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            Layout.fillWidth: true
                            text: "Click to load"
                            font.family: Theme.mono
                            font.pixelSize: 9
                            color: Theme.dim
                        }
                    }

                    Rectangle {
                        z: 2
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 18
                        height: 18
                        radius: Theme.controlRadius
                        color: clearMouse.containsMouse ? Theme.hover : Theme.surfaceAlt
                        border.width: 1
                        border.color: Theme.border

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.mono
                            font.pixelSize: 9
                            color: clearMouse.containsMouse ? Theme.red : Theme.dim
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.app.deleteTheme(modelData)
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.app.selectedTheme = modelData;
                            root.app.loadTheme(modelData);
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.columnSpan: 4
                visible: root.app.themeNames.length === 0
                text: "No saved themes yet — enter a name above and press Save."
                font.family: Theme.mono
                font.pixelSize: 9
                color: Theme.dim
                wrapMode: Text.WordWrap
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Themes are stored in ~/.config/quickshell/themes.json. Loading also presses Apply so Hyprland window styling takes effect."
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.dim
            wrapMode: Text.WordWrap
        }
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "cursor"
        title: "CURSOR"
        subtitle: "Pointer theme and size apply immediately. Press Apply to write them into Hyprland's environment."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Theme"
            }

            OptionCombo {
                options: root.app.cursorThemeOptions
                labels: root.app.cursorThemeLabels
                selected: root.app.cursorTheme
                onPicked: value => root.app.setCursorTheme(value)
            }

            SettingsButton {
                text: "Rescan"
                tooltip: "Look for installed cursor themes again"
                onClicked: root.app.scanCursors()
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Pointer size"
            from: 12
            to: 64
            stepSize: 2
            value: root.app.cursorSize
            suffix: "px"
            onMoved: value => root.app.setCursorSize(Math.round(value))
        }

        Text {
            Layout.fillWidth: true
            text: "Some Qt apps pick up a new Xcursor theme only after they restart."
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.dim
            wrapMode: Text.WordWrap
        }
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "panel"
        title: "PANEL"
        subtitle: "Choose how the bar is arranged, which screen edge it sits on, and where it appears."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Layout"
                tooltipText: "Panel layout: floating pills, unified, wrap, corners or island."
            }

            OptionCombo {
                options: root.app.barLayoutOptions
                labels: root.app.barLayoutLabels
                selected: root.app.barLayout
                tooltip: "Panel layout: floating pills, unified, wrap, corners or island."
                onPicked: value => { root.app.barLayout = value; root.app.queueManaged() }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Edge"
            }

            OptionCombo {
                options: root.app.barEdgeOptions
                labels: root.app.barEdgeLabels
                selected: root.app.barEdge
                onPicked: value => { root.app.barEdge = value; root.app.queueManaged() }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 150
                text: "Display"
            }

            OptionCombo {
                options: root.panelDisplayOptions
                labels: root.panelDisplayLabels
                selected: root.app.barDisplay
                onPicked: value => { root.app.barDisplay = value; root.app.queueManaged() }
            }

            Item { Layout.fillWidth: true }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "panel"
        title: "PANEL ELEMENTS"
        subtitle: "Hidden elements are removed from the bar and from its layout."

        ToggleRow {
            Layout.fillWidth: true
            label: "Application menu"
            hint: "Launcher button"
            checked: root.app.barShowAppMenu
            onToggled: value => { root.app.barShowAppMenu = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Workspaces"
            hint: "Workspace switcher"
            checked: root.app.barShowWorkspaces
            onToggled: value => { root.app.barShowWorkspaces = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Clock"
            hint: "Opens the calendar pop-up"
            checked: root.app.barShowClock
            onToggled: value => { root.app.barShowClock = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "System tray"
            hint: "Tray icons and their separator"
            checked: root.app.barShowTray
            onToggled: value => { root.app.barShowTray = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Bluetooth"
            checked: root.app.barShowBluetooth
            onToggled: value => { root.app.barShowBluetooth = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Network"
            checked: root.app.barShowNetwork
            onToggled: value => { root.app.barShowNetwork = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Volume"
            checked: root.app.barShowVolume
            onToggled: value => { root.app.barShowVolume = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Brightness"
            checked: root.app.barShowBrightness
            onToggled: value => { root.app.barShowBrightness = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Battery"
            checked: root.app.barShowBattery
            onToggled: value => { root.app.barShowBattery = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Power"
            checked: root.app.barShowPower
            onToggled: value => { root.app.barShowPower = value; root.app.queueSave() }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Update indicator"
            hint: "Arch updates in panel and calendar"
            checked: root.app.barShowUpdates
            onToggled: value => { root.app.barShowUpdates = value; root.app.queueSave() }
        }
    }


    // ---- Live preview -------------------------------------------------
    BarPreview {
        Layout.fillWidth: true
        visible: root.section === "panel"
        width: parent.width
        app: root.app
        overlayHost: root.app.dragOverlayHost
    }

    // ---- Colours ------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: root.section === "style"
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

            SettingsButton {
                Layout.fillWidth: true
                icon: "󰈺"
                text: "Use wallpaper colors"
                tooltip: "Average the current wallpaper and tint every Quickshell color"
                enabled: root.app.resolvedWallpaperPath.length > 0
                onClicked: root.app.applyWallpaperColors()
            }

            ColorField {
                Layout.fillWidth: true
                app: root.app
                label: "Accent"
                value: root.app.barAccent
                onEdited: value => { root.app.barAccent = value; root.app.queueSave() }
            }

            ColorField {
                Layout.fillWidth: true
                app: root.app
                label: "Font color"
                value: root.app.barText
                onEdited: value => { root.app.barText = value; root.app.queueSave() }
            }

            ColorField {
                Layout.fillWidth: true
                app: root.app
                label: "Popup surface"
                value: root.app.barSurface
                onEdited: value => root.app.setBarColor("surface", value)
            }

            ColorField {
                Layout.fillWidth: true
                app: root.app
                label: "Background"
                value: root.app.barPill
                onEdited: value => root.app.setBarColor("pill", value)
            }

            ColorField {
                Layout.fillWidth: true
                app: root.app
                label: "Border"
                value: root.app.barPillBorder
                onEdited: value => { root.app.barPillBorder = value; root.app.queueSave() }
            }
        }
    }

    // ---- Geometry -----------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: root.section === "style"
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
                label: "Panel height"
                from: 30
                to: 56
                value: root.app.barPanelHeight
                suffix: "px"
                onMoved: value => { root.app.barPanelHeight = Math.round(value); root.app.queueSave() }
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
        visible: root.section === "wallpaper"
        app: root.app
    }
}
