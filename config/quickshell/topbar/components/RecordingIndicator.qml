import QtQuick
import Quickshell

// Compact status chip used inside the action status cluster before Bluetooth.
// While recording it is red with a timer and click-to-stop; in replay mode it
// is gray and shows the configured replay-buffer length instead.
Item {
    id: root

    property bool vertical: false
    property bool replayMode: false

    readonly property color chipColor: root.replayMode ? Theme.dim : Theme.red

    readonly property string timeText: {
        const total = root.replayMode
            ? ReplayState.seconds
            : RecordingState.elapsedSeconds;
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

    implicitWidth: root.vertical ? 36 : 62
    implicitHeight: root.vertical ? 44 : 26

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: root.replayMode
            ? root.chipColor
            : (mouse.containsMouse ? "#f06a6a" : root.chipColor)

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    Row {
        visible: !root.vertical
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            visible: !root.replayMode
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
                color: root.chipColor
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
        visible: root.vertical
        anchors.centerIn: parent
        spacing: 2

        Rectangle {
            visible: !root.replayMode
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
                color: root.chipColor
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
