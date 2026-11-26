import QtQuick

// Small segmented control with a single sliding highlight.
Item {
    id: root

    property var options: []       // [{ label: "Crop", value: "crop" }, ...]
    property string value: ""
    property int spacing: 6
    property color baseColor: Theme.surfaceAlt

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

        // Opaque segment fills and input. They stay below the highlight.
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
                    width: measure.implicitWidth + 24
                    radius: Theme.controlRadius
                    color: root.value === modelData.value
                        ? (mouse.containsMouse ? Theme.active : "transparent")
                        : (mouse.containsMouse ? Theme.hover : root.baseColor)
                    // A transparent fill with an animated border hits
                    // QTBUG-137166 and punches a hole through the window.
                    // Inactive segments use the opaque surface behind them.
                    border.width: root.value === modelData.value ? 0 : 1
                    border.color: Theme.border
                    scale: 1 - 0.025 * (mouse.containsPress ? 1 : 0)

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.motionFast
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Same metrics as the visible label, used only for width.
                    Text {
                        id: measure
                        visible: false
                        text: modelData.label
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: root.value === modelData.value ? Font.DemiBold : Font.Normal
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

        // The highlight has to sit above the opaque segment fills or the slide
        // is hidden behind them. Labels are painted above it below.
        Rectangle {
            z: 1
            x: root.segmentHighlightRect.x
            y: root.segmentHighlightRect.y
            width: root.segmentHighlightRect.width
            height: root.segmentHighlightRect.height
            radius: Theme.controlRadius
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

        // Labels live above the highlight so it never covers the text while
        // sliding between segments.
        Row {
            z: 2
            anchors.fill: parent
            spacing: root.spacing

            Repeater {
                model: root.options

                delegate: Item {
                    required property var modelData

                    height: 28
                    width: labelMeasure.implicitWidth + 24

                    Text {
                        id: labelMeasure
                        visible: false
                        text: modelData.label
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: root.value === modelData.value ? Font.DemiBold : Font.Normal
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: root.value === modelData.value ? Font.DemiBold : Font.Normal
                        color: root.value === modelData.value ? Theme.accentSoft : Theme.text

                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                    }
                }
            }
        }
    }
}
