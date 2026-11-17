import QtQuick
import QtQuick.Layouts

// Top bar appearance controls with a live mini preview.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Top Bar"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Text {
        text: "Everything here updates the bar instantly and is saved automatically."
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
    }

    // ---- Live preview -------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 86
        radius: 12
        color: "#05070a"
        border.width: 1
        border.color: Theme.border

        Rectangle {
            x: root.app.barSideMargin
            anchors.verticalCenter: parent.verticalCenter
            width: 238
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
                spacing: 3
                Repeater {
                    model: 10
                    delegate: Rectangle {
                        required property int index
                        width: 20
                        height: 18
                        radius: 5
                        color: index === 1 ? Theme.active : "transparent"
                        border.width: index === 1 ? 1 : 0
                        border.color: root.app.barAccent
                        Text {
                            anchors.centerIn: parent
                            text: index + 1
                            font.family: Theme.mono
                            font.pixelSize: Math.max(8, root.app.barFontSize - 1)
                            color: index === 1 ? root.app.barAccent : Theme.dim
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: 210
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
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: root.app.barSideMargin
            anchors.verticalCenter: parent.verticalCenter
            width: 250
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
                spacing: 12
                Text {
                    text: "󰤨  WiFi"
                    font.family: Theme.mono
                    font.pixelSize: root.app.barFontSize
                    color: Theme.text
                }
                Text {
                    text: "󰕾  45%"
                    font.family: Theme.mono
                    font.pixelSize: root.app.barFontSize
                    color: Theme.text
                }
                Text {
                    text: "󰃠  70%"
                    font.family: Theme.mono
                    font.pixelSize: root.app.barFontSize
                    color: Theme.text
                }
                Text {
                    text: "⏻"
                    font.family: Theme.font
                    font.pixelSize: root.app.barFontSize + 2
                    color: root.app.barAccent
                }
            }
        }
    }

    // ---- Colours ------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: colorsColumn.implicitHeight + 28
        radius: 12
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
                onEdited: value => root.app.barAccent = value
            }

            ColorField {
                Layout.fillWidth: true
                label: "Popup surface"
                value: root.app.barSurface
                presets: ["#0a0c11", "#11141b", "#171b24", "#1a202b", "#202634"]
                onEdited: value => root.app.barSurface = value
            }

            ColorField {
                Layout.fillWidth: true
                label: "Pill background"
                value: root.app.barPill
                presets: ["#0a0c11", "#11141b", "#121722", "#171b24", "#1d2433"]
                onEdited: value => root.app.barPill = value
            }

            ColorField {
                Layout.fillWidth: true
                label: "Pill border"
                value: root.app.barPillBorder
                presets: ["#232a37", "#2b3547", "#3a4a63", "#4c6485", "#68e0c8"]
                onEdited: value => root.app.barPillBorder = value
            }
        }
    }

    // ---- Geometry -----------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: geometryColumn.implicitHeight + 28
        radius: 12
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
                onMoved: value => root.app.barPillHeight = Math.round(value)
            }

            SliderField {
                Layout.fillWidth: true
                label: "Pill radius"
                from: 0
                to: 18
                value: root.app.barPillRadius
                suffix: "px"
                onMoved: value => root.app.barPillRadius = Math.round(value)
            }

            SliderField {
                Layout.fillWidth: true
                label: "Side margin"
                from: 0
                to: 24
                value: root.app.barSideMargin
                suffix: "px"
                onMoved: value => root.app.barSideMargin = Math.round(value)
            }

            SliderField {
                Layout.fillWidth: true
                label: "Text size"
                from: 9
                to: 15
                value: root.app.barFontSize
                suffix: "px"
                onMoved: value => root.app.barFontSize = Math.round(value)
            }

            SliderField {
                Layout.fillWidth: true
                label: "Icon size"
                from: 11
                to: 20
                value: root.app.barIconSize
                suffix: "px"
                onMoved: value => root.app.barIconSize = Math.round(value)
            }

            SliderField {
                Layout.fillWidth: true
                label: "Pill opacity"
                from: 0.3
                to: 1.0
                stepSize: 0.05
                decimals: 2
                value: root.app.barPillOpacity
                onMoved: value => root.app.barPillOpacity = value
            }
        }
    }

}
