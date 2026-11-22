import QtQuick

// Click-to-record shortcut field. Captures the next non-modifier key press and
// emits a Hyprland-ready Lua expression such as `mainMod .. " + RETURN"`.
Rectangle {
    id: root

    property var app: null
    property string label: ""
    property string placeholder: "click to record…"
    property bool capturing: false

    signal captured(string expression)

    readonly property string displayText: {
        if (root.capturing)
            return "Press keys…";
        const text = String(root.label || "").trim();
        return text.length > 0 ? text : root.placeholder;
    }

    activeFocusOnTab: true

    color: root.capturing
        ? Theme.active
        : (captureMouse.containsMouse ? Theme.hover : Theme.bg)
    radius: 6
    border.width: 1
    border.color: root.capturing
        ? Theme.accentAlt
        : (root.activeFocus ? Theme.accent : Theme.border)

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    function begin() {
        root.capturing = true;
        if (root.app)
            root.app.captureOwner = root;
        root.forceActiveFocus();
    }

    function stop() {
        root.capturing = false;
        if (root.app && root.app.captureOwner === root)
            root.app.captureOwner = null;
    }

    function keyName(key: int): string {
        switch (key) {
        case Qt.Key_Shift:
        case Qt.Key_Control:
        case Qt.Key_Alt:
        case Qt.Key_Meta:
            return "";
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return "RETURN";
        case Qt.Key_Space:
            return "SPACE";
        case Qt.Key_Tab:
            return "TAB";
        case Qt.Key_Backspace:
            return "BACKSPACE";
        case Qt.Key_Delete:
            return "DELETE";
        case Qt.Key_Insert:
            return "INSERT";
        case Qt.Key_Home:
            return "HOME";
        case Qt.Key_End:
            return "END";
        case Qt.Key_PageUp:
            return "PAGEUP";
        case Qt.Key_PageDown:
            return "PAGEDOWN";
        case Qt.Key_Left:
            return "left";
        case Qt.Key_Right:
            return "right";
        case Qt.Key_Up:
            return "up";
        case Qt.Key_Down:
            return "down";
        case Qt.Key_Escape:
            return "ESCAPE";
        case Qt.Key_Print:
            return "PRINT";
        case Qt.Key_Pause:
            return "PAUSE";
        case Qt.Key_CapsLock:
            return "CAPSLOCK";
        case Qt.Key_NumLock:
            return "NUMLOCK";
        case Qt.Key_ScrollLock:
            return "SCROLLLOCK";
        case Qt.Key_Comma:
            return "comma";
        case Qt.Key_Period:
            return "period";
        case Qt.Key_Slash:
            return "slash";
        case Qt.Key_Semicolon:
            return "semicolon";
        case Qt.Key_Apostrophe:
            return "apostrophe";
        case Qt.Key_BracketLeft:
            return "bracketleft";
        case Qt.Key_BracketRight:
            return "bracketright";
        case Qt.Key_Backslash:
            return "backslash";
        case Qt.Key_Minus:
            return "minus";
        case Qt.Key_Equal:
            return "equal";
        case Qt.Key_QuoteLeft:
            return "grave";
        case Qt.Key_VolumeUp:
            return "XF86AudioRaiseVolume";
        case Qt.Key_VolumeDown:
            return "XF86AudioLowerVolume";
        case Qt.Key_VolumeMute:
            return "XF86AudioMute";
        case Qt.Key_MonBrightnessUp:
            return "XF86MonBrightnessUp";
        case Qt.Key_MonBrightnessDown:
            return "XF86MonBrightnessDown";
        case Qt.Key_KeyboardLightOnOff:
            return "XF86KbdLightOnOff";
        case Qt.Key_KeyboardBrightnessUp:
            return "XF86KbdBrightnessUp";
        case Qt.Key_KeyboardBrightnessDown:
            return "XF86KbdBrightnessDown";
        case Qt.Key_MediaPlay:
            return "XF86AudioPlay";
        case Qt.Key_MediaPause:
            return "XF86AudioPause";
        case Qt.Key_MediaNext:
            return "XF86AudioNext";
        case Qt.Key_MediaPrevious:
            return "XF86AudioPrev";
        case Qt.Key_MediaStop:
            return "XF86AudioStop";
        }

        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(Qt.Key_A + (key - Qt.Key_A));

        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(Qt.Key_0 + (key - Qt.Key_0));

        if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
            return "F" + (key - Qt.Key_F1 + 1);

        return "";
    }

    function expressionFor(event: var, name: string): string {
        const mods = [];
        if (event.modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        if (event.modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            mods.push("ALT");
        mods.push(name);

        // mainMod is defined at the top of keybindings.lua. Keeping it in
        // generated expressions preserves the existing config conventions.
        if (mods[0] === "SUPER")
            return "mainMod .. \" + " + mods.slice(1).join(" + ") + "\"";

        return "\"" + mods.join(" + ") + "\"";
    }

    Keys.enabled: root.capturing
    Keys.onPressed: function (event) {
        if (!root.capturing)
            return;

        event.accepted = true;

        if (event.isAutoRepeat)
            return;

        // Escape cancels instead of being recorded, so a mis-click never
        // replaces a binding with an unintended one.
        if (event.key === Qt.Key_Escape) {
            root.stop();
            return;
        }

        const name = root.keyName(event.key);
        if (name.length === 0)
            return;

        const expression = root.expressionFor(event, name);
        root.captured(expression);
        root.stop();
    }

    onActiveFocusChanged: {
        if (!activeFocus && root.capturing)
            root.stop();
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 12
        text: root.displayText
        font.family: Theme.mono
        font.pixelSize: 10
        color: root.capturing
            ? Theme.accentAlt
            : (root.displayText === root.placeholder ? Theme.dim : Theme.accentSoft)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        id: captureMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.capturing)
                root.stop();
            else
                root.begin();
        }
    }
}
