import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// Dropdown under a bar module: its own layer surface, centered under the module and kept on screen.
// While open it takes the keyboard on demand (it gets focus when the pointer enters it; Escape closes
// it, text fields work) and a Hyprland focus grab closes it on any click outside it and the bar.
// Not Exclusive: Hyprland sends all pointer input to exclusive layer surfaces, so the grab would never
// see the outside click and the dropdown would block the rest of the screen.
// Content is loaded only while open (no cost when closed); the loaded item may declare
// `property var dropdown` to get this object (shown, close(), bar).
PanelWindow {
    id: root

    required property var bar          // Bar (PanelWindow) owning the open/close state
    required property string name
    required property Item anchorItem
    property url source
    property Component sourceComponent

    readonly property bool shown: bar.openPopup === name
    readonly property Item content: loader.item
    property real anchorCenterX: 0     // anchor's center in bar coordinates, captured on open

    function close() {
        bar.closePopup(name);
    }

    function captureAnchor() {
        if (anchorItem)
            anchorCenterX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    }

    onShownChanged: if (shown) captureAnchor()
    onAnchorItemChanged: if (shown) captureAnchor()

    screen: bar.screen
    anchors {
        top: true
        left: true
    }
    margins {
        top: Theme.barGapTop + Theme.barHeight + Theme.popupGap
        left: Math.max(Theme.barGapSide, Math.min(Theme.barGapSide + anchorCenterX - implicitWidth / 2,
                                                   (screen?.width ?? 1920) - Theme.barGapSide - implicitWidth))
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-dropdown"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    visible: shown || frame.opacity > 0
    color: "transparent"
    implicitWidth: frame.implicitWidth
    implicitHeight: frame.implicitHeight + 8   // room for the slide-in

    Rectangle {
        id: frame

        implicitWidth: loader.implicitWidth + 2 * Theme.popupPadding
        implicitHeight: loader.implicitHeight + 2 * Theme.popupPadding
        width: parent.width
        height: implicitHeight
        y: root.shown ? 0 : -8
        opacity: root.shown ? 1 : 0
        radius: Theme.popupRadius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.obsidian

        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

        Loader {
            id: loader
            x: Theme.popupPadding
            y: Theme.popupPadding
            width: implicitWidth
            height: implicitHeight
            active: root.shown || frame.opacity > 0
            source: root.source
            sourceComponent: root.sourceComponent
            focus: true
            onLoaded: {
                if (item.hasOwnProperty("dropdown"))
                    item.dropdown = root;
            }
            Keys.onEscapePressed: root.close()
        }
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root, root.bar]
        onCleared: root.close()
    }
}
