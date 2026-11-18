import QtQuick
import QtQuick.Layouts

// Labelled on/off switch used across the Hyprland config pages.
RowLayout {
    id: root

    property string label: ""
    property bool checked: false
    property int labelWidth: 150
    property string hint: ""

    signal toggled(bool value)

    spacing: 10

    ColumnLayout {
        Layout.preferredWidth: root.labelWidth
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: root.label
            font.family: Theme.mono
            font.pixelSize: 11
            color: Theme.subtext
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            visible: root.hint !== ""
            text: root.hint
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.dim
            elide: Text.ElideRight
        }
    }

    Rectangle {
        width: 44
        height: 24
        radius: 12
        color: root.checked ? Theme.accent : Theme.bg
        border.width: 1
        border.color: root.checked ? Theme.accent : Theme.border

        Behavior on color { ColorAnimation { duration: 120 } }

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            y: 3
            width: 18
            height: 18
            radius: 9
            color: root.checked ? Theme.bg : Theme.subtext

            Behavior on x { NumberAnimation { duration: 120 } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled(!root.checked)
        }
    }

    Item { Layout.fillWidth: true }
}
