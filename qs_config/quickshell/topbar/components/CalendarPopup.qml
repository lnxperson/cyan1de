import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: popup

    property var bar
    property Item target
    property date viewMonth: new Date()

    readonly property int viewYear: viewMonth.getFullYear()
    readonly property int viewMonthIndex: viewMonth.getMonth()
    readonly property int daysInMonth: new Date(viewYear, viewMonthIndex + 1, 0).getDate()
    readonly property int firstDayOffset: (new Date(viewYear, viewMonthIndex, 1).getDay() + 6) % 7

    implicitWidth: 380
    implicitHeight: surface.contentHeight
    color: "transparent"
    visible: false

    anchor.window: bar
    anchor.rect.x: {
        if (!bar || !target)
            return 0;
        const p = target.mapToItem(bar.contentItem, 0, 0);
        return Math.round(Math.max(8, Math.min(p.x + target.width / 2 - width / 2, bar.width - width - 8)));
    }
    anchor.rect.y: bar ? bar.height + 2 : 0

    function open() { visible = true; }
    function close() { visible = false; }

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

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: prevMouse.containsMouse ? Theme.hover : "transparent"
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
            }

            Item {
                implicitWidth: 28
                implicitHeight: 28

                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: nextMouse.containsMouse ? Theme.hover : "transparent"
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
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

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
                            color: dayCell.isToday ? Theme.active : "transparent"
                            border.width: dayCell.isToday ? 1 : 0
                            border.color: Theme.accent
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: dayCell.inMonth
                            text: dayCell.day
                            font.family: Theme.mono
                            font.pixelSize: 12
                            color: dayCell.isToday ? Theme.accent : Theme.text
                        }
                    }
                }
            }
        }
    }
}
