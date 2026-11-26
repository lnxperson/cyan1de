import QtQuick
import Quickshell

// Compact status chip shown after Bluetooth. While recording it is red with a
// timer and click-to-stop; otherwise a small gray glyph marks the rolling
// replay buffer in the exact same slot.
Item {
    id: root

    property bool vertical: false
    property bool replayMode: false

    readonly property string timeText: {
        const total = RecordingState.elapsedSeconds;
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        const seconds = total % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return hours > 0
            ? hours + ":" + pad(minutes) + ":" + pad(seconds)
            : pad(minutes) + ":" + pad(seconds);
    }

    readonly property string toggleScript: (Quickshell.env("HOME") || "")
        + "/.config/quickshell/recorder/toggle.sh"

    implicitWidth: root.replayMode
        ? (root.vertical ? 28 : 26)
        : (root.vertical ? 36 : 62)
    implicitHeight: root.replayMode
        ? (root.vertical ? 30 : 26)
        : (root.vertical ? 44 : 26)

    Rectangle {
        visible: !root.replayMode
        anchors.fill: parent
        radius: 7
        color: mouse.containsMouse ? "#f06a6a" : Theme.red

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    Row {
        visible: !root.vertical && !root.replayMode
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            width: 12
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: "#ffffff"

            Rectangle {
                anchors.centerIn: parent
                width: 5
                height: 5
                radius: 1
                color: Theme.red
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.timeText
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: "#ffffff"
        }
    }

    Column {
        visible: root.vertical && !root.replayMode
        anchors.centerIn: parent
        spacing: 2

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 12
            height: 12
            radius: 4
            color: "#ffffff"

            Rectangle {
                anchors.centerIn: parent
                width: 5
                height: 5
                radius: 1
                color: Theme.red
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: "#ffffff"
        }
    }

    Text {
        id: replayIcon
        visible: root.replayMode
        anchors.centerIn: parent
        text: "󰑓"
        font.family: Theme.mono
        font.pixelSize: 14
        color: Theme.dim
    }

    MouseArea {
        id: mouse
        visible: !root.replayMode
        enabled: !root.replayMode
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([root.toggleScript])
    }
}
