import QtQuick
import Quickshell

// Compact red status chip shown only while wf-recorder is running. The rounded
// white square is the stop affordance; clicking anywhere stops the recording.
Item {
    id: root

    property bool vertical: false

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

    implicitWidth: root.vertical ? 36 : 62
    implicitHeight: root.vertical ? 44 : 26

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: mouse.containsMouse ? "#f06a6a" : Theme.red

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    }

    Row {
        visible: !root.vertical
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
        visible: root.vertical
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

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([root.toggleScript])
    }
}
