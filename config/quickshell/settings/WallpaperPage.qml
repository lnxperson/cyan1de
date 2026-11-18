import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Wallpaper picker. Selection applies instantly through the Quickshell
// background daemon.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "WALLPAPER"
        font.family: Theme.mono
        font.pixelSize: 10
        font.weight: Font.DemiBold
        color: Theme.dim
    }

    // Current wallpaper preview
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 232
        radius: 12
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border
        clip: true

        Image {
            anchors.fill: parent
            source: root.app.resolvedWallpaperPath.length > 0
                ? "file://" + root.app.resolvedWallpaperPath
                : ""
            fillMode: root.app.wallpaperMode === "fit"
                ? Image.PreserveAspectFit
                : (root.app.wallpaperMode === "stretch" ? Image.Stretch : Image.PreserveAspectCrop)
            asynchronous: true
            cache: false
            smooth: true
        }

        Text {
            anchors.centerIn: parent
            visible: root.app.wallpaperPath === ""
            text: "No wallpaper selected"
            font.family: Theme.mono
            font.pixelSize: 12
            color: Theme.dim
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 34
            color: "#aa05070a"

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                text: root.app.wallpaperPath
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.subtext
                elide: Text.ElideMiddle
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Text {
            text: "Scaling"
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.subtext
        }

        Segmented {
            options: [
                { label: "Crop", value: "crop" },
                { label: "Fit", value: "fit" },
                { label: "Stretch", value: "stretch" }
            ]
            value: root.app.wallpaperMode
            onSelected: value => root.app.setWallpaperMode(value)
        }

        Item { Layout.fillWidth: true }

        SettingsButton {
            icon: "󰉋"
            text: "Pictures folder"
            onClicked: root.app.openPictures()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: libraryColumn.implicitHeight + 28
        radius: 12
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: libraryColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "LIBRARY"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.dim
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.app.wallpapers.length + " image"
                        + (root.app.wallpapers.length === 1 ? "" : "s") + " in ~/Pictures"
                    font.family: Theme.mono
                    font.pixelSize: 10
                    color: Theme.dim
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                clip: true
                contentWidth: wallpaperRow.implicitWidth
                contentHeight: wallpaperRow.height
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOn
                ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                Row {
                    id: wallpaperRow
                    height: 94
                    spacing: 10

                    Repeater {
                        model: root.app.wallpapers

                        delegate: Rectangle {
                            required property string modelData

                            width: 150
                            height: 84
                            radius: 9
                            color: Theme.bg
                            border.width: root.app.wallpaperPath === modelData ? 2 : 1
                            border.color: root.app.wallpaperPath === modelData ? Theme.accent : Theme.border
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: "file://" + root.app.resolveWallpaperPath(modelData)
                                sourceSize.width: 300
                                sourceSize.height: 168
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 20
                                color: "#bb05070a"

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.split("/").pop()
                                    font.family: Theme.mono
                                    font.pixelSize: 9
                                    color: Theme.subtext
                                    elide: Text.ElideMiddle
                                }
                            }

                            Rectangle {
                                visible: root.app.wallpaperPath === modelData
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 5
                                width: 18
                                height: 18
                                radius: 9
                                color: Theme.accent

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 10
                                    color: Theme.bg
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.app.selectWallpaper(modelData)
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.app.wallpapers.length === 0
                text: "No images found in ~/Pictures."
                font.family: Theme.mono
                font.pixelSize: 11
                color: Theme.dim
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: pathColumn.implicitHeight + 28
        radius: 12
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: pathColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10

            Text {
                text: "CUSTOM PATH"
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: Theme.dim
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                TextField {
                    id: pathField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    text: root.app.wallpaperPath
                    placeholderText: "~/Pictures/wallpaper.png"
                    placeholderTextColor: Theme.dim
                    color: Theme.text
                    font.family: Theme.mono
                    font.pixelSize: 11
                    selectByMouse: true
                    leftPadding: 9
                    rightPadding: 9
                    background: Rectangle {
                        color: Theme.bg
                        radius: 7
                        border.width: 1
                        border.color: pathField.activeFocus ? Theme.accent : Theme.border
                    }

                    // Keep Apply in sync even if the field keeps focus when
                    // the button is clicked.
                    onTextEdited: root.app.wallpaperPath = text.trim()
                    onEditingFinished: {
                        const v = text.trim();
                        // Don't save an empty path just because the field lost
                        // focus (e.g. when this page is unloaded by the sidebar).
                        if (v !== "" && v !== root.app.wallpaperPath)
                            root.app.selectWallpaper(v);
                    }
                }

                SettingsButton {
                    text: "Set wallpaper"
                    onClicked: root.app.selectWallpaper(pathField.text.trim())
                }
            }
        }
    }

}
