import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import "Colors.js" as Colors

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

    signal unlocked()

    opacity: 0
    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    Component.onCompleted: {
        opacity = 1;
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

        if (lock)
            lock.locked = false;
        else
            console.warn("LockScreen: session lock object is missing; the compositor will unlock only when the process exits");

        unlocked();
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
        color: Colors.bg
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

    // Darkening / readability overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#c4050a12" }
            GradientStop { position: 0.55; color: "#a6050a12" }
            GradientStop { position: 1.0; color: "#d9050a12" }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    Column {
        id: content
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 480)
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.family: Colors.mono
            font.pixelSize: 96
            font.weight: Font.Light
            color: Colors.text
            opacity: 0.96
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
            font.family: Colors.mono
            font.pixelSize: 17
            color: Colors.subtext
        }

        Item { width: 1; height: 46 }

        // Password field
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 360)
            height: 48
            radius: 12
            color: "#cc111722"
            border.width: 1
            border.color: input.activeFocus ? Colors.accent : Colors.border

            Behavior on border.color { ColorAnimation { duration: 140 } }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌾"
                font.family: Colors.font
                font.pixelSize: 16
                color: input.activeFocus ? Colors.accent : Colors.dim
            }

            TextInput {
                id: input
                anchors.fill: parent
                leftPadding: 44
                rightPadding: 14
                verticalAlignment: TextInput.AlignVCenter
                font.family: Colors.mono
                font.pixelSize: 14
                color: Colors.text
                selectionColor: Colors.accent
                selectedTextColor: Colors.bg
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
                font.family: Colors.mono
                font.pixelSize: 13
                color: Colors.dim
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
                font.family: Colors.font
                font.pixelSize: 16
                color: root.messageError
                    ? Colors.red
                    : (root.fpWorking ? Colors.accent : Colors.subtext)
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
                font.family: Colors.mono
                font.pixelSize: 12
                color: root.messageError ? Colors.red : Colors.subtext
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Item { width: 1; height: 14 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.fpAvailable
            text: "Fingerprint or password to unlock"
            font.family: Colors.mono
            font.pixelSize: 10
            color: Colors.dim
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        text: Quickshell.env("USER") + (root.hostname !== "" ? "@" + root.hostname : "")
        font.family: Colors.mono
        font.pixelSize: 10
        color: Colors.dim
        opacity: 0.75
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
            GradientStop { position: 0.0; color: "#0068e0c8" }
            GradientStop { position: 0.5; color: Colors.accentAlt }
            GradientStop { position: 1.0; color: "#0068e0c8" }
        }
        opacity: 0.55
    }
}
