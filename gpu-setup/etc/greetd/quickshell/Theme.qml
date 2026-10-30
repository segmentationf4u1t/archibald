pragma Singleton

import QtQuick
import Quickshell

// dark-volcanic (Tern/omp). Copy of ~/.config/quickshell/Theme.qml (the greeter user cannot read
// the home directory): copy it again after changing the desktop palette.
Singleton {
    readonly property color basalt: "#100908"   // background
    readonly property color crater: "#1A100E"   // panels
    readonly property color lava: "#261513"     // raised / hover
    readonly property color obsidian: "#3A201C" // borders, tracks
    readonly property color magma: "#FF7A3D"    // accent
    readonly property color sulfur: "#F3C24F"   // secondary accent
    readonly property color ash: "#8F7D74"      // muted text
    readonly property color moss: "#4FC48A"     // ok / connected
    readonly property color fire: "#FF5C5C"     // error / critical
    readonly property color text: "#ebdfd8"
    // derived
    readonly property color ashDim: "#6B5A52"   // disabled
    readonly property color ember: "#FFA36B"    // light magma

    readonly property color barBg: Qt.rgba(0x1A / 255, 0x10 / 255, 0x0E / 255, 0.85)
    readonly property color popupBg: Qt.rgba(0x10 / 255, 0x09 / 255, 0x08 / 255, 0.94)

    readonly property string font: "JetBrainsMono Nerd Font Propo"
    readonly property int fontSize: 14
    readonly property int fontSizeSmall: 12
    readonly property int iconSize: 16

    readonly property int barHeight: 34
    readonly property int barGapTop: 6
    readonly property int barGapSide: 14   // = Hyprland gaps_out, bar lines up with windows
    readonly property int popupGap: 8      // space between bar and dropdown
    readonly property int popupPadding: 16
    readonly property int popupRadius: 16
    readonly property int radius: 12

    readonly property int animFast: 140
    readonly property int animNormal: 220

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // 0..1 load -> sulfur..magma..fire
    function heat(v) {
        if (v < 0.5) return Qt.tint(sulfur, alpha(magma, v * 2));
        return Qt.tint(magma, alpha(fire, (v - 0.5) * 2));
    }
}
