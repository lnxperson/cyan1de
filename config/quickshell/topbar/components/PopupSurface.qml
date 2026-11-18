import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property int padding: 16
    property int contentHeight: column.implicitHeight + padding * 2
    default property alias content: column.data

    radius: Theme.panelRadius
    color: Theme.surface
    border.width: 1
    border.color: Theme.border

    // Soft drop shadow, drawn inside the transparent popup surface.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        z: -1
        radius: parent.radius + 1
        color: "#55000000"
    }

    ColumnLayout {
        id: column
        x: root.padding
        y: root.padding
        width: root.width - root.padding * 2
        spacing: 12
    }
}
