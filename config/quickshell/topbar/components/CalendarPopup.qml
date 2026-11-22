import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup


    property var bar
    property Item target
    property date viewMonth: new Date()
    property alias popupSurface: surface

    readonly property int viewYear: viewMonth.getFullYear()
    readonly property int viewMonthIndex: viewMonth.getMonth()
    readonly property int daysInMonth: new Date(viewYear, viewMonthIndex + 1, 0).getDate()
    readonly property int firstDayOffset: (new Date(viewYear, viewMonthIndex, 1).getDay() + 6) % 7

    implicitWidth: Math.max(380, Theme.calendarWidth)
    // Fixed so the popup height stays stable while its contents load.
    implicitHeight: 510
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: bar ? bar.popupX(target, width, "center") : 0
    anchor.rect.y: bar ? bar.popupY(target, height, "center") : 0

    function open() { surface.open(); }
    function close() { surface.close(); }

    onVisibleChanged: if (!visible) surface.reset()

    function shiftMonth(delta) {
        viewMonth = new Date(viewYear, viewMonthIndex + delta, 1);
    }

    function resetMonth() {
        viewMonth = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1);
    }

    Component.onCompleted: resetMonth()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    PopupSurface {
        id: surface
        window: popup
        owner: popup
        anchors.fill: parent
        padding: 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                spacing: 0

                Text {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.family: Theme.mono
                    font.pixelSize: 40
                    font.weight: Font.Light
                    color: Theme.text
                }

                Text {
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: Theme.subtext
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.border
        }

        // Media can sit above or below the calendar. The header and divider
        // above always stay first.
        Item {
            id: mediaTopSlot
            Layout.fillWidth: true
            implicitHeight: Theme.calendarMedia
                && Theme.calendarMediaPosition === "top"
                ? mediaControls.implicitHeight : 0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            layoutDirection: Theme.calendarNotificationsSide === "left"
                ? Qt.RightToLeft : Qt.LeftToRight

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 306
                Layout.maximumWidth: 306
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: Qt.formatDate(popup.viewMonth, "MMMM yyyy")
                        font.family: Theme.mono
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Item { Layout.fillWidth: true }

                    PillButton {
                        label: "Today"
                        onClicked: popup.resetMonth()
                    }

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28
                        property bool keyboardFocused: false
                        activeFocusOnTab: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: prevMouse.containsMouse || parent.activeFocus
                                || parent.keyboardFocused ? Theme.hover : "transparent"
                            border.width: parent.activeFocus || parent.keyboardFocused ? 1 : 0
                            border.color: Theme.accentSoft

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            font.family: Theme.font
                            font.pixelSize: 14
                            color: Theme.subtext
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.shiftMonth(-1)
                        }

                        function keyboardActivate() { popup.shiftMonth(-1); }

                        Keys.onReturnPressed: {
                            event.accepted = true;
                            popup.shiftMonth(-1);
                        }

                        Keys.onSpacePressed: {
                            event.accepted = true;
                            popup.shiftMonth(-1);
                        }
                    }

                    Item {
                        implicitWidth: 28
                        implicitHeight: 28
                        property bool keyboardFocused: false
                        activeFocusOnTab: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: nextMouse.containsMouse || parent.activeFocus
                                || parent.keyboardFocused ? Theme.hover : "transparent"
                            border.width: parent.activeFocus || parent.keyboardFocused ? 1 : 0
                            border.color: Theme.accentSoft

                            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            font.family: Theme.font
                            font.pixelSize: 14
                            color: Theme.subtext
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popup.shiftMonth(1)
                        }

                        function keyboardActivate() { popup.shiftMonth(1); }

                        Keys.onReturnPressed: {
                            event.accepted = true;
                            popup.shiftMonth(1);
                        }

                        Keys.onSpacePressed: {
                            event.accepted = true;
                            popup.shiftMonth(1);
                        }
                    }
                }

                Row {
                    spacing: 2

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        Text {
                            required property string modelData
                            width: 42
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: Theme.mono
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.dim
                        }
                    }
                }

                Grid {
                    columns: 7
                    spacing: 2

                    Repeater {
                        model: 42

                        Item {
                            id: dayCell
                            required property int index

                            readonly property int day: index - popup.firstDayOffset + 1
                            readonly property bool inMonth: day >= 1 && day <= popup.daysInMonth
                            readonly property bool isToday: inMonth
                                && day === clock.date.getDate()
                                && popup.viewMonthIndex === clock.date.getMonth()
                                && popup.viewYear === clock.date.getFullYear()

                            width: 42
                            height: 34

                            Rectangle {
                                anchors.centerIn: parent
                                width: 32
                                height: 28
                                radius: 7
                                color: dayCell.isToday
                                    ? Theme.active
                                    : (dayMouse.containsMouse ? Theme.hover : "transparent")
                                border.width: dayCell.isToday ? 1 : 0
                                border.color: Theme.accent
                                scale: dayCell.isToday
                                    ? 1.06 : (dayMouse.containsMouse ? 1.03 : 1)

                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                                Behavior on border.width {
                                    NumberAnimation { duration: Theme.motionFast }
                                }
                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Theme.motionFast
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: dayCell.inMonth
                                text: dayCell.day
                                font.family: Theme.mono
                                font.pixelSize: 12
                                color: dayCell.isToday
                                    ? Theme.accent
                                    : (dayMouse.containsMouse ? Theme.accentSoft : Theme.text)

                                Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                hoverEnabled: dayCell.inMonth
                                cursorShape: dayCell.inMonth
                                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Theme.border
                visible: Theme.calendarNotifications
            }

            NotificationHistory {
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignTop
                visible: Theme.calendarNotifications
            }
        }

        Item {
            id: mediaBottomSlot
            Layout.fillWidth: true
            implicitHeight: Theme.calendarMedia
                && Theme.calendarMediaPosition !== "top"
                ? mediaControls.implicitHeight : 0
        }
    }

    MediaControls {
        id: mediaControls
        parent: Theme.calendarMediaPosition === "top"
            ? mediaTopSlot : mediaBottomSlot
        anchors.fill: parent
    }
}
