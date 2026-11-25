import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// QML-drawn SNI menu. The native QtWidgets QMenu used by item.display() cannot
// create a grabbing xdg_popup from a Wayland layer shell, so we render the
// DBusMenu contents ourselves instead.
PopupWindow {
    id: root


    property var handle: null
    property var anchorItem: null
    property var ownerWindow: null
    property var parentMenu: null
    property int edge: Edges.Bottom
    property var childMenu: null
    property real reveal: 0
    property bool closing: false

    signal dismissed()

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: hideTimer
        interval: Theme.motionFast + 20
        onTriggered: {
            root.visible = false;
            root.closing = false;
        }
    }

    function open() {
        hideTimer.stop();
        root.closing = false;
        root.visible = true;
        root.reveal = 1;
    }

    function isOpen() {
        return root.visible && !root.closing;
    }

    visible: false
    // Qt's xdg popup grab cannot be created from a layer-shell parent on
    // wlroots. HyprlandFocusGrab handles outside-click dismissal instead.
    grabFocus: false
    color: "transparent"
    implicitWidth: 244
    implicitHeight: menuColumn.implicitHeight + 8

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    anchor.item: root.anchorItem
    anchor.edges: root.edge

    function hide() {
        if (!root.visible || root.closing)
            return;

        root.closing = true;
        root.reveal = 0;
        hideTimer.start();
        if (root.childMenu)
            root.childMenu.hide();
        root.dismissed();
    }

    function closeAll() {
        let menu = root;
        while (menu) {
            const parent = menu.parentMenu;
            menu.hide();
            menu = parent;
        }
    }

    function openSubmenu(row) {
        if (!row || !row.entry || !row.entry.hasChildren)
            return;

        if (root.childMenu && root.childMenu.isOpen() && root.childMenu.handle === row.entry)
            return;

        if (root.childMenu)
            root.childMenu.hide();

        const component = Qt.createComponent(Qt.resolvedUrl("TrayMenu.qml"));
        if (component.status !== Component.Ready) {
            console.warn("TrayMenu: submenu component not ready", component.errorString());
            return;
        }

        const menu = component.createObject(null, {
            handle: row.entry,
            anchorItem: row,
            ownerWindow: root.ownerWindow,
            parentMenu: root,
            edge: Edges.Right
        });
        if (!menu) {
            console.warn("TrayMenu: could not create submenu");
            return;
        }

        root.childMenu = menu;
        menu.dismissed.connect(function () {
            if (root.childMenu === menu)
                root.childMenu = null;
        });
        menu.open();
    }

    onVisibleChanged: {
        if (visible) {
            // Submenus must not replace the top-level menu as the active one.
            if (root.parentMenu === null)
                TrayMenuState.show(root);
        } else {
            hideTimer.stop();
            root.closing = false;
            root.reveal = 0;
            TrayMenuState.clear(root);
        }
    }

    onClosed: {
        if (root.childMenu)
            root.childMenu.hide();
        root.dismissed();
    }

    HyprlandFocusGrab {
        id: focusGrab

        // Only the top-level menu grabs focus; its open submenus are included
        // in the window list so hovering into them does not dismiss the menu.
        active: root.visible && root.parentMenu === null
        windows: {
            const list = [];
            // The bar is intentionally excluded: including a layer-shell
            // window clears the grab almost immediately and breaks clicks.
            let menu = root;
            while (menu) {
                list.push(menu);
                menu = menu.childMenu;
            }
            return list;
        }
        onCleared: root.closeAll()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.hide()
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 10
        color: Theme.popupFill(Theme.surface)
        border.width: 1
        border.color: Theme.border

        opacity: root.reveal
        scale: Theme.motionEnterScale + (1 - Theme.motionEnterScale) * root.reveal
        transform: Translate {
            y: -(1 - root.reveal) * 6
        }

        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }
    }

    Column {
        id: menuColumn

        x: 4
        y: 4
        opacity: root.reveal
        transform: Translate {
            y: -(1 - root.reveal) * 6
        }
        width: root.implicitWidth - 8
        spacing: 0

        QsMenuOpener {
            id: opener
            menu: root.handle
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: row

                property var entry: modelData
                property bool isSeparator: row.entry && row.entry.isSeparator

                width: menuColumn.width
                implicitHeight: row.isSeparator ? 1 : 30

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    height: 1
                    color: Theme.border
                    visible: row.isSeparator
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.controlRadius
                    color: mouse.containsMouse ? Theme.hover : "transparent"
                    visible: !row.isSeparator

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                Text {
                    id: checkMark

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize
                    horizontalAlignment: Text.AlignHCenter
                    visible: !row.isSeparator && row.entry && row.entry.buttonType !== 0

                    text: row.entry && row.entry.checkState === Qt.Checked
                        ? "✓"
                        : (row.entry && row.entry.buttonType === 2 ? "○" : "")
                }

                Image {
                    id: itemIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize.width: 16
                    sourceSize.height: 16
                    smooth: true
                    asynchronous: true
                    source: row.entry ? row.entry.icon : ""
                    visible: !row.isSeparator && source !== "" && row.entry.buttonType === 0
                }

                Text {
                    id: label

                    anchors {
                        left: itemIcon.visible ? itemIcon.right : parent.left
                        right: chevron.left
                        verticalCenter: parent.verticalCenter
                    }
                    anchors.leftMargin: itemIcon.visible ? 8 : (checkMark.visible ? 30 : 10)
                    anchors.rightMargin: 6
                    text: row.entry ? row.entry.text : ""
                    color: row.entry && !row.entry.enabled ? Theme.dim : Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    visible: !row.isSeparator

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                Text {
                    id: chevron

                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Theme.subtext
                    font.family: Theme.font
                    font.pixelSize: Theme.barFontSize + 2
                    visible: !row.isSeparator && row.entry && row.entry.hasChildren

                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }

                Timer {
                    id: hoverTimer
                    interval: 180
                    onTriggered: root.openSubmenu(row)
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    visible: !row.isSeparator

                    onEntered: {
                        if (row.entry && row.entry.hasChildren)
                            hoverTimer.start();
                    }

                    onExited: hoverTimer.stop()

                    onClicked: {
                        if (!row.entry || !row.entry.enabled)
                            return;

                        if (row.entry.hasChildren)
                            root.openSubmenu(row);
                        else {
                            row.entry.triggered();
                            root.closeAll();
                        }
                    }
                }
            }
        }
    }

    PopupDimOverlay {
        anchors.fill: surface
        radius: surface.radius
        reveal: root.reveal
    }
}
