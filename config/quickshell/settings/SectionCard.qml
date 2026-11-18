import QtQuick
import QtQuick.Layouts

// Titled surface used to group settings on the Hyprland tabs.
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias content: body.data

    implicitWidth: 120
    implicitHeight: body.implicitHeight + 28
    radius: Theme.panelRadius
    color: Theme.surfaceAlt
    border.width: 1
    border.color: Theme.border

    ColumnLayout {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: root.title
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            color: Theme.dim
        }

        Text {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            font.family: Theme.mono
            font.pixelSize: 9
            color: Theme.dim
            wrapMode: Text.WordWrap
        }
    }
}
