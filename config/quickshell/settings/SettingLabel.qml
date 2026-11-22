import QtQuick
import QtQuick.Controls.Basic

// A normal settings label that shows a short explanation on hover. SettingHelp
// provides the default text; callers can override it for ambiguous labels.
Text {
    id: root

    property string tooltipText: ""
    property string helpKey: text
    property string resolvedTooltip: root.tooltipText !== ""
        ? root.tooltipText : SettingHelp.textFor(root.helpKey)

    font.family: Theme.mono
    font.pixelSize: 11
    color: Theme.subtext

    MouseArea {
        id: labelMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.ArrowCursor
    }

    ToolTip {
        visible: labelMouse.containsMouse && root.resolvedTooltip !== ""
        text: root.resolvedTooltip
        delay: 250
        timeout: 6000
    }
}
