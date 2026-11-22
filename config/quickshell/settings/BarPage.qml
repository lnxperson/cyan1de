import QtQuick
import QtQuick.Layouts

// Quickshell appearance controls with a live, draggable pill preview.
ColumnLayout {
    id: root

    property var app
    property string section: "panel"

    readonly property var sectionHints: ({
        panel: "Panel layout, elements, calendar and the live drag preview.",
        theme: "Theme mode, panel colours and sizing.",
        cursor: "Pointer theme and size, applied instantly.",
        wallpaper: "Choose the wallpaper and how it fills the screen.",
        effects: "Animation styles, speed and blur. Press Apply for Hyprland changes.",
        windows: "Window borders, rounding and gaps. Press Apply for Hyprland changes."
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

    Text {
        text: String(root.sectionHints[root.section] || "")
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "theme"
        title: "THEME"

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
        visible: root.section === "cursor"
        title: "CURSOR"
        subtitle: "Pointer theme and size apply immediately. Press Apply to write them into Hyprland's environment."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Theme"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
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

            Text {
                Layout.preferredWidth: 150
                text: "Layout"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.barLayoutOptions
                labels: root.app.barLayoutLabels
                selected: root.app.barLayout
                onPicked: value => { root.app.barLayout = value; root.app.queueSave() }
            }

            SettingsButton {
                visible: root.app.barLayout === "unified"
                text: root.app.barUnifiedCorners ? "Corners: on" : "Corners: off"
                primary: root.app.barUnifiedCorners
                onClicked: {
                    root.app.barUnifiedCorners = !root.app.barUnifiedCorners;
                    root.app.queueSave();
                }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Edge"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.barEdgeOptions
                labels: root.app.barEdgeLabels
                selected: root.app.barEdge
                onPicked: value => { root.app.barEdge = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Display"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.panelDisplayOptions
                labels: root.panelDisplayLabels
                selected: root.app.barDisplay
                onPicked: value => { root.app.barDisplay = value; root.app.queueSave() }
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
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "panel"
        title: "CALENDAR LAYOUT"
        subtitle: "Arrange what appears inside the calendar pop-up."

        ToggleRow {
            Layout.fillWidth: true
            label: "Media controls"
            hint: "Show media player controls"
            checked: root.app.calendarMedia
            onToggled: value => { root.app.calendarMedia = value; root.app.queueSave() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Media position"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: ["bottom", "top"]
                labels: ({ "bottom": "Bottom", "top": "Top" })
                selected: root.app.calendarMediaPosition
                onPicked: value => { root.app.calendarMediaPosition = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Notifications"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: ["right", "left"]
                labels: ({ "right": "Right", "left": "Left" })
                selected: root.app.calendarNotificationsSide
                onPicked: value => { root.app.calendarNotificationsSide = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Popup width"
            from: 380
            to: 1100
            stepSize: 10
            value: root.app.calendarWidth
            suffix: "px"
            onMoved: value => { root.app.calendarWidth = Math.round(value); root.app.queueSave() }
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
        visible: root.section === "theme"
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
        visible: root.section === "theme"
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

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "windows"
        title: "WINDOW BORDERS"

        ColorField {
            Layout.fillWidth: true
            app: root.app
            label: "Active border"
            value: root.app.hyprBorder1
            onEdited: value => root.app.hyprBorder1 = value
        }

        ColorField {
            Layout.fillWidth: true
            app: root.app
            label: "Gradient end"
            value: root.app.hyprBorder2
            onEdited: value => root.app.hyprBorder2 = value
        }

        ColorField {
            Layout.fillWidth: true
            app: root.app
            label: "Inactive border"
            value: root.app.hyprInactive
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
        visible: root.section === "windows"
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

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "effects"
        title: "ANIMATIONS"
        subtitle: "Built-in Hyprland styles and curves only. Speed scales every animation. Press Apply to write hyprland/animations.lua."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Window open"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.windowAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animWindowOpen
                onPicked: value => root.app.animWindowOpen = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Window close"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.windowAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animWindowClose
                onPicked: value => root.app.animWindowClose = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Workspace switch"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.workspaceAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animWorkspace
                onPicked: value => root.app.animWorkspace = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Layer / popup"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.layerAnimStyles
                labels: root.app.animStyleLabels
                selected: root.app.animLayer
                onPicked: value => root.app.animLayer = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Open easing"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.animCurves
                labels: root.app.animCurveLabels
                selected: root.app.animOpenCurve
                onPicked: value => root.app.animOpenCurve = value
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.preferredWidth: 150
                text: "Close easing"
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.subtext
            }

            OptionCombo {
                options: root.app.animCurves
                labels: root.app.animCurveLabels
                selected: root.app.animCloseCurve
                onPicked: value => root.app.animCloseCurve = value
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Animation speed"
            from: 1
            to: 20
            value: root.app.animSpeed
            suffix: ""
            onMoved: value => root.app.animSpeed = Math.round(value)
        }
    }

    SectionCard {
        Layout.fillWidth: true
        visible: root.section === "effects"
        title: "BLUR"

        ToggleRow {
            Layout.fillWidth: true
            label: "Hyprland blur"
            hint: "Blur behind transparent windows"
            checked: root.app.hyprBlur
            onToggled: value => {
                root.app.hyprBlur = value
                root.app.queueSave()
            }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Alacritty blur"
            hint: "Transparent terminal shows the desktop blur"
            checked: root.app.alacrittyBlur
            onToggled: value => {
                root.app.alacrittyBlur = value
                root.app.queueSave()
            }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Alacritty blur strength"
            from: 0
            to: 100
            value: root.app.alacrittyBlurStrength
            suffix: "%"
            enabled: root.app.alacrittyBlur
            opacity: enabled ? 1 : 0.45
            onMoved: value => {
                root.app.alacrittyBlurStrength = Math.round(value)
                root.app.queueSave()
            }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Hyprland blur radius"
            from: 1
            to: 20
            value: root.app.hyprBlurSize
            suffix: "px"
            enabled: root.app.hyprBlur
            opacity: enabled ? 1 : 0.45
            onMoved: value => {
                root.app.hyprBlurSize = Math.round(value)
                root.app.queueSave()
            }
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
            text: "hyprland/ui_overrides.lua + animations.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }

}
