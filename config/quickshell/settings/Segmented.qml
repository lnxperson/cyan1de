import QtQuick

// Small segmented control with a single sliding highlight.
Item {
    id: root

    property var options: []       // [{ label: "Crop", value: "crop" }, ...]
    property string value: ""
    property int spacing: 6

    signal selected(string value)

    // One sliding highlight, mirroring the top bar's action indicator.
    property rect segmentHighlightRect: Qt.rect(0, 0, 0, 0)
    property bool segmentHighlightVisible: false
    property bool segmentHighlightAnimate: false

    function segmentHighlightGeometry() {
        for (let i = 0; i < segmentRepeater.count; i++) {
            const item = segmentRepeater.itemAt(i);
            if (!item || item.modelData.value !== root.value)
                continue;
            const origin = item.mapToItem(track, 0, 0);
            return Qt.rect(origin.x, origin.y, item.width, item.height);
        }
        return null;
    }

    function syncSegmentHighlight() {
        const rect = root.segmentHighlightGeometry();
        if (!rect) {
            root.segmentHighlightVisible = false;
            root.segmentHighlightAnimate = false;
            return;
        }

        if (!root.segmentHighlightVisible) {
            root.segmentHighlightAnimate = false;
            root.segmentHighlightRect = rect;
            root.segmentHighlightVisible = true;
            Qt.callLater(function () {
                if (root.segmentHighlightVisible)
                    root.segmentHighlightAnimate = true;
            });
        } else {
            root.segmentHighlightRect = rect;
        }
    }

    onValueChanged: root.syncSegmentHighlight()
    onOptionsChanged: root.syncSegmentHighlight()
    Component.onCompleted: Qt.callLater(root.syncSegmentHighlight)

    implicitWidth: track.implicitWidth
    implicitHeight: track.implicitHeight

    Item {
        id: track

        anchors.fill: parent
        implicitWidth: segmentRow.implicitWidth
        implicitHeight: segmentRow.implicitHeight

        Rectangle {
            x: root.segmentHighlightRect.x
            y: root.segmentHighlightRect.y
            width: root.segmentHighlightRect.width
            height: root.segmentHighlightRect.height
            radius: 7
            color: Theme.active
            border.width: 1
            border.color: Theme.accent
            visible: root.segmentHighlightVisible

            Behavior on x {
                enabled: root.segmentHighlightAnimate
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: root.segmentHighlightAnimate
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                enabled: root.segmentHighlightAnimate
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: root.segmentHighlightAnimate
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            id: segmentRow

            anchors.fill: parent
            spacing: root.spacing

            Repeater {
                id: segmentRepeater
                model: root.options

                delegate: Rectangle {
                    required property var modelData

                    height: 28
                    width: label.implicitWidth + 24
                    radius: 7
                    // The selected fill is the sliding highlight behind this row.
                    color: root.value === modelData.value
                        ? "transparent"
                        : (mouse.containsMouse ? Theme.hover : "transparent")
                    border.width: root.value === modelData.value ? 0 : 1
                    border.color: Theme.border
                    scale: 1 - 0.025 * (mouse.containsPress ? 1 : 0)

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on border.width { NumberAnimation { duration: Theme.motionFast } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: root.value === modelData.value ? Font.DemiBold : Font.Normal
                        color: root.value === modelData.value ? Theme.accentSoft : Theme.text

                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(modelData.value)
                    }
                }
            }
        }
    }
}
