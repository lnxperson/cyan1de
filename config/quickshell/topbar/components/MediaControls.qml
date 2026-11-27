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
    // Some players (notably Firefox for YouTube) claim CanSeek but silently
    // ignore Seek/SetPosition and expose no duration. Only allow scrubbing
    // when a real duration exists, otherwise wheel input just fires no-ops.
    property bool seekEnabled: root.player && root.player.canSeek
        && root.hasDuration
    // Browsers often publish no mpris:length. In that case Quickshell reports
    // length == position, so a plain position/length calculation would pin the
    // bar to the end. Treat that as indeterminate instead.
    property bool hasDuration: root.player && root.player.lengthSupported
        && root.length > 0
    property real progress: 0
    property real wheelRemainder: 0
    property bool dragging: false
    property real dragProgress: 0
    property bool seekHold: false
    property var trackId: null
    property real pressProgress: 0

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

        const changed = chosen !== root.player
            || (chosen && chosen.uniqueId !== root.trackId);
        if (changed) {
            root.wheelRemainder = 0;
            root.dragging = false;
            root.seekHold = false;
        }
        root.player = chosen;
        root.trackId = chosen ? chosen.uniqueId : null;
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

        // While dragging or just after a seek, keep the handle where the user
        // put it instead of letting the 500ms poll snap it back.
        if (!root.dragging && !root.seekHold) {
            root.progress = root.hasDuration
                ? Math.max(0, Math.min(1, root.position / root.length))
                : 0;
        }
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

    function currentPosition() {
        if (!root.player)
            return 0;
        return root.player.positionSupported ? root.player.position : root.position;
    }

    function holdPosition(target) {
        root.position = target;
        if (root.hasDuration)
            root.progress = Math.max(0, Math.min(1, target / root.length));
        root.seekHold = true;
        seekHoldTimer.restart();
    }

    // Relative Seek is reliable for small steps (wheel). Some players ignore
    // the magnitude of Seek and jump by a fixed amount, so absolute jumps use
    // SetPosition through Quickshell's writable position property instead.
    function seekDelta(delta) {
        if (!root.seekEnabled || Math.abs(delta) < 0.01)
            return;
        const target = Math.max(0, Math.min(root.length,
            currentPosition() + delta));
        root.player.seek(delta);
        holdPosition(target);
    }

    // Absolute seek is only meaningful when the player publishes a duration.
    function seekTo(seconds) {
        if (!root.seekEnabled)
            return;
        const target = Math.max(0, Math.min(root.length, seconds));
        if (root.player.positionSupported) {
            // Uses MPRIS SetPosition with the current track id, which is the
            // spec-compliant way to jump to an exact point.
            root.player.position = target;
        } else {
            root.player.seek(target - root.player.position);
        }
        holdPosition(target);
    }

    function seekBy(seconds) {
        seekDelta(seconds);
    }

    Timer {
        id: seekHoldTimer
        interval: 700
        onTriggered: root.seekHold = false
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
                    visible: root.player !== null

                    Rectangle {
                        width: parent.width * root.progress
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                        visible: root.hasDuration
                    }

                    // The dot is the seek handle. For players with no usable
                    // duration it stays dim at the left edge as an indicator
                    // only; Firefox/YouTube does not implement MPRIS seeking.
                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        color: root.hasDuration ? Theme.accent : Theme.dim
                        border.width: 1
                        border.color: Theme.surface
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width,
                            parent.width * root.progress - width / 2))
                        visible: root.player !== null
                    }

                    // Wheel seeks by five seconds per notch. Clicking jumps
                    // straight to that point; dragging previews the dot and
                    // commits the final position on release. The hit area is
                    // taller than the 3px bar so the dot stays comfortable to
                    // grab without changing the layout.
                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        anchors.topMargin: -5
                        anchors.bottomMargin: -5
                        hoverEnabled: true
                        enabled: root.seekEnabled
                        cursorShape: root.seekEnabled
                            ? Qt.PointingHandCursor : Qt.ArrowCursor
                        preventStealing: true

                        onWheel: event => {
                            if (!root.seekEnabled)
                                return;
                            let delta = event.angleDelta.y;
                            if (delta === 0)
                                delta = event.angleDelta.x;
                            if (delta === 0)
                                delta = event.pixelDelta.y * 4;
                            if (delta === 0)
                                delta = event.pixelDelta.x * 4;

                            root.wheelRemainder += delta;
                            const notches = Math.trunc(root.wheelRemainder / 120);
                            root.wheelRemainder -= notches * 120;
                            if (notches !== 0) {
                                const step = (event.modifiers & Qt.ShiftModifier)
                                    ? 1 : 5;
                                root.seekBy(notches * step);
                            }
                            event.accepted = true;
                        }

                        onPressed: {
                            if (!root.seekEnabled)
                                return;
                            root.dragging = true;
                            root.dragProgress = Math.max(0, Math.min(1,
                                mouseX / Math.max(1, width)));
                            root.pressProgress = root.dragProgress;
                            root.progress = root.dragProgress;
                            root.seekTo(root.dragProgress * root.length);
                        }

                        onPositionChanged: if (root.dragging) {
                            root.dragProgress = Math.max(0, Math.min(1,
                                mouseX / Math.max(1, width)));
                            root.progress = root.dragProgress;
                        }

                        onReleased: {
                            if (!root.dragging)
                                return;
                            root.dragging = false;
                            if (Math.abs(root.dragProgress - root.pressProgress) > 0.001)
                                root.seekTo(root.dragProgress * root.length);
                        }

                        onCanceled: {
                            root.dragging = false;
                            root.seekHold = false;
                            root.refresh();
                        }
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
