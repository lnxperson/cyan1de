import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

// Compact MPRIS controller shown at the bottom of the calendar popup.
// Any player publishing MPRIS metadata works: local files in VLC/mpv,
// YouTube tabs in the browser, Spotify, etc.
ColumnLayout {
    id: root

    property var player: null
    property string title: ""
    property string subtitle: ""
    property string artUrl: ""
    property bool playing: false
    property real position: 0
    property real length: 0

    spacing: 9
    visible: Theme.calendarMedia

    function refresh() {
        const players = Mpris.players.values || [];
        let chosen = null;

        // Prefer whatever is currently playing, then any player with a track.
        for (let i = 0; i < players.length; i++) {
            const p = players[i];
            if (p.isPlaying && (p.trackTitle || p.identity)) {
                chosen = p;
                break;
            }
        }
        if (!chosen) {
            for (let i = 0; i < players.length; i++) {
                if (players[i].trackTitle) {
                    chosen = players[i];
                    break;
                }
            }
        }

        root.player = chosen;
        root.title = chosen
            ? (chosen.trackTitle || chosen.identity || "Media")
            : "";

        const artist = chosen
            ? (chosen.trackArtist || (chosen.trackArtists && chosen.trackArtists[0]) || "")
            : "";
        const album = chosen ? (chosen.trackAlbum || "") : "";
        const parts = [artist, album].filter(s => s && s !== root.title);
        root.subtitle = chosen ? parts.join(" — ") : "";

        root.artUrl = chosen ? (chosen.trackArtUrl || "") : "";
        root.playing = chosen ? chosen.isPlaying : false;
        root.position = chosen ? (chosen.position || 0) : 0;
        root.length = chosen ? (chosen.length || 0) : 0;
    }

    function activate(action) {
        if (!root.player)
            return;
        if (action === "previous")
            root.player.previous();
        else if (action === "toggle")
            root.player.togglePlaying();
        else if (action === "next")
            root.player.next();
    }

    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: Theme.panelRadius
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.border

        RowLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: Theme.controlRadius
                color: Theme.surface
                border.width: 1
                border.color: Theme.border
                clip: true

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰎇"
                    font.family: Theme.font
                    font.pixelSize: 18
                    color: Theme.subtext
                    visible: !(root.artUrl !== "" && art.status === Image.Ready)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.player ? root.title : "No media playing"
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: true
                    color: root.player ? Theme.text : Theme.subtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player
                        ? (root.subtitle || root.title || "Media")
                        : "Local files, YouTube or Spotify"
                    font.family: Theme.font
                    font.pixelSize: 10
                    color: Theme.dim
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    radius: Math.min(1.5, Theme.controlRadius)
                    color: Theme.border
                    visible: root.player !== null && root.length > 0

                    Rectangle {
                        width: parent.width * Math.min(1, root.position / root.length)
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                    }
                }
            }

            RowLayout {
                spacing: 4

                ListModel {
                    id: mediaButtons
                    ListElement { action: "previous"; icon: "󰒮" }
                    ListElement { action: "toggle"; icon: "󰐊" }
                    ListElement { action: "next"; icon: "󰒭" }
                }

                Repeater {
                    model: mediaButtons

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: Theme.controlRadius
                        color: mouse.containsMouse ? Theme.active : Theme.surface
                        border.width: 1
                        border.color: Theme.border
                        opacity: buttonEnabled ? 1 : 0.4

                        property bool buttonEnabled: root.player && (
                            model.action === "toggle"
                                ? (root.player.canTogglePlaying || root.player.canPlay || root.player.canPause)
                                : (model.action === "previous" ? root.player.canGoPrevious : root.player.canGoNext)
                        )

                        Text {
                            anchors.centerIn: parent
                            text: model.action === "toggle"
                                ? (root.playing ? "󰏤" : "󰐊")
                                : model.icon
                            font.family: Theme.font
                            font.pixelSize: 15
                            color: Theme.text
                        }

                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            enabled: parent.buttonEnabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.DefaultCursor
                            onClicked: root.activate(model.action)
                        }
                    }
                }
            }
        }
    }
}
