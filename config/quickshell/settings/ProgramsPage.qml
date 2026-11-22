import QtQuick
import QtQuick.Layouts

// Default applications exported by programs.lua to the other modules.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Default Programs"
        font.family: Theme.mono
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Applications used by the bar, launcher and keybindings."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "APPLICATIONS"
        subtitle: "Use a command name, or a ~/ path for scripts in your home directory."

        TextFieldRow {
            Layout.fillWidth: true
            label: "Terminal"
            value: root.app.displayProgram(root.app.progTerminal)
            placeholder: "alacritty"
            onEdited: value => root.app.setProgram("progTerminal", value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "File manager"
            value: root.app.displayProgram(root.app.progFileManager)
            placeholder: "nautilus --no-default-window"
            onEdited: value => root.app.setProgram("progFileManager", value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Launcher"
            value: root.app.displayProgram(root.app.progMenu)
            placeholder: "~/.config/quickshell/launcher/toggle.sh"
            onEdited: value => root.app.setProgram("progMenu", value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Browser"
            value: root.app.displayProgram(root.app.progBrowser)
            placeholder: "firefox"
            onEdited: value => root.app.setProgram("progBrowser", value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Text editor"
            value: root.app.displayProgram(root.app.progTextEditor)
            placeholder: "gnome-text-editor"
            onEdited: value => root.app.setProgram("progTextEditor", value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Image viewer"
            value: root.app.displayProgram(root.app.progImageViewer)
            placeholder: "loupe"
            onEdited: value => root.app.setProgram("progImageViewer", value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "PDF viewer"
            value: root.app.displayProgram(root.app.progPdfViewer)
            placeholder: "papers"
            onEdited: value => root.app.setProgram("progPdfViewer", value)
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Screenshot"
            value: root.app.displayProgram(root.app.progScreenshot)
            placeholder: "hyprshot"
            onEdited: value => root.app.setProgram("progScreenshot", value)
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
            text: "hyprland/programs.lua"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }
}
