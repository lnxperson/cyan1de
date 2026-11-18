import QtQuick
import Quickshell

Item {
    id: root

    property var item: null
    property var bar: null

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse ? Theme.hover : "transparent"
    }

    Image {
        anchors.centerIn: parent
        source: root.item ? root.item.icon : ""
        sourceSize.width: 16
        sourceSize.height: 16
        smooth: true
        asynchronous: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function (event) {
            if (!root.item)
                return;

            if (event.button === Qt.LeftButton) {
                root.item.activate();
            } else if (event.button === Qt.MiddleButton) {
                root.item.secondaryActivate();
            } else if (event.button === Qt.RightButton && root.item.hasMenu && root.bar) {
                const p = root.mapToItem(root.bar.contentItem, 0, 0);
                root.item.display(root.bar, Math.round(p.x), Math.round(root.bar.height));
            }
        }

        onWheel: function (event) {
            if (root.item)
                root.item.scroll(event.angleDelta.y > 0 ? 1 : -1, false);
        }
    }
}
