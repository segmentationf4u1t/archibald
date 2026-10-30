import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// greetd greeter in the dark-volcanic style of the desktop (same Theme.qml as ~/.config/quickshell,
// layout of the hyprlock lock screen). Started by /etc/greetd/hyprland.lua as the "greeter" user.
// GREETER_TEST=1 shows it in a normal window instead of full-screen layers and only logs the power
// buttons, for trying changes inside a running session (needs a greetd socket in GREETD_SOCK).
ShellRoot {
    id: root

    // ---- configuration ----
    readonly property string defaultUser: "segfault"
    readonly property var sessionCommand: ["start-hyprland"]
    readonly property var sessionEnvironment: ["XDG_SESSION_TYPE=wayland", "XDG_SESSION_DESKTOP=Hyprland", "XDG_CURRENT_DESKTOP=Hyprland"]
    readonly property string sessionName: "Hyprland"
    readonly property string keyboardLayout: "PL"          // keep in sync with input.kb_layout in hyprland.lua
    readonly property string primaryModel: "PL2480C"       // monitor with the login card (iiyama); fallback: first screen

    readonly property bool testMode: Quickshell.env("GREETER_TEST") === "1"
    readonly property var primaryScreen: Quickshell.screens.find(s => s.model.indexOf(primaryModel) !== -1) ?? Quickshell.screens[0]

    Auth {
        id: greetdAuth   // not "auth": inside Greeter { auth: ... } that name is Greeter's own property
        command: root.sessionCommand
        environment: root.sessionEnvironment
    }

    // Real greeter: one full-screen layer per monitor, the login card and keyboard only on the primary one.
    Variants {
        model: root.testMode ? [] : Quickshell.screens

        delegate: PanelWindow {
            id: panel
            required property var modelData
            readonly property bool primary: modelData === root.primaryScreen

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "greeter"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: Theme.basalt

            Greeter {
                anchors.fill: parent
                primary: panel.primary
                auth: greetdAuth
                shell: root
            }
        }
    }

    // Test: an ordinary window.
    LazyLoader {
        active: root.testMode

        FloatingWindow {
            title: "greeter-test"
            implicitWidth: 1280
            implicitHeight: 800
            color: Theme.basalt

            Greeter {
                anchors.fill: parent
                primary: true
                auth: greetdAuth
                shell: root
            }
        }
    }
}
