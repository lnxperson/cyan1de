import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland

// Desktop notification daemon with stacked popups. State and look are shared
// with the rest of the desktop through ~/.config/quickshell/settings.json.
ShellRoot {
    id: root

    readonly property bool atTop: Theme.notifyPosition.startsWith("top")
    readonly property bool atBottom: Theme.notifyPosition.startsWith("bottom")
    readonly property bool atLeft: Theme.notifyPosition.endsWith("left")
    readonly property bool atRight: Theme.notifyPosition.endsWith("right")

    readonly property int cardWidth: 380
    readonly property int edgeMargin: 12

    property int nextKey: 1

    readonly property string historyPath: Quickshell.env("HOME") + "/.config/quickshell/notification-history.json"
    readonly property int historyLimit: 40
    property var history: []
    property int nextHistoryId: 1

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: false
        keepOnReload: false

        onNotification: notif => root.receive(notif)
    }

    ListModel { id: popupModel }
    readonly property int count: popupModel.count

    property bool windowShown: false
    property real reveal: 0
    property bool closing: false

    Behavior on reveal {
        NumberAnimation {
            duration: root.closing ? Theme.motionFast : Theme.motionBase
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: windowExitTimer
        interval: Theme.motionFast + 20
        onTriggered: {
            windowShown = false;
            closing = false;
        }
    }

    function syncWindow(): void {
        if (popupModel.count > 0) {
            windowExitTimer.stop();
            closing = false;
            windowShown = true;
            reveal = 1;
        } else if (windowShown && !closing) {
            closing = true;
            reveal = 0;
            windowExitTimer.restart();
        }
    }

    function loadHistory(): void {
        historyFile.reload();
        let list = [];
        try {
            const parsed = JSON.parse(historyFile.text());
            if (Array.isArray(parsed))
                list = parsed.slice(0, root.historyLimit);
        } catch (e) {
            list = [];
        }

        // Older history files have no id. Give each entry a stable one and
        // rewrite the file so per-entry removal works after a daemon restart.
        let nextId = 1;
        let migrated = false;
        for (let i = 0; i < list.length; i++) {
            const entry = list[i];
            const id = Number(entry && entry.id);
            if (typeof id === "number" && isFinite(id)
                && Math.floor(id) === id && id > 0) {
                if (id >= nextId)
                    nextId = id + 1;
            } else {
                entry.id = nextId++;
                migrated = true;
            }
        }
        root.nextHistoryId = nextId;
        root.history = list;
        if (migrated)
            root.writeHistory();
    }

    function writeHistory(): void {
        historyWriter.setText(JSON.stringify(root.history, null, 2) + "\n");
    }

    function clearHistory(): void {
        root.history = [];
        root.writeHistory();
    }

    function removeHistory(id): void {
        const target = Number(id);
        const next = root.history.filter(entry => Number(entry && entry.id) !== target);
        if (next.length === root.history.length)
            return;
        root.history = next;
        root.writeHistory();
    }

    function recordHistory(notif): void {
        if (!notif)
            return;
        const summary = notif.summary || "";
        const body = notif.body || "";
        if (!summary && !body)
            return;

        const entry = {
            id: root.nextHistoryId++,
            time: Math.floor(Date.now() / 1000),
            appName: notif.appName || "",
            appIcon: notif.appIcon || "",
            summary: summary,
            body: body,
            urgency: notif.urgency
        };
        root.history = [entry].concat(root.history).slice(0, root.historyLimit);
        root.writeHistory();
    }

    function indexOfKey(key: int): int {
        for (let i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).key === key)
                return i;
        }
        return -1;
    }

    function receive(notif): void {
        if (!notif)
            return;

        // Without this the server discards the notification immediately.
        notif.tracked = true;
        root.recordHistory(notif);

        const key = root.nextKey++;
        popupModel.insert(root.atBottom ? popupModel.count : 0,
            { key: key, notif: notif });

        // The client can close its own notification at any time.
        notif.closed.connect(function () { root.removeKey(key); });

        const limit = Math.max(1, Theme.notifyMaxVisible);
        if (popupModel.count > limit) {
            const oldest = root.atBottom ? 0 : popupModel.count - 1;
            root.closeKey(popupModel.get(oldest).key, "expire");
        }
        root.syncWindow();
    }

    function removeKey(key: int): void {
        const i = root.indexOfKey(key);
        if (i >= 0)
            popupModel.remove(i);
        root.syncWindow();
    }

    function closeKey(key: int, how: string): void {
        const i = root.indexOfKey(key);
        if (i < 0)
            return;
        const notif = popupModel.get(i).notif;
        popupModel.remove(i);
        if (how === "expire")
            notif.expire();
        else
            notif.dismiss();
        root.syncWindow();
    }

    function durationFor(notif): int {
        if (Theme.notifyPersistent)
            return -1;
        if (Theme.notifyTimeout > 0)
            return Theme.notifyTimeout;
        if (notif && notif.expireTimeout > 0)
            return notif.expireTimeout * 1000;
        return 5000;
    }

    function clear(): void {
        while (popupModel.count > 0)
            root.closeKey(popupModel.get(0).key, "dismiss");
        root.syncWindow();
    }

    Component.onCompleted: root.loadHistory()

    FileView {
        id: historyFile
        path: root.historyPath
        preload: true
        blockLoading: true
        printErrors: false
        onLoadedChanged: if (loaded) root.loadHistory()
    }

    FileView {
        id: historyWriter
        path: root.historyPath
        blockWrites: false
        atomicWrites: true
        printErrors: false
    }

    IpcHandler {
        target: "notifications"

        function clear(): void { root.clear() }
        function historyCount(): int { return root.history.length }
        function clearHistory(): void { root.clearHistory() }
        function removeHistory(id: int): void { root.removeHistory(id) }
        function expireAll(): void {
            while (popupModel.count > 0)
                root.closeKey(popupModel.get(0).key, "expire");
        }
        function notificationCount(): int { return root.count }
        function debug(): string {
            let s = "persistent=" + Theme.notifyPersistent
                + " timeout=" + Theme.notifyTimeout + " pos=" + Theme.notifyPosition;
            for (let i = 0; i < popupModel.count; i++) {
                const n = popupModel.get(i).notif;
                s += " | key=" + popupModel.get(i).key
                    + " duration=" + root.durationFor(n)
                    + " expireTimeout=" + (n ? n.expireTimeout : -1);
            }
            return s;
        }
    }

    Component {
        id: notificationCard

        Rectangle {
            id: card

            required property int key
            required property var notif

            readonly property string appName: card.notif ? (card.notif.appName || "") : ""
            readonly property string appIcon: card.notif ? (card.notif.appIcon || "") : ""
            readonly property string summary: card.notif ? (card.notif.summary || "") : ""
            readonly property string bodyText: card.notif ? (card.notif.body || "") : ""
            readonly property var actions: card.notif ? card.notif.actions : []
            readonly property bool iconIsGlyph: appIcon.length > 0 && appIcon.charCodeAt(0) > 0xd7ff
            readonly property int duration: root.durationFor(card.notif)

            readonly property color urgencyColor: !card.notif ? Theme.accent
                : (card.notif.urgency === NotificationUrgency.Critical ? Theme.red
                : (card.notif.urgency === NotificationUrgency.Low ? Theme.dim
                : Theme.accentAlt))

            width: root.cardWidth
            implicitHeight: content.implicitHeight + 24
            radius: Theme.panelRadius
            color: Theme.panelFill(Theme.surface, "notifications")
            border.width: 1
            border.color: Theme.border

            opacity: 0
            scale: Theme.motionEnterScale
            transform: Translate {
                x: root.atLeft ? -(1 - card.opacity) * Theme.motionEnterOffset
                    : (1 - card.opacity) * Theme.motionEnterOffset
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                NumberAnimation {
                    duration: Theme.motionBase
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }

            Component.onCompleted: {
                card.opacity = 1;
                card.scale = 1;
            }

            // Soft drop shadow.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -1
                radius: parent.radius + 1
                color: "#55000000"
                z: -2
            }

            // Click anywhere on the card to dismiss it. Hover pauses this
            // card's timer only, avoiding a shared counter that can get stuck
            // when a hovered card is destroyed.
            MouseArea {
                id: dismissArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root.closeKey(card.key, "dismiss")
            }

            // Urgency stripe.
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 3
                color: card.urgencyColor
            }

            RowLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                // Application icon: Nerd Font glyphs render as text, everything
                // else goes through the theme icon provider.
                Item {
                    visible: Theme.notifyShowAppIcon && card.appIcon !== ""
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24

                    Text {
                        anchors.fill: parent
                        visible: card.iconIsGlyph
                        text: card.appIcon
                        font.family: Theme.mono
                        font.pixelSize: 20
                        color: card.urgencyColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Image {
                        anchors.fill: parent
                        visible: !card.iconIsGlyph
                        source: card.appIcon.startsWith("file://") ? card.appIcon
                            : (card.appIcon.startsWith("/") ? "file://" + card.appIcon
                            : Quickshell.iconPath(card.appIcon, "application-x-executable"))
                        sourceSize.width: 48
                        sourceSize.height: 48
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        visible: Theme.notifyShowAppName && card.appName !== ""
                        text: card.appName
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: card.urgencyColor
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.summary
                        font.family: Theme.mono
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.text
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: card.bodyText !== ""
                        text: card.bodyText
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.subtext
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: card.actions.length > 0
                        spacing: 6

                        Repeater {
                            model: card.actions

                            delegate: Rectangle {
                                required property var modelData

                                Layout.preferredHeight: 22
                                Layout.preferredWidth: actionText.implicitWidth + 16
                                radius: 6
                                color: Theme.active
                                border.width: 1
                                border.color: Theme.border

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    text: modelData.text || ""
                                    font.family: Theme.mono
                                    font.pixelSize: 10
                                    color: Theme.accentSoft
                                    textFormat: Text.PlainText
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }
                }
            }

            Timer {
                id: expireTimer

                interval: card.duration > 0 ? card.duration : 60000
                repeat: false
                running: card.duration > 0
                    && (!Theme.notifyPauseOnHover || !dismissArea.containsMouse)
                onTriggered: root.closeKey(card.key, "expire")
            }
        }
    }

    PanelWindow {
        id: window

        visible: root.windowShown

        anchors {
            top: root.atTop
            bottom: root.atBottom
            left: root.atLeft
            right: root.atRight
        }

        implicitWidth: root.cardWidth + root.edgeMargin * 2
        implicitHeight: Math.max(1, cards.implicitHeight + root.edgeMargin * 2)
        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.motionBase
                easing.type: Easing.OutCubic
            }
        }
        exclusiveZone: 0
        color: "transparent"
        focusable: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"

        Loader {
            anchors.fill: parent
            z: 1000
            source: "SoftwareDimOverlay.qml"
        }

        Column {
            id: cards

            x: root.edgeMargin
            y: root.edgeMargin
            width: root.cardWidth
            spacing: 8
            opacity: root.reveal

            Repeater {
                model: popupModel
                delegate: notificationCard
            }
        }
    }
}
