import QtQuick
import QtQuick.Controls.Basic

// Compact dark-styled dropdown used for monitor mode / refresh choices.
ComboBox {
    id: root

    property var options: []
    property string selected: ""
    // Optional canonical-value -> display-name map (used by animation styles).
    property var labels: ({})
    signal picked(string value)

    function labelFor(value) {
        return root.labels[value] || value;
    }

    model: root.options
    currentIndex: Math.max(0, root.options.indexOf(root.selected))

    onCurrentIndexChanged: {
        if (root.options.length > 0 && currentIndex >= 0 &&
            root.options[currentIndex] !== root.selected)
            root.picked(root.options[currentIndex]);
    }

    implicitHeight: 28
    implicitWidth: 220

    background: Rectangle {
        radius: 6
        color: Theme.surfaceAlt
        border.width: 1
        border.color: root.activeFocus || root.hovered ? Theme.accent : Theme.border
    }

    contentItem: Text {
        text: root.labelFor(root.currentText)
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.text
        verticalAlignment: Text.AlignVCenter
        leftPadding: 8
        rightPadding: 22
        elide: Text.ElideRight
    }

    indicator: Text {
        text: "󰸾"
        font.family: Theme.font
        font.pixelSize: 12
        color: Theme.subtext
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
    }

    popup: Popup {
        y: root.height + 2
        width: root.width
        implicitHeight: Math.min(250, listView.contentHeight)
        padding: 2

        contentItem: ListView {
            id: listView
            model: root.model
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: ItemDelegate {
                width: listView.width
                height: 26
                highlighted: root.currentIndex === index

                contentItem: Text {
                    text: root.labelFor(modelData)
                    font.family: Theme.mono
                    font.pixelSize: 11
                    color: parent.highlighted ? Theme.accentSoft : Theme.text
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 8
                }

                background: Rectangle {
                    color: parent.highlighted ? Theme.active : "transparent"
                    radius: 4
                }

                onClicked: {
                    root.currentIndex = index;
                    root.popup.close();
                }
            }
        }

        background: Rectangle {
            color: Theme.surface
            radius: 8
            border.width: 1
            border.color: Theme.border
        }
    }
}
