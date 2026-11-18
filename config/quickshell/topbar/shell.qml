import QtQuick
import Quickshell
import "components"

ShellRoot {
    // Software dimmers are created before the bars so the bars stay above
    // them in the Wayland top layer.
    Variants {
        model: Quickshell.screens

        SoftwareDim {
            property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            property var modelData
            screen: modelData
        }
    }
}
