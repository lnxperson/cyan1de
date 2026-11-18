import QtQuick
import Quickshell
import "."

Item {
    id: root

    property var item: null
    property var bar: null
    property bool menuWasOpen: false
    property alias menuOpen: menu.visible

    implicitWidth: 24
    implicitHeight: 24

    TrayMenu {
        id: menu
        anchorItem: root
        ownerWindow: root.bar
        handle: root.item ? root.item.menu : null
    }

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

        onPressed: function (event) {
            if (event.button === Qt.RightButton ||
                (event.button === Qt.LeftButton && root.item && root.item.onlyMenu && root.item.hasMenu)) {
                // Capture this before any focus-grab side effects can close it.
                root.menuWasOpen = TrayMenuState.current === menu && menu.visible;
            }
        }

        onClicked: function (event) {
            if (!root.item)
                return;

            if (event.button === Qt.LeftButton && root.item.onlyMenu && root.item.hasMenu) {
                root.showMenu();
            } else if (event.button === Qt.LeftButton) {
                root.item.activate();
            } else if (event.button === Qt.MiddleButton) {
                root.item.secondaryActivate();
            } else if (event.button === Qt.RightButton && root.item.hasMenu) {
                root.showMenu();
            }
        }

        onWheel: function (event) {
            if (root.item)
                root.item.scroll(event.angleDelta.y > 0 ? 1 : -1, false);
        }
    }

    function showMenu() {
        if (!root.item || !root.item.hasMenu || !root.item.menu)
            return;

        if (root.menuWasOpen || (TrayMenuState.current === menu && menu.visible)) {
            menu.hide();
            root.menuWasOpen = false;
            return;
        }

        root.menuWasOpen = false;
        menu.handle = root.item.menu;
        menu.visible = true;
    }
}
