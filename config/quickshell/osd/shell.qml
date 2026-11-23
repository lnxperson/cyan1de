import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// Replacement for swayosd: volume/microphone/brightness feedback.
// Volume and microphone changes are observed from Pipewire, brightness is
// polled from the backlight sysfs attribute (sysfs does not support inotify).
ShellRoot {
    id: osd

    property string kind: "volume"
    property real value: 0
    property bool muted: false
    property bool shown: false
    property real reveal: 0
    property bool closing: false
    property bool ready: false
    property real revealFrom: 0
    property real revealTo: 0
    property real revealStarted: 0
    property bool revealAnimating: false
    property real revealTickerValue: 0

    // Follow Hyprland's focused monitor, mapped to the matching Quickshell
    // screen. The window's own `screen` is unreliable while it is hidden, and
    // pinning to the first screen puts the OSD on the wrong display.
    readonly property var focusedScreen: {
        const monitor = Hyprland.focusedMonitor;
        const name = monitor ? monitor.name : "";
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === name)
                return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    // The animation driver advances per frame in this Quickshell build, so a
    // plain tween runs faster on high-refresh monitors. Use the animation only
    // as a frame ticker and derive progress from real elapsed time instead.
    NumberAnimation {
        id: revealTicker
        target: osd
        property: "revealTickerValue"
        from: 0
        to: 1
        duration: 60000
        loops: Animation.Infinite
        running: osd.revealAnimating
    }

    onRevealTickerValueChanged: {
        if (!osd.revealAnimating)
            return;

        const elapsed = Date.now() - osd.revealStarted;
        const t = Math.min(1, elapsed / Theme.motionSlow);
        const eased = 1 - Math.pow(1 - t, 3);
        osd.reveal = osd.revealFrom
            + (osd.revealTo - osd.revealFrom) * eased;

        if (t < 1)
            return;

        osd.reveal = osd.revealTo;
        osd.revealAnimating = false;
        if (osd.revealTo <= 0) {
            osd.shown = false;
            osd.closing = false;
        }
    }

    function animateReveal(to) {
        if (Math.abs(osd.reveal - to) < 0.001) {
            osd.reveal = to;
            return;
        }
        osd.revealFrom = osd.reveal;
        osd.revealTo = to;
        osd.revealStarted = Date.now();
        osd.revealAnimating = true;
    }

    property string backlightDir: ""
    property int maxRaw: 0
    property int lastRaw: -1

    property string kbdDir: ""
    property int kbdMaxRaw: 0
    property int kbdLastRaw: -1

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var sourceAudio: source ? source.audio : null

    readonly property color tone: kind === "brightness"
        ? Theme.yellow
        : (kind === "kbd"
            ? Theme.mauve
            : (kind === "mic" ? Theme.accentAlt : Theme.accent))

    readonly property string glyph: {
        if (kind === "brightness")
            return "󰃠";
        if (kind === "kbd")
            return "󰌌";
        if (kind === "mic")
            return muted ? "󰍭" : "󰍬";
        if (muted || value <= 0.01)
            return "󰖁";
        return value < 0.5 ? "󰖀" : "󰕾";
    }

    readonly property string valueText: muted ? "Muted" : Math.round(value * 100) + "%"

    function present() {
        closing = false;
        shown = true;
        if (reveal < 1)
            animateReveal(1);
        else
            reveal = 1;
        hideTimer.restart();
    }

    function flash(nextKind) {
        if (nextKind === "volume") {
            if (!sinkAudio)
                return;
            kind = "volume";
            value = sinkAudio.volume;
            muted = sinkAudio.muted;
        } else if (nextKind === "mic") {
            if (!sourceAudio)
                return;
            kind = "mic";
            value = sourceAudio.volume;
            muted = sourceAudio.muted;
        }

        present();
    }

    function flashBrightness(percent) {
        kind = "brightness";
        value = Math.max(0, Math.min(1, percent / 100));
        muted = false;
        present();
    }

    function flashKeyboard(percent) {
        kind = "kbd";
        value = Math.max(0, Math.min(1, percent / 100));
        muted = false;
        present();
    }

    function pollBrightness() {
        if (backlightDir === "")
            return;

        brightnessFile.reload();
        const raw = parseInt(brightnessFile.text(), 10);
        if (isNaN(raw))
            return;

        if (maxRaw <= 0) {
            maxFile.reload();
            const max = parseInt(maxFile.text(), 10);
            if (!isNaN(max) && max > 0)
                maxRaw = max;
        }

        if (maxRaw > 0 && lastRaw >= 0 && raw !== lastRaw)
            flashBrightness(Math.round(raw / maxRaw * 100));

        lastRaw = raw;
    }

    function pollKeyboard() {
        if (kbdDir === "")
            return;

        kbdFile.reload();
        const raw = parseInt(kbdFile.text(), 10);
        if (isNaN(raw))
            return;

        if (kbdMaxRaw <= 0) {
            kbdMaxFile.reload();
            const max = parseInt(kbdMaxFile.text(), 10);
            if (!isNaN(max) && max > 0)
                kbdMaxRaw = max;
        }

        if (kbdMaxRaw > 0 && kbdLastRaw >= 0 && raw !== kbdLastRaw)
            flashKeyboard(Math.round(raw / kbdMaxRaw * 100));

        kbdLastRaw = raw;
    }

    // Keep the audio nodes bound so their volume/mute changes are visible.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Timer {
        interval: 1200
        running: true
        onTriggered: osd.ready = true
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: {
            osd.closing = true;
            if (osd.reveal > 0) {
                osd.animateReveal(0);
            } else {
                osd.shown = false;
                osd.closing = false;
            }
        }
    }

    Connections {
        target: osd.ready ? osd.sinkAudio : null

        function onVolumeChanged() {
            if (osd.sinkAudio)
                osd.flash("volume");
        }

        function onMutedChanged() {
            if (osd.sinkAudio)
                osd.flash("volume");
        }
    }

    Connections {
        target: osd.ready ? osd.sourceAudio : null

        function onVolumeChanged() {
            if (osd.sourceAudio)
                osd.flash("mic");
        }

        function onMutedChanged() {
            if (osd.sourceAudio)
                osd.flash("mic");
        }
    }

    Process {
        id: backlightProbe
        command: ["sh", "-c", "ls /sys/class/backlight 2>/dev/null | head -n1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim();
                if (name.length > 0)
                    osd.backlightDir = "/sys/class/backlight/" + name;
            }
        }

        Component.onCompleted: running = true
    }

    FileView {
        id: brightnessFile
        path: osd.backlightDir === "" ? "" : osd.backlightDir + "/brightness"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: maxFile
        path: osd.backlightDir === "" ? "" : osd.backlightDir + "/max_brightness"
        preload: true
        blockLoading: true
        printErrors: false
    }

    Process {
        id: kbdProbe
        command: ["sh", "-c", "ls /sys/class/leds 2>/dev/null | grep -i kbd_backlight | head -n1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim();
                if (name.length > 0)
                    osd.kbdDir = "/sys/class/leds/" + name;
            }
        }

        Component.onCompleted: running = true
    }

    FileView {
        id: kbdFile
        path: osd.kbdDir === "" ? "" : osd.kbdDir + "/brightness"
        preload: true
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: kbdMaxFile
        path: osd.kbdDir === "" ? "" : osd.kbdDir + "/max_brightness"
        preload: true
        blockLoading: true
        printErrors: false
    }

    Timer {
        interval: 100
        repeat: true
        running: osd.backlightDir !== "" || osd.kbdDir !== ""
        onTriggered: {
            osd.pollBrightness();
            osd.pollKeyboard();
        }
    }

    PanelWindow {
        id: window

        visible: osd.shown
        screen: osd.focusedScreen
        anchors {
            bottom: true
            left: true
        }
        margins {
            left: osd.focusedScreen
                ? Math.max(0, (osd.focusedScreen.width - 340) / 2)
                : 0
        }
        implicitWidth: 340
        implicitHeight: 150
        exclusiveZone: 0
        color: "transparent"
        focusable: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-osd"

        Loader {
            anchors.fill: card
            z: 1000
            source: "SoftwareDimOverlay.qml"
            onLoaded: item.radius = Qt.binding(function() { return card.radius; })
        }

        Rectangle {
            anchors.fill: card
            anchors.margins: -1
            radius: card.radius + 1
            color: "#55000000"
            opacity: osd.reveal
            z: -1
        }

        Rectangle {
            id: card

            width: 340
            height: 52
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56

            radius: Theme.panelRadius
            color: Theme.panelFill(Theme.surface, "osd")
            border.width: 1
            border.color: Theme.border

            opacity: osd.reveal
            scale: 1
            // Travel the full card height plus its bottom margin so the OSD
            // enters from below the screen edge and retracts back down when
            // the hide timer fires.
            transform: Translate {
                y: (1 - osd.reveal) * (card.height + card.anchors.bottomMargin)
            }

            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            Item {
                anchors.fill: parent
                anchors.margins: 14

                Text {
                    id: iconText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd.glyph
                    font.family: Theme.font
                    font.pixelSize: 20
                    color: osd.tone
                }

                Text {
                    id: valueLabel
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: osd.valueText
                    font.family: Theme.mono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: osd.muted ? Theme.red : Theme.text
                }

                Rectangle {
                    id: track
                    anchors.left: iconText.right
                    anchors.leftMargin: 12
                    anchors.right: valueLabel.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: Theme.surfaceAlt

                    Rectangle {
                        width: track.width * osd.value
                        height: parent.height
                        radius: parent.radius
                        color: osd.muted ? Theme.dim : osd.tone

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.motionFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
