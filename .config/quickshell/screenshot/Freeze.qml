import QtQuick
import Quickshell
import Quickshell.Wayland

// Frozen screen for the area screenshot (~/.local/bin/screenshot area): the script grabs every output
// to <dir>/<output>.ppm before anything on screen changes (open dropdowns included), shows them here
// on the overlay layer, slurp selects on top and grim captures the frozen frame.
// Click-through and without keyboard, so slurp gets all the input.
Scope {
    id: root

    property string dir: ""   // "" = hidden

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "qs-freeze"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
            color: "transparent"
            visible: root.dir !== "" && frame.status === Image.Ready

            Image {
                id: frame
                anchors.fill: parent
                source: root.dir !== "" ? "file://" + root.dir + "/" + modelData.name + ".ppm" : ""
                cache: false
                smooth: false
            }
        }
    }
}
