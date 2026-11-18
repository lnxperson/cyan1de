pragma Singleton
import QtQuick

// Tracks the single tray menu that is currently open so opening another one
// dismisses the first, just like Plasma and GNOME.
QtObject {
    property var current: null

    function show(menu) {
        if (current && current !== menu)
            current.hide();
        current = menu;
    }

    function clear(menu) {
        if (current === menu)
            current = null;
    }
}
