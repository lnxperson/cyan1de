import QtQuick
import QtQuick.Layouts

// Screen capture controls. Values are read by the recorder, replay and
// screenshot helpers directly from settings.json, so no Apply is needed for
// capture behaviour itself.
ColumnLayout {
    id: root

    property var app

    spacing: 14

    Text {
        text: "Screen Capturing"
        font.family: Theme.mono
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: Theme.text
    }

    SettingLabel {
        text: "Recording, replay clips and screenshots. Capture values take effect on the next capture without Apply. The screenshot command is shared with Programs and is written when you Apply all settings."
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    SectionCard {
        Layout.fillWidth: true
        title: "ORGANIZATION"
        subtitle: "Optionally group captures by the app that was active when they were saved."

        ToggleRow {
            Layout.fillWidth: true
            label: "Organize by app folders"
            hint: "Recordings go under their folder at start; clips go under their folder when saved"
            checked: root.app.captureAppFolders
            onToggled: value => { root.app.captureAppFolders = value; root.app.queueSave() }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "AUDIO"
        subtitle: "Desktop sound and the real microphone are controlled independently for captures."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SliderField {
                Layout.fillWidth: true
                label: "Desktop audio level"
                tooltip: "Capture-only level; it does not change the system speaker volume. Above 100% boosts the input."
                from: 0
                to: 200
                stepSize: 5
                suffix: "%"
                value: root.app.captureDesktopLevel
                onMoved: value => { root.app.captureDesktopLevel = Math.round(value); root.app.queueSave() }
            }

            SettingsButton {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                icon: root.app.captureDesktopMuted ? "󰍭" : "󰍬"
                danger: root.app.captureDesktopMuted
                tooltip: root.app.captureDesktopMuted
                    ? "Unmute desktop audio" : "Mute desktop audio"
                onClicked: {
                    root.app.captureDesktopMuted = !root.app.captureDesktopMuted;
                    root.app.queueSave()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SliderField {
                Layout.fillWidth: true
                label: "Microphone level"
                tooltip: "Capture-only level; it does not change the system microphone volume. Above 100% boosts the input."
                from: 0
                to: 200
                stepSize: 5
                suffix: "%"
                value: root.app.captureMicLevel
                onMoved: value => { root.app.captureMicLevel = Math.round(value); root.app.queueSave() }
            }

            SettingsButton {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                icon: root.app.captureMicMuted ? "󰍭" : "󰍬"
                danger: root.app.captureMicMuted
                tooltip: root.app.captureMicMuted
                    ? "Unmute microphone" : "Mute microphone"
                onClicked: {
                    root.app.captureMicMuted = !root.app.captureMicMuted;
                    root.app.queueSave()
                }
            }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "RECORDINGS"
        subtitle: "Full recordings started with SUPER + ALT + R."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TextFieldRow {
                Layout.fillWidth: true
                label: "Recording folder"
                value: root.app.captureRecDir
                placeholder: "~/Videos"
                onEdited: value => root.app.setCapturePath("recording", value)
            }

            SettingsButton {
                icon: "󰉋"
                text: "Open"
                onClicked: root.app.openCapturePath(root.app.captureRecDir)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 132
                text: "Recording display"
            }

            OptionCombo {
                options: root.app.captureDisplayOptions
                labels: root.app.captureDisplayLabels
                selected: root.app.captureRecDisplay
                onPicked: value => { root.app.captureRecDisplay = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 132
                text: "Recording resolution"
            }

            OptionCombo {
                options: root.app.captureResolutionOptions
                labels: root.app.captureResolutionLabels
                selected: root.app.captureRecResolution
                onPicked: value => { root.app.captureRecResolution = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Recording refresh rate"
            from: 0
            to: 144
            stepSize: 1
            suffix: " fps"
            value: root.app.captureRecFps
            onMoved: value => { root.app.captureRecFps = Math.round(value); root.app.queueSave() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 132
                text: "Recording quality"
            }

            OptionCombo {
                options: root.app.captureQualityOptions
                labels: root.app.captureQualityLabels
                selected: root.app.captureRecQuality
                onPicked: value => { root.app.captureRecQuality = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Record audio"
            hint: "Retries video only if no audio source is available"
            checked: root.app.captureRecAudio
            onToggled: value => { root.app.captureRecAudio = value; root.app.queueSave() }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "REPLAY CLIPS"
        subtitle: "A rolling buffer keeps recent footage. Press SUPER + ALT + V to save it."

        ToggleRow {
            Layout.fillWidth: true
            label: "Replay clips"
            hint: "Keep a low-bitrate rolling buffer running in the background"
            checked: root.app.captureClipEnabled
            onToggled: value => { root.app.captureClipEnabled = value; root.app.queueSave() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TextFieldRow {
                Layout.fillWidth: true
                label: "Clip folder"
                value: root.app.captureClipDir
                placeholder: "~/Videos"
                onEdited: value => root.app.setCapturePath("clip", value)
            }

            SettingsButton {
                icon: "󰉋"
                text: "Open"
                onClicked: root.app.openCapturePath(root.app.captureClipDir)
            }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Clip length"
            from: 10
            to: 600
            stepSize: 10
            suffix: "s"
            value: root.app.captureClipSeconds
            onMoved: value => { root.app.captureClipSeconds = Math.round(value); root.app.queueSave() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 132
                text: "Clip display"
            }

            OptionCombo {
                options: root.app.captureDisplayOptions
                labels: root.app.captureDisplayLabels
                selected: root.app.captureClipDisplay
                onPicked: value => { root.app.captureClipDisplay = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 132
                text: "Clip resolution"
            }

            OptionCombo {
                options: root.app.captureResolutionOptions
                labels: root.app.captureResolutionLabels
                selected: root.app.captureClipResolution
                onPicked: value => { root.app.captureClipResolution = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        SliderField {
            Layout.fillWidth: true
            label: "Clip refresh rate"
            from: 1
            to: 144
            stepSize: 1
            suffix: " fps"
            value: root.app.captureClipFps
            onMoved: value => { root.app.captureClipFps = Math.round(value); root.app.queueSave() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 132
                text: "Clip quality"
            }

            OptionCombo {
                options: root.app.captureQualityOptions
                labels: root.app.captureQualityLabels
                selected: root.app.captureClipQuality
                onPicked: value => { root.app.captureClipQuality = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Clip audio"
            hint: "Include audio in the rolling buffer"
            checked: root.app.captureClipAudio
            onToggled: value => { root.app.captureClipAudio = value; root.app.queueSave() }
        }
    }

    SectionCard {
        Layout.fillWidth: true
        title: "SCREENSHOTS"
        subtitle: "PRINT copies a region, CTRL + PRINT saves a display, SHIFT + PRINT saves a region."

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TextFieldRow {
                Layout.fillWidth: true
                label: "Screenshot folder"
                value: root.app.captureShotDir
                placeholder: "~/Pictures"
                onEdited: value => root.app.setCapturePath("screenshot", value)
            }

            SettingsButton {
                icon: "󰉋"
                text: "Open"
                onClicked: root.app.openCapturePath(root.app.captureShotDir)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SettingLabel {
                Layout.preferredWidth: 132
                text: "Screenshot format"
            }

            OptionCombo {
                options: root.app.captureFormatOptions
                labels: root.app.captureFormatLabels
                selected: root.app.captureShotFormat
                onPicked: value => { root.app.captureShotFormat = value; root.app.queueSave() }
            }

            Item { Layout.fillWidth: true }
        }

        ToggleRow {
            Layout.fillWidth: true
            label: "Copy screenshots"
            hint: "Also copy screenshots saved to disk to the clipboard"
            checked: root.app.captureShotCopy
            onToggled: value => { root.app.captureShotCopy = value; root.app.queueSave() }
        }

        TextFieldRow {
            Layout.fillWidth: true
            label: "Screenshot command"
            value: root.app.displayProgram(root.app.progScreenshot)
            placeholder: "hyprshot"
            onEdited: value => root.app.setProgram("progScreenshot", value)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        SettingsButton {
            icon: "󰑓"
            text: "Save a clip now"
            onClicked: root.app.saveClipNow()
        }

        SettingsButton {
            icon: "󰑗"
            text: "Restart replay buffer"
            onClicked: root.app.restartReplay()
        }

        Item { Layout.fillWidth: true }

        SettingsButton {
            icon: "󰄬"
            text: "Apply all settings"
            primary: true
            onClicked: root.app.applyAll()
        }
    }
}
