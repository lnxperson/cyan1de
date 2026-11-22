import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Labelled slider with a value readout.
RowLayout {
    id: root

    property string label: ""
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property string suffix: ""
    property int decimals: 0
    property string tooltip: ""

    signal moved(real value)

    spacing: 10

    SettingLabel {
        Layout.preferredWidth: 132
        text: root.label
        tooltipText: root.tooltip
        elide: Text.ElideRight
    }

    Slider {
        id: slider

        Layout.fillWidth: true
        Layout.preferredHeight: 24
        from: root.from
        to: root.to
        stepSize: root.stepSize
        value: root.value

        background: Rectangle {
            x: 0
            y: (parent.height - height) / 2
            width: parent.width
            height: 4
            radius: 2
            color: Theme.surfaceAlt

            Rectangle {
                width: parent.width * slider.visualPosition
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }

        handle: Rectangle {
            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
            y: slider.topPadding + (slider.availableHeight - height) / 2
            width: 14
            height: 14
            radius: 7
            color: slider.pressed ? Theme.accentSoft : Theme.accent
            border.width: 2
            border.color: Theme.bg
        }

        onMoved: root.moved(value)
    }

    Text {
        Layout.preferredWidth: 56
        text: Number(root.value).toFixed(root.decimals) + root.suffix
        font.family: Theme.mono
        font.pixelSize: 11
        color: Theme.text
        horizontalAlignment: Text.AlignRight
    }

    onValueChanged: {
        if (Math.abs(slider.value - root.value) > 0.0001)
            slider.value = root.value;
    }
}
