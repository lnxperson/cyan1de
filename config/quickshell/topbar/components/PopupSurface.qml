import QtQuick
import QtQuick.Layouts
import QtQuick.Window

Rectangle {
    id: root

    property int padding: 16
    default property alias content: column.data

    // PopupWindow visibility is a hard cut, so the surface owns a short
    // reveal animation and delays the actual window hide until it finishes.
    property var window: null
    // Action popups live inside one persistent PopupWindow. The host controls
    // that window's visibility so one surface's hide timer cannot close another.
    property var controller: null
    property var owner: null
    property bool manageWindow: true
    property real reveal: 0
    property bool closing: false

    // Action-section switches slide the content sideways instead of fading one
    // whole window out and another in. The direction and axis follow the
    // movement of the sliding action indicator in the bar.
    property bool sliding: false
    property bool slideHorizontal: true
    property real slideOffset: 0
    property int hideDelay: Theme.motionFast + 20

    // Keyboard navigation lives here so every popup gets the same Tab/arrow
    // behaviour without each popup owning its own key handling.
    property bool keyboardNavigation: true
    property bool keyboardPassthrough: false
    property int keyboardIndex: -1
    focus: true
    activeFocusOnTab: false

    readonly property string attachEdge: root.window && root.window.bar
        ? root.window.bar.edge : ""
    readonly property int enterX: root.attachEdge === "left"
        ? -Theme.motionEnterOffset
        : (root.attachEdge === "right" ? Theme.motionEnterOffset : 0)
    readonly property int enterY: root.attachEdge === "top"
        ? -Theme.motionEnterOffset
        : (root.attachEdge === "bottom" ? Theme.motionEnterOffset : 0)

    radius: Theme.panelRadius
    color: Theme.popupFill(Theme.surface)
    border.width: 1
    border.color: Theme.border

    opacity: root.reveal
    scale: Theme.motionEnterScale + (1 - Theme.motionEnterScale) * root.reveal
    transform: Translate {
        x: root.enterX * (1 - root.reveal) + (root.slideHorizontal ? root.slideOffset : 0)
        y: root.enterY * (1 - root.reveal) + (root.slideHorizontal ? 0 : root.slideOffset)
    }

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    Behavior on slideOffset {
        enabled: root.sliding
        NumberAnimation {
            duration: Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

    function focusedItem() {
        const list = root.sortedCandidates();
        if (root.keyboardIndex >= 0 && root.keyboardIndex < list.length)
            return list[root.keyboardIndex];
        const active = Window.window ? Window.window.activeFocusItem : null;
        return active && list.indexOf(active) >= 0 ? active : null;
    }

    function isTextEntry(item) {
        if (!item)
            return false;
        try {
            return typeof item.cursorPosition === "number"
                || typeof item.echoMode === "number";
        } catch (e) {
            return false;
        }
    }

    function isActuallyVisible(item) {
        let cur = item;
        while (cur && cur !== root) {
            if (!cur.visible || cur.enabled === false || cur.opacity <= 0.001)
                return false;
            cur = cur.parent;
        }
        return true;
    }

    function collectFocusable(item, out) {
        const children = item.children || [];
        for (let i = 0; i < children.length; i++) {
            const child = children[i];
            if (child.activeFocusOnTab === true
                && child.enabled !== false
                && root.isActuallyVisible(child))
                out.push(child);
            root.collectFocusable(child, out);
        }
    }

    function focusCandidates() {
        const out = [];
        root.collectFocusable(root, out);
        return out;
    }

    function rectOf(item) {
        const p = item.mapToItem(root, 0, 0);
        return {
            x: p.x, y: p.y,
            w: item.width, h: item.height,
            cx: p.x + item.width / 2,
            cy: p.y + item.height / 2
        };
    }

    function readingOrder(a, b) {
        const ra = root.rectOf(a);
        const rb = root.rectOf(b);
        if (Math.abs(ra.y - rb.y) > 8)
            return ra.y - rb.y;
        return ra.x - rb.x;
    }

    function sortedCandidates() {
        return root.focusCandidates().sort(root.readingOrder);
    }

    function applyKeyboardFocus() {
        const list = root.sortedCandidates();
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            if (typeof item.keyboardFocused !== "undefined")
                item.keyboardFocused = i === root.keyboardIndex
                    && !root.isTextEntry(item);
        }
    }

    function clearKeyboardFocus() {
        root.keyboardIndex = -1;
        root.applyKeyboardFocus();
    }

    function focusItem(item) {
        if (!item)
            return false;
        const list = root.sortedCandidates();
        const index = list.indexOf(item);
        if (index < 0)
            return false;
        root.keyboardIndex = index;
        if (root.isTextEntry(item))
            item.forceActiveFocus(Qt.TabFocusReason);
        root.applyKeyboardFocus();
        return true;
    }

    function focusFirst() {
        const list = root.sortedCandidates();
        if (list.length)
            root.focusItem(list[0]);
        else
            root.clearKeyboardFocus();
    }

    function moveFocus(delta) {
        const list = root.sortedCandidates();
        if (!list.length)
            return;
        let index = root.keyboardIndex;
        if (index < 0 || index >= list.length)
            index = delta > 0 ? -1 : 0;
        index = (index + delta + list.length) % list.length;
        root.focusItem(list[index]);
    }

    function moveFocusDirection(key) {
        const list = root.sortedCandidates();
        if (!list.length)
            return;

        const current = root.focusedItem();
        if (!current) {
            root.focusItem(key === Qt.Key_Left || key === Qt.Key_Up
                ? list[list.length - 1] : list[0]);
            return;
        }

        const origin = root.rectOf(current);
        let best = null;
        let bestScore = Infinity;

        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            if (item === current)
                continue;
            const r = root.rectOf(item);
            let primary = 0;
            let cross = 0;

            if (key === Qt.Key_Right) {
                primary = r.cx - origin.cx;
                cross = Math.abs(r.cy - origin.cy);
            } else if (key === Qt.Key_Left) {
                primary = origin.cx - r.cx;
                cross = Math.abs(r.cy - origin.cy);
            } else if (key === Qt.Key_Down) {
                primary = r.cy - origin.cy;
                cross = Math.abs(r.cx - origin.cx);
            } else {
                primary = origin.cy - r.cy;
                cross = Math.abs(r.cx - origin.cx);
            }
            if (primary <= 1)
                continue;

            const score = primary + cross * 2;
            if (score < bestScore) {
                bestScore = score;
                best = item;
            }
        }

        if (!best)
            best = (key === Qt.Key_Left || key === Qt.Key_Up)
                ? list[list.length - 1] : list[0];
        root.focusItem(best);
    }

    function activateFocused() {
        const item = root.focusedItem();
        if (!item)
            return;
        if (typeof item.keyboardActivate === "function")
            item.keyboardActivate();
        else if (typeof item.clicked === "function")
            item.clicked();
    }

    function closeOwner() {
        if (root.owner && typeof root.owner.close === "function")
            root.owner.close();
    }

    function handleKey(event) {
        if (!root.keyboardNavigation || root.keyboardPassthrough
            || event.accepted)
            return;

        // Text fields keep their own cursor keys and Escape behaviour.
        if (root.isTextEntry(root.focusedItem()))
            return;

        if (event.key === Qt.Key_Escape) {
            root.closeOwner();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            || event.key === Qt.Key_Space) {
            root.activateFocused();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.moveFocus(event.key === Qt.Key_Backtab
                || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
            || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            root.moveFocusDirection(event.key);
            event.accepted = true;
        }
    }

    Keys.onPressed: function (event) {
        root.handleKey(event);
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: {
            if (root.controller)
                root.controller.surfaceHidden(root);
            else {
                if (root.owner)
                    root.owner.visible = false;
                if (root.manageWindow && root.window)
                    root.window.visible = false;
            }
            root.closing = false;
            root.sliding = false;
            root.slideOffset = 0;
        }
    }

    function ensureVisible() {
        if (root.controller)
            root.controller.ensureVisible();
        else if (root.manageWindow && root.window)
            root.window.visible = true;
    }

    function slideDistance(horizontal) {
        return horizontal ? root.width : root.height;
    }

    function open() {
        hideTimer.stop();
        root.closing = false;
        root.sliding = false;
        root.slideOffset = 0;
        root.hideDelay = Theme.motionFast + 20;
        root.ensureVisible();
        root.reveal = 1;
        Qt.callLater(root.focusFirst);
    }

    function close() {
        if (!root.window || !root.window.visible || root.closing)
            return;
        root.closing = true;
        root.hideDelay = Theme.motionFast + 20;
        root.reveal = 0;
        root.clearKeyboardFocus();
        hideTimer.start();
    }

    // Bring a popup in from the side the action indicator is travelling from.
    function slideIn(direction, horizontal) {
        hideTimer.stop();
        root.closing = false;
        root.hideDelay = Theme.motionBase + 30;
        root.slideHorizontal = horizontal;
        root.sliding = false;
        root.slideOffset = direction * root.slideDistance(horizontal);
        root.sliding = true;
        root.ensureVisible();
        root.reveal = 1;
        Qt.callLater(root.focusFirst);
        Qt.callLater(function () {
            if (root.sliding)
                root.slideOffset = 0;
        });
    }

    // Move the previous content out in the same direction, without the generic
    // fade so the two surfaces read as one sliding panel.
    function slideOut(direction, horizontal) {
        if (!root.window || !root.window.visible || root.closing)
            return;
        root.closing = true;
        root.hideDelay = Theme.motionBase + 30;
        root.slideHorizontal = horizontal;
        root.sliding = true;
        root.slideOffset = -direction * root.slideDistance(horizontal);
        root.clearKeyboardFocus();
        hideTimer.start();
    }

    // Used when the PopupWindow is hidden outside of close(), for example by
    // the compositor dismissing it. Keeps the next open animated.
    function reset() {
        hideTimer.stop();
        root.closing = false;
        root.sliding = false;
        root.slideOffset = 0;
        root.reveal = 0;
        root.clearKeyboardFocus();
    }

    // Soft drop shadow, drawn inside the transparent popup surface.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        z: -1
        radius: parent.radius + 1
        color: "#55000000"
    }

    Flickable {
        id: flick
        anchors {
            fill: parent
            margins: root.padding
        }
        clip: true
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: column.width
        contentHeight: Math.max(flick.height, column.implicitHeight)

        ColumnLayout {
            id: column
            width: flick.width
            height: Math.max(flick.height, implicitHeight)
            spacing: 12
        }
    }

    PopupDimOverlay {
        anchors.fill: parent
        radius: parent.radius
        reveal: root.reveal
        active: root.reveal > 0 && (!root.window || root.window.visible)
    }
}
