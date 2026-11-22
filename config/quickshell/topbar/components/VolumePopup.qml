import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

PopupWindow {
    id: popup


    property var bar
    property Item target

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinkAudio: sink ? sink.audio : null
    readonly property var sourceAudio: source ? source.audio : null

    implicitWidth: 400
    // Fixed so every action popup shares one consistent size.
    implicitHeight: 320
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: bar ? bar.actionPopupX(width) : 0
    anchor.rect.y: bar ? bar.actionPopupY(height) : 0

    function open() { surface.open(); }
    function close() { surface.close(); }

    onVisibleChanged: if (!visible) surface.reset()

    PopupSurface {
        id: surface
        window: popup
        anchors.fill: parent

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "󰕾"
                font.family: Theme.font
                font.pixelSize: 18
                color: Theme.accent
            }

            Text {
                text: "Sound"
                font.family: Theme.mono
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Item { Layout.fillWidth: true }

            Text {
                text: popup.sink ? (popup.sink.description || popup.sink.nickname || "Output") : "No output"
                font.family: Theme.mono
                font.pixelSize: 10
                color: Theme.subtext
                elide: Text.ElideRight
                Layout.maximumWidth: 150
            }
        }

        SliderRow {
            Layout.fillWidth: true
            icon: "󰓃"
            label: "Output"
            value: popup.sinkAudio ? popup.sinkAudio.volume : 0
            muted: popup.sinkAudio ? popup.sinkAudio.muted : false

            onMoved: function (value) {
                if (popup.sinkAudio)
                    popup.sinkAudio.volume = value;
            }
            onMuteToggled: {
                if (popup.sinkAudio)
                    popup.sinkAudio.muted = !popup.sinkAudio.muted;
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        SliderRow {
            Layout.fillWidth: true
            icon: "󰍬"
            label: "Microphone"
            value: popup.sourceAudio ? popup.sourceAudio.volume : 0
            muted: popup.sourceAudio ? popup.sourceAudio.muted : false
            accent: Theme.accentAlt

            onMoved: function (value) {
                if (popup.sourceAudio)
                    popup.sourceAudio.volume = value;
            }
            onMuteToggled: {
                if (popup.sourceAudio)
                    popup.sourceAudio.muted = !popup.sourceAudio.muted;
            }
        }

        Item { Layout.preferredHeight: 2 }

        PillButton {
            Layout.fillWidth: true
            icon: "󰒓"
            label: "Open audio mixer"
            onClicked: {
                Quickshell.execDetached(["pavucontrol"]);
                popup.close();
            }
        }
    }
}
