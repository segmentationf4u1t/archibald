import QtQuick
import QtQuick.Effects
import Quickshell
import qs

// One screen of the greeter: blurred volcanic wallpaper everywhere, clock + login card + power
// buttons on the primary screen. Layout and colors follow ~/.config/hypr/hyprlock.conf.
Item {
    id: root

    required property bool primary
    required property var auth      // Auth
    required property var shell     // ShellRoot from shell.qml (configuration, testMode)

    property string user: shell.defaultUser
    property bool editingUser: false
    property date now: new Date()

    readonly property var plLocale: Qt.locale("pl_PL")

    function glyph(code) {
        return String.fromCodePoint(code);
    }

    function power(action) {
        if (shell.testMode) {
            console.log("greeter test: would run systemctl " + action);
            return;
        }
        Quickshell.execDetached(["systemctl", action]);
    }

    opacity: auth.launching ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    Component.onCompleted: if (primary) passwordInput.forceActiveFocus()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // ---- background: wallpaper blurred and darkened like the hyprlock background ----
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Qt.resolvedUrl("wallpaper.png")
        sourceSize.width: 1920
        fillMode: Image.PreserveAspectCrop
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 48
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.basalt
        opacity: 0.45
    }

    // ---- clock, date, user, password ----
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24
        visible: root.primary
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            color: Theme.magma
            font.family: Theme.font
            font.pixelSize: 112
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.plLocale.toString(root.now, "dddd, d MMMM yyyy")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 24
        }

        Item { width: 1; height: 56 }

        // user: click to log in as someone else
        Rectangle {
            id: userChip

            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: userRow.implicitWidth + 32
            implicitHeight: 40
            radius: height / 2
            color: userArea.containsMouse || root.editingUser ? Theme.lava : Theme.alpha(Theme.crater, 0.75)
            border.width: 1
            border.color: root.editingUser ? Theme.alpha(Theme.magma, 0.6) : Theme.obsidian

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Row {
                id: userRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.glyph(0xF0004)   // md-account
                    color: Theme.magma
                    font.family: Theme.font
                    font.pixelSize: 20
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.editingUser
                    text: root.user
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.Medium
                }

                TextInput {
                    id: userInput
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.editingUser
                    width: Math.max(140, contentWidth)
                    color: Theme.text
                    selectionColor: Theme.alpha(Theme.magma, 0.4)
                    selectedTextColor: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.Medium

                    onAccepted: {
                        if (text.trim() !== "")
                            root.user = text.trim();
                        root.editingUser = false;
                        passwordInput.forceActiveFocus();
                    }
                    Keys.onEscapePressed: {
                        root.editingUser = false;
                        passwordInput.forceActiveFocus();
                    }
                }
            }

            MouseArea {
                id: userArea
                anchors.fill: parent
                enabled: !root.editingUser && !root.auth.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    userInput.text = root.user;
                    root.editingUser = true;
                    userInput.selectAll();
                    userInput.forceActiveFocus();
                }
            }
        }

        Item { width: 1; height: 16 }

        // password: magma -> sulfur outline, sulfur while checking, fire after a failure
        Item {
            id: field

            property real shake: 0

            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            height: 56
            transform: Translate { x: field.shake }

            Rectangle {
                anchors.fill: parent
                radius: 16
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: root.auth.failed ? Theme.fire : root.auth.busy ? Theme.sulfur : Theme.magma
                    }
                    GradientStop {
                        position: 1
                        color: root.auth.failed ? Theme.fire : Theme.sulfur
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 13
                color: Theme.alpha(Theme.crater, 0.92)
            }

            TextInput {
                id: passwordInput

                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: root.auth.prompt !== "" && root.auth.promptEcho ? TextInput.Normal : TextInput.Password
                passwordCharacter: "●"
                cursorDelegate: Item {}   // no caret, like hyprlock: the dots are the feedback
                readOnly: root.auth.busy || root.auth.launching
                clip: true
                color: Theme.text
                selectionColor: Theme.alpha(Theme.magma, 0.4)
                selectedTextColor: Theme.text
                font.family: Theme.font
                font.pixelSize: 18
                font.letterSpacing: 2

                onTextChanged: if (text !== "" && root.auth.failed) {
                    root.auth.failed = false;
                    root.auth.message = "";
                }
                onAccepted: root.auth.submit(root.user, text)
                Keys.onEscapePressed: text = ""
            }

            Text {
                anchors.centerIn: parent
                visible: passwordInput.text === "" || root.auth.busy
                text: root.auth.busy ? "Sprawdzanie..." : root.auth.prompt !== "" ? root.auth.prompt : "Hasło..."
                color: Theme.ash
                font.family: Theme.font
                font.pixelSize: 16
            }

            SequentialAnimation {
                id: shakeAnimation
                NumberAnimation { target: field; property: "shake"; to: -12; duration: 45 }
                NumberAnimation { target: field; property: "shake"; to: 12; duration: 70 }
                NumberAnimation { target: field; property: "shake"; to: -8; duration: 60 }
                NumberAnimation { target: field; property: "shake"; to: 8; duration: 60 }
                NumberAnimation { target: field; property: "shake"; to: 0; duration: 45 }
            }
        }

        Item { width: 1; height: 14 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 20
            text: root.auth.message
            color: root.auth.failed ? Theme.fire : Theme.ash
            font.family: Theme.font
            font.pixelSize: 14
        }
    }

    Connections {
        target: root.auth

        function onFailure() {
            passwordInput.text = "";
            shakeAnimation.restart();
            passwordInput.forceActiveFocus();
        }
    }

    // ---- bottom: session + keyboard layout (left), power (right) ----
    component Chip: Rectangle {
        property int icon
        property string label

        implicitWidth: chipRow.implicitWidth + 28
        implicitHeight: 36
        radius: height / 2
        color: Theme.alpha(Theme.crater, 0.75)
        border.width: 1
        border.color: Theme.obsidian

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyph(icon)
                color: Theme.magma
                font.family: Theme.font
                font.pixelSize: 16
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.weight: Font.Medium
            }
        }
    }

    component PowerButton: Rectangle {
        id: button

        property int icon
        property color hoverColor: Theme.magma
        signal clicked()

        implicitWidth: 44
        implicitHeight: 44
        radius: width / 2
        color: area.containsMouse ? Theme.lava : Theme.alpha(Theme.crater, 0.75)
        border.width: 1
        border.color: area.containsMouse ? Theme.alpha(hoverColor, 0.6) : Theme.obsidian

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Text {
            anchors.centerIn: parent
            text: root.glyph(button.icon)
            color: area.containsMouse ? button.hoverColor : Theme.text
            font.family: Theme.font
            font.pixelSize: 20
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        visible: root.primary
        spacing: 10

        Chip { icon: 0xF0379; label: root.shell.sessionName }       // md-monitor
        Chip { icon: 0xF030C; label: root.shell.keyboardLayout }    // md-keyboard
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        visible: root.primary
        spacing: 12

        PowerButton { icon: 0xF0709; onClicked: root.power("reboot") }                              // md-restart
        PowerButton { icon: 0xF0425; hoverColor: Theme.fire; onClicked: root.power("poweroff") }    // md-power
    }
}
