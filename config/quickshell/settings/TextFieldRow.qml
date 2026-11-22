import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Labelled single-line text field used across the Hyprland config pages.
RowLayout {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""
    property int labelWidth: 132
    property bool monoValue: true
    property string tooltip: ""

    signal edited(string value)

    spacing: 10

    SettingLabel {
        Layout.preferredWidth: root.labelWidth
        text: root.label
        tooltipText: root.tooltip
        elide: Text.ElideRight
    }

    TextField {
        id: field

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        text: root.value
        placeholderText: root.placeholder
        placeholderTextColor: Theme.dim
        color: root.monoValue ? Theme.accentSoft : Theme.text
        font.family: Theme.mono
        font.pixelSize: 11
        selectByMouse: true
        leftPadding: 8
        rightPadding: 8
        background: Rectangle {
            color: Theme.bg
            radius: 6
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.border
        }

        Component.onCompleted: text = root.value

        // Commit on every keystroke so clicking Apply without pressing Enter
        // never drops the edit.
        onTextEdited: root.edited(text)
        onEditingFinished: {
            if (text !== root.value)
                root.edited(text);
        }
    }

    onValueChanged: {
        if (field.text !== root.value)
            field.text = root.value;
    }
}
