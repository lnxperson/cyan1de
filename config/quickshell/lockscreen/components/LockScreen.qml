import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: root

    property var lock: null
    property var screen: null
    property string wallpaperPath: ""

    property bool unlocking: false
    property bool fpAvailable: false
    property bool fpWorking: false
    property string message: "Enter your password"
    property bool messageError: false
    property string queuedPassword: ""
    property string hostname: ""
    property real reveal: 0

    signal unlocked()

    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    // Let the shared theme finish its first settings read before the reveal,
    // so the lock screen never pops in with the fallback palette.
    Timer {
        id: revealTimer
        interval: 120
        onTriggered: root.reveal = 1
    }

    Timer {
        id: unlockTimer
        interval: Theme.motionBase + 40
        onTriggered: {
            if (lock)
                lock.locked = false;
            else
                console.warn("LockScreen: session lock object is missing; the compositor will unlock only when the process exits");
            unlocked();
        }
    }

    Component.onCompleted: {
        opacity = 1;
        revealTimer.start();
        input.forceActiveFocus();
    }

    function unlock() {
        if (unlocking)
            return;

        unlocking = true;
        message = "Unlocking…";
        messageError = false;
        fpProc.running = false;
        pam.abort();
        revealTimer.stop();

        // Play the exit animation first, then release the session lock so the
        // reverse pop is visible instead of being cut short by surface teardown.
        reveal = 0;
        unlockTimer.start();
    }

    function submitPassword() {
        if (unlocking)
            return;

        const password = input.text;
        if (password.length === 0)
            return;

        input.text = "";
        message = "Authenticating…";
        messageError = false;

        if (pam.responseRequired) {
            pam.respond(password);
        } else if (!pam.active) {
            queuedPassword = password;
            if (!pam.start()) {
                message = "Could not start authentication";
                messageError = true;
                queuedPassword = "";
            }
        } else {
            queuedPassword = password;
        }

        input.forceActiveFocus();
    }

    function startFingerprint() {
        if (!fpAvailable || unlocking || fpProc.running)
            return;

        fpWorking = true;
        message = "Touch the fingerprint sensor";
        messageError = false;
        fpProc.running = true;
    }

    // Check whether the current user has any enrolled fingerprints.
    Process {
        id: fpCheck
        command: ["sh", "-c", "fprintd-list \"$USER\" 2>/dev/null | grep -q -- ' - #'"]
        running: true

        onExited: function (exitCode) {
            root.fpAvailable = exitCode === 0;
            if (root.fpAvailable)
                root.startFingerprint();
        }
    }

    // A single fingerprint scan. Re-armed after a failed attempt.
    Process {
        id: fpProc
        command: ["fprintd-verify"]

        onExited: function (exitCode) {
            root.fpWorking = false;
            if (root.unlocking)
                return;

            if (exitCode === 0) {
                root.unlock();
            } else {
                root.message = "Fingerprint not recognized — try again";
                root.messageError = true;
                fpRetry.start();
            }
        }
    }

    Timer {
        id: fpRetry
        interval: 1100
        onTriggered: root.startFingerprint()
    }

    PamContext {
        id: pam
        config: "login"

        onResponseRequiredChanged: {
            if (responseRequired && root.queuedPassword !== "") {
                const password = root.queuedPassword;
                root.queuedPassword = "";
                respond(password);
            }
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                root.unlock();
            } else {
                root.message = "Incorrect password";
                root.messageError = true;
                root.queuedPassword = "";
                input.text = "";
                input.forceActiveFocus();
            }
        }

        onError: function (error) {
            root.message = "Authentication error: " + PamError.toString(error);
            root.messageError = true;
            root.queuedPassword = "";
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FileView {
        id: hostFile
        path: "/proc/sys/kernel/hostname"
        onLoadedChanged: {
            if (loaded)
                root.hostname = text().trim();
        }
    }

    // Wallpaper. Downscaling the source and letting the smooth filter scale it
    // back up gives a soft blur without shader effects, which render black on
    // some GPU/driver combinations.
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Image {
        anchors.fill: parent
        source: wallpaperPath.length > 0 ? "file://" + wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: 128
        sourceSize.height: 72
        smooth: true
        onStatusChanged: {
            if (status === Image.Error)
                console.warn("LockScreen: failed to load wallpaper");
        }
    }

    // Theme-aware readability overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.78) }
            GradientStop { position: 0.55; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.66) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85) }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (1 - root.reveal) * 14
        width: Math.min(parent.width - 48, 480)
        spacing: 0

        opacity: root.reveal
        scale: 0.94 + 0.06 * root.reveal

        Behavior on opacity {
            NumberAnimation {
                duration: root.unlocking ? Theme.motionBase : Theme.motionSlow
                easing.type: root.unlocking ? Easing.InCubic : Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.unlocking ? Theme.motionBase : Theme.motionSlow + 120
                easing.type: root.unlocking ? Easing.InCubic : Easing.OutBack
                easing.overshoot: 1.18
            }
        }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation {
                duration: root.unlocking ? Theme.motionBase : Theme.motionSlow + 120
                easing.type: root.unlocking ? Easing.InCubic : Easing.OutCubic
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Theme.mono
            font.pixelSize: 96
            font.weight: Font.Light
            color: Theme.text
            opacity: 0.96
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
            font.family: Theme.mono
            font.pixelSize: 17
            color: Theme.subtext
        }

        Item { width: 1; height: 46 }

        // Password field
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 360)
            height: 48
            radius: 12
            color: Qt.rgba(Theme.pill.r, Theme.pill.g, Theme.pill.b, 0.8)
            border.width: 1
            border.color: input.activeFocus ? Theme.accent : Theme.border

            Behavior on border.color { ColorAnimation { duration: 140 } }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌾"
                font.family: Theme.font
                font.pixelSize: 16
                color: input.activeFocus ? Theme.accent : Theme.dim
            }

            TextInput {
                id: input
                anchors.fill: parent
                leftPadding: 44
                rightPadding: 14
                verticalAlignment: TextInput.AlignVCenter
                font.family: Theme.mono
                font.pixelSize: 14
                color: Theme.text
                selectionColor: Theme.accent
                selectedTextColor: Theme.bg
                passwordCharacter: "•"
                echoMode: TextInput.Password
                focus: true
                clip: true

                onAccepted: root.submitPassword()
                Keys.onEscapePressed: {
                    input.text = "";
                    root.message = root.fpAvailable ? "Touch the fingerprint sensor" : "Enter your password";
                    root.messageError = false;
                }
            }

            Text {
                anchors.left: input.left
                anchors.leftMargin: 44
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text.length === 0
                text: "Password"
                font.family: Theme.mono
                font.pixelSize: 13
                color: Theme.dim
            }
        }

        Item { width: 1; height: 20 }

        // Authentication status
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Text {
                id: fpIcon
                visible: root.fpAvailable
                text: "󰈷"
                font.family: Theme.font
                font.pixelSize: 16
                color: root.messageError
                    ? Theme.red
                    : (root.fpWorking ? Theme.accent : Theme.subtext)
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: root.fpWorking
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: root.message
                font.family: Theme.mono
                font.pixelSize: 12
                color: root.messageError ? Theme.red : Theme.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item { width: 1; height: 14 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.fpAvailable
            text: "Fingerprint or password to unlock"
            font.family: Theme.mono
            font.pixelSize: 10
            color: Theme.dim
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        text: Quickshell.env("USER") + (root.hostname !== "" ? "@" + root.hostname : "")
        font.family: Theme.mono
        font.pixelSize: 10
        color: Theme.dim
        opacity: 0.75 * root.reveal

        Behavior on opacity {
            NumberAnimation {
                duration: root.unlocking ? Theme.motionBase : Theme.motionSlow
                easing.type: root.unlocking ? Easing.InCubic : Easing.OutCubic
            }
        }
    }

    // Subtle vertical accent at the very top
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: 240
        height: 2
        radius: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.accentAlt }
            GradientStop { position: 1.0; color: "transparent" }
        }
        opacity: 0.55 * root.reveal

        Behavior on opacity {
            NumberAnimation {
                duration: root.unlocking ? Theme.motionBase : Theme.motionSlow
                easing.type: root.unlocking ? Easing.InCubic : Easing.OutCubic
            }
        }
    }
}
