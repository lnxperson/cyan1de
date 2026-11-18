import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Hex colour field with a live swatch and optional preset swatches.
RowLayout {
    id: root

    property string label: ""
    property string value: "#ffffff"
    property var presets: []

    signal edited(string value)

    spacing: 10

    Text {
        Layout.preferredWidth: 132
        text: root.label
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.subtext
        elide: Text.ElideRight
    }

    Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 6
        color: root.value
        border.width: 1
        border.color: "#40ffffff"
    }

    TextField {
        id: field
        Layout.preferredWidth: 96
        Layout.preferredHeight: 28
        text: root.value
        color: Theme.text
        font.family: Theme.mono
        font.pixelSize: 11
        horizontalAlignment: TextInput.AlignHCenter
        selectByMouse: true
        leftPadding: 6
        rightPadding: 6
        background: Rectangle {
            color: Theme.surfaceAlt
            radius: 6
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.border
        }

        Component.onCompleted: text = root.value

        function commit() {
            let v = text.trim().toLowerCase();
            if (!v.startsWith("#"))
                v = "#" + v;
            if (/^#[0-9a-f]{6}$/.test(v)) {
                field.text = v;
                root.edited(v);
            } else {
                field.text = root.value;
            }
        }

        // Commit valid hex as it is typed so Apply never misses an edit.
        onTextEdited: {
            let v = text.trim().toLowerCase();
            if (!v.startsWith("#"))
                v = "#" + v;
            if (/^#[0-9a-f]{6}$/.test(v))
                root.edited(v);
        }
        onEditingFinished: commit()
        Keys.onReturnPressed: commit()
        Keys.onEnterPressed: commit()
    }

    Row {
        visible: root.presets.length > 0
        spacing: 5
        Layout.alignment: Qt.AlignVCenter

        Repeater {
            model: root.presets

            delegate: Rectangle {
                required property string modelData

                width: 16
                height: 16
                radius: 8
                color: modelData
                border.width: root.value === modelData ? 2 : 1
                border.color: root.value === modelData ? Theme.text : "#30ffffff"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.edited(modelData)
                }
            }
        }
    }

    Item { Layout.fillWidth: true }

    onValueChanged: {
        if (field.text !== root.value)
            field.text = root.value;
    }
}
