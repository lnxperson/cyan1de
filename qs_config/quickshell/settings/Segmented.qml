import QtQuick
import QtQuick.Layouts

// Small segmented control.
Row {
    id: root

    property var options: []       // [{ label: "Crop", value: "crop" }, ...]
    property string value: ""

    signal selected(string value)

    spacing: 6

    Repeater {
        model: root.options

        delegate: Rectangle {
            required property var modelData

            height: 28
            width: label.implicitWidth + 24
            radius: 7
            color: root.value === modelData.value
                ? Theme.active
                : (mouse.containsMouse ? Theme.hover : "transparent")
            border.width: 1
            border.color: root.value === modelData.value ? Theme.accent : Theme.border

            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                id: label
                anchors.centerIn: parent
                text: modelData.label
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: root.value === modelData.value ? Font.DemiBold : Font.Normal
                color: root.value === modelData.value ? Theme.accentSoft : Theme.text
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
