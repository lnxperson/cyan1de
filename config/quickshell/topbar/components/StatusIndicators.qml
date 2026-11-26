import QtQuick

// Compact status cluster that sits immediately before Bluetooth. Every active
// status gets its own small symbol; a trailing rule separates this cluster
// from the regular action buttons.
Flow {
    id: root

    property bool vertical: false
    property bool showSeparator: false

    flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
    spacing: 2

    RecordingIndicator {
        visible: RecordingState.active
        vertical: root.vertical
        replayMode: false
    }

    // Keep the two time chips distinct when both capture states are active.
    Item {
        visible: RecordingState.active && ReplayState.active
        width: root.vertical ? 26 : 1
        height: root.vertical ? 1 : 26

        Rectangle {
            anchors.centerIn: parent
            width: root.vertical ? 16 : 1
            height: root.vertical ? 1 : 16
            color: Theme.border
        }
    }

    RecordingIndicator {
        visible: ReplayState.active
        vertical: root.vertical
        replayMode: true
    }

    Item {
        id: idleChip
        visible: IdleState.active
        width: 26
        height: 26

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: Theme.active
            border.width: 1
            border.color: Theme.border
        }

        Text {
            anchors.centerIn: parent
            text: "󰅶"
            font.family: Theme.mono
            font.pixelSize: 13
            color: Theme.accentSoft
        }
    }

    // Flow pins raw children to the cluster's leading edge, so give the
    // separator a full-height slot and centre the rule inside it.
    Item {
        visible: root.showSeparator
        width: root.vertical ? 26 : 1
        height: root.vertical ? 1 : 26

        Rectangle {
            anchors.centerIn: parent
            width: root.vertical ? 16 : 1
            height: root.vertical ? 1 : 16
            color: Theme.border
        }
    }
}
