import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs

// The bar's single dropdown: one layer surface that shows whichever popup bar.openPopup names,
// centered under that popup's anchor and kept on screen. One window per bar instead of one per popup.
// The surface is persistent: it is mapped for the bar's whole lifetime and never unmapped on close.
// Creating the wl_surface + layer surface, waiting for its configure and building a QQuickWindow
// render context / EGL surface on every open cost ~70-100 ms to the first frame (and ~140 ms CPU);
// now opening only resizes the surface and fades the frame in.
// Closed (not shown and the fade-out done) the surface is 1x1 (never 0: in layer-shell a 0 size with a
// single anchor means stretch), fully transparent, its input region empty (clicks pass through) and its
// content unloaded. It must stay tiny: the layer rule blurs behind this namespace, so a large
// transparent surface left over the desktop would cost background blur on every compositor frame.
// While open the surface grows to the content size (the size changes in the same step that loads the
// content, before the frame fades in) and the input region is the frame (not the slide-in margin).
// While open it takes the keyboard on demand (it gets focus when the pointer enters it; Escape closes
// it, text fields work) and a Hyprland focus grab closes it on any click outside it and the bar.
// Not Exclusive: Hyprland sends all pointer input to exclusive layer surfaces, so the grab would never
// see the outside click and the dropdown would block the rest of the screen.
// Content is loaded only while open (no cost when closed); the loaded item may declare
// `property var dropdown` to get this object (shown, close(), bar). Switching straight to another
// popup swaps the content in place (the frame stays up and resizes).
PanelWindow {
    id: root

    required property var bar          // Bar (PanelWindow) owning the open/close state
    // popup name -> {source: url, anchor: Item}; the anchor is re-read on every open
    required property var popups

    readonly property string target: bar.openPopup
    // The popup being shown, kept after closing until the fade-out is done. Set by onTargetChanged
    // (not bound), so it and `shown` change in a defined order: the Loader never sees a stale popup.
    property string current: ""
    property bool shown: false
    // open or still fading out: the surface has its content size and takes input; otherwise 1x1
    readonly property bool showing: shown || frame.opacity > 0
    readonly property Item anchorItem: popups[current]?.anchor ?? null
    readonly property url source: popups[current]?.source ?? ""
    readonly property Item content: loader.item
    // bench keys (Perf.qml)
    readonly property string openKey: "open:" + current
    readonly property string loadedKey: "loaded:" + current
    property real anchorCenterX: 0     // anchor's center in bar coordinates, captured on open

    function close() {
        bar.closePopup(current);
    }

    function captureAnchor() {
        if (anchorItem)
            anchorCenterX = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
    }

    onTargetChanged: {
        // an open measurement still running for the previous popup is dropped
        Perf.clear(openKey);
        Perf.clear(loadedKey);
        const known = target !== "" && popups[target] !== undefined;
        if (known) {
            Perf.begin("open:" + target);
            current = target;
            captureAnchor();
        }
        shown = known;
    }
    // the tray menu moves to another tray item while open
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

    visible: true
    color: "transparent"
    implicitWidth: showing ? frame.implicitWidth : 1
    implicitHeight: showing ? frame.implicitHeight + 8 : 1   // room for the slide-in
    // Input only on the frame while showing (the surface is as big as the frame plus the slide-in
    // margin); a Region without an item is empty, which makes the surface click-through. The region
    // follows `inputArea` (static, unlike the frame it does not move during the slide), so it is only
    // recomputed when the size changes.
    mask: Region { item: root.showing ? inputArea : null }

    Item {
        id: inputArea
        width: frame.implicitWidth
        height: frame.implicitHeight
    }

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
            active: root.showing
            source: root.source
            focus: true
            onLoaded: {
                if (item.hasOwnProperty("dropdown"))
                    item.dropdown = root;
                // bench: the content was built after the open began (a warm re-open never gets here)
                if (Perf.has(root.openKey))
                    Perf.begin(root.loadedKey);
            }
            Keys.onEscapePressed: root.close()
        }
    }

    HyprlandFocusGrab {
        active: root.shown
        windows: [root, root.bar]
        onCleared: root.close()
    }

    // bench: dropdown frames while shown, and shown -> first frame (nothing connected while Perf is off)
    Connections {
        target: Perf.enabled ? frame.Window.window : null

        function onFrameSwapped() {
            if (!root.shown)
                return;
            Perf.count("frames:dropdown:" + root.current);
            if (!Perf.has(root.openKey))
                return;
            // loaded = ms until the Loader finished; 0 when the content was still loaded (re-open in the fade)
            const loaded = Perf.has(root.loadedKey) ? Perf.since(root.openKey) - Perf.since(root.loadedKey) : 0;
            Perf.emit("open", {name: root.current, loaded: loaded, frame: Perf.since(root.openKey)});
            Perf.clear(root.openKey);
            Perf.clear(root.loadedKey);
        }
    }
}
