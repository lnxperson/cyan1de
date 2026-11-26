import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

// Structured, readable view of hl.bind() statements. Each shortcut has three
// editable values: bind, command and label. Labels are stored as Hyprland bind
// descriptions in the optional third argument.
ColumnLayout {
    id: root

    property var app
    property string newBindExpr: ""

    readonly property var categories: [
        "APPLICATIONS & WINDOWS",
        "CAPTURE & UTILITIES",
        "SCREENSHOTS",
        "NAVIGATION & WORKSPACES",
        "MEDIA & HARDWARE",
        "CUSTOM"
    ]

    function matchesFilter(bind) {
        const item = bind || {};
        const text = root.app.friendlyKey(item.bind || "") + " "
            + String(item.label || "") + " "
            + root.app.friendlyAction(item.command || "");
        return root.app.keyFilter.length === 0
            || text.toLowerCase().indexOf(root.app.keyFilter) !== -1;
    }

    function categoryCount(category) {
        let count = 0;
        const binds = root.app.keybinds || [];
        for (let i = 0; i < binds.length; i++) {
            const bind = binds[i];
            if (bind.removed || !root.matchesFilter(bind)) continue;
            if (root.app.keybindCategory(bind) === category) count++;
        }
        return count;
    }

    function addNewBind() {
        root.app.addKeybind(root.newBindExpr, newCommand.text, newLabel.text);
        root.newBindExpr = "";
        newCommand.text = "";
        newLabel.text = "";
    }

    spacing: 14

    Text {
        text: "Keybindings"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Shortcuts are grouped by category. Each has a bind, a command and a label. Click a bind to record keys; Esc cancels. Labels appear in Hyprland as bind descriptions."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        TextField {
            id: search
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            placeholderText: "filter shortcuts…"
            placeholderTextColor: Theme.dim
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: 10
            selectByMouse: true
            leftPadding: 8
            rightPadding: 8
            background: Rectangle {
                color: Theme.bg
                radius: Theme.controlRadius
                border.width: 1
                border.color: search.activeFocus ? Theme.accent : Theme.border
            }
            onTextChanged: root.app.keyFilter = text.trim().toLowerCase()
        }

        Text {
            text: root.app.keybinds.length + " shortcuts"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }

    Repeater {
        model: root.categories

        delegate: SectionCard {
            id: sectionCard
            Layout.fillWidth: true
            title: modelData
            visible: root.categoryCount(modelData) > 0

            property string category: modelData

            Column {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: root.app.keybinds

                    delegate: ColumnLayout {
                        id: bindRow

                        required property int index
                        required property var modelData

                        property bool expanded: false
                        property string rawBind: bindRow.modelData.bind
                        property string rawCommand: bindRow.modelData.command
                        property string rawLabel: bindRow.modelData.label || ""

                        readonly property string flags: root.app.bindFlags(bindRow.modelData)
                        readonly property bool hidden: !root.matchesFilter(bindRow.modelData)

                        visible: !bindRow.hidden && !bindRow.modelData.removed
                            && root.app.keybindCategory(bindRow.modelData) === sectionCard.category
                        width: parent.width
                        spacing: 4

                        // ---- Readable summary ---------------------------------
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 30
                            radius: Theme.controlRadius
                            color: bindRow.expanded ? Theme.active : (summaryMouse.containsMouse ? Theme.hover : Theme.bg)
                            border.width: 1
                            border.color: bindRow.expanded ? Theme.accent : Theme.border

                            Behavior on color { ColorAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 10

                                Text {
                                    Layout.preferredWidth: 200
                                    text: root.app.friendlyKey(bindRow.rawBind)
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.accentSoft
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "→"
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    color: Theme.dim
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: bindRow.rawLabel || root.app.friendlyAction(bindRow.rawCommand)
                                    font.family: Theme.mono
                                    font.pixelSize: 11
                                    color: Theme.text
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: bindRow.flags.length > 0
                                    text: "[" + bindRow.flags + "]"
                                    font.family: Theme.mono
                                    font.pixelSize: 9
                                    color: Theme.dim
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                Text {
                                    text: bindRow.expanded ? "⌄" : "›"
                                    font.family: Theme.mono
                                    font.pixelSize: 13
                                    color: Theme.subtext
                                }
                            }

                            MouseArea {
                                id: summaryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bindRow.expanded = !bindRow.expanded
                            }
                        }

                        // ---- Three-parameter editor ---------------------------
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: bindRow.expanded
                            Layout.topMargin: 2
                            Layout.bottomMargin: 4
                            Layout.leftMargin: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                ColumnLayout {
                                    Layout.preferredWidth: 190
                                    spacing: 2

                                    Text {
                                        text: "BIND"
                                        font.family: Theme.mono
                                        font.pixelSize: 8
                                        color: Theme.dim
                                    }

                                    KeyCapture {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        app: root.app
                                        label: root.app.friendlyKey(bindRow.rawBind)
                                        onCaptured: function (expression) {
                                            root.app.setKeybind(bindRow.index, "bind", expression);
                                            bindRow.rawBind = expression;
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        text: "COMMAND"
                                        font.family: Theme.mono
                                        font.pixelSize: 8
                                        color: Theme.dim
                                    }

                                    TextField {
                                        id: commandField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        text: bindRow.rawCommand
                                        color: Theme.text
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                        selectByMouse: true
                                        leftPadding: 8
                                        rightPadding: 8
                                        background: Rectangle {
                                            color: Theme.bg
                                            radius: Theme.controlRadius
                                            border.width: 1
                                            border.color: commandField.activeFocus ? Theme.accent : Theme.border
                                        }
                                        onTextEdited: {
                                            bindRow.rawCommand = text;
                                            root.app.setKeybind(bindRow.index, "command", text);
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 190
                                    spacing: 2

                                    Text {
                                        text: "LABEL"
                                        font.family: Theme.mono
                                        font.pixelSize: 8
                                        color: Theme.dim
                                    }

                                    TextField {
                                        id: labelField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        text: bindRow.rawLabel
                                        placeholderText: "description…"
                                        placeholderTextColor: Theme.dim
                                        color: Theme.text
                                        font.family: Theme.mono
                                        font.pixelSize: 10
                                        selectByMouse: true
                                        leftPadding: 8
                                        rightPadding: 8
                                        background: Rectangle {
                                            color: Theme.bg
                                            radius: Theme.controlRadius
                                            border.width: 1
                                            border.color: labelField.activeFocus ? Theme.accent : Theme.border
                                        }
                                        onTextEdited: {
                                            bindRow.rawLabel = text;
                                            root.app.setKeybind(bindRow.index, "label", text);
                                        }
                                    }
                                }

                                SettingsButton {
                                    icon: "󰅖"
                                    danger: true
                                    Layout.alignment: Qt.AlignBottom
                                    onClicked: root.app.removeKeybind(bindRow.index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SettingsButton {
            icon: "󰉋"
            text: "Open config folder"
            onClicked: root.app.openHyprFolder()
        }

        Item { Layout.fillWidth: true }

        Text {
            text: "hyprland/keybindings.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }
}
