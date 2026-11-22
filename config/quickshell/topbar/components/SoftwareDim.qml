import QtQuick
import Quickshell
import Quickshell.Wayland

// Full-output software dimmer for monitors that cannot be controlled over
// DDC/CI. The surface is click-through and never takes keyboard focus, so the
// desktop remains fully usable underneath it. It must be created after the
// bar in shell.qml so it stacks above the bar on the overlay layer.
PanelWindow {
    id: dim

    property var modelData

    readonly property string outputName: screen ? screen.name : ""
    readonly property int level: Brightness.percentForScreen(outputName)
    readonly property real opacityAmount: (100 - level) / 100

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    visible: Brightness.hasSoftwareForScreen(outputName) && level < 100

    color: Qt.rgba(0, 0, 0, opacityAmount)
    focusable: false
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-softdim-" + outputName
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Empty input region: pointer events pass through to the windows below.
    mask: Region {
        intersection: Intersection.Subtract
        x: 0
        y: 0
        width: dim.width
        height: dim.height
    }
}
