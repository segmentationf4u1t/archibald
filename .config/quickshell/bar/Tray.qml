import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components

// StatusNotifier icons. Known apps are drawn with their Tabler icon (Icons.tray), others as a
// monochrome version of their own icon; items whose job a bar module does are hidden (Icons.hiddenTray).
// Left click: activate (or menu if the item only has a menu), middle: secondary action,
// right: themed menu dropdown (bar's "traymenu" popup).
Row {
    id: root

    required property var bar

    spacing: 2
    leftPadding: 6
    rightPadding: 6

    Repeater {
        // ScriptModel diffs the array, so delegates survive list changes instead of being rebuilt
        model: ScriptModel {
            values: SystemTray.items.values.filter(item => !Icons.hiddenTray.includes(item.id))
        }

        delegate: Item {
            id: slot

            required property SystemTrayItem modelData
            readonly property string glyph: Icons.tray(modelData.id)
            readonly property real iconOpacity: modelData.status === Status.Passive ? 0.55 : 1

            width: 28
            height: Theme.barHeight

            Rectangle {
                anchors.centerIn: parent
                width: 26
                height: 26
                radius: 13
                color: slot.modelData.status === Status.NeedsAttention ? Theme.alpha(Theme.fire, 0.35)
                    : area.containsMouse || root.bar.trayMenuItem === slot.modelData && root.bar.openPopup === "traymenu" ? Theme.lava
                    : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }

            Glyph {
                anchors.centerIn: parent
                visible: slot.glyph !== ""
                text: slot.glyph
                size: 18
                color: Theme.magma
                opacity: slot.iconOpacity
            }

            // unknown app: its own icon in grayscale, brightened (a flat silhouette would turn round app
            // icons into blank discs). Only instantiated for items without a Tabler glyph. A Canvas, not
            // MultiEffect: the bar uses the software scene graph (shell.qml), which has no shader effects.
            // Same output as the MultiEffect it replaces (brightness 0.15, saturation -1; its colorization
            // never took effect, measured): luma (0.299/0.587/0.114) + 0.15, alpha kept.
            Loader {
                anchors.centerIn: parent
                active: slot.glyph === ""
                sourceComponent: Canvas {
                    readonly property string icon: slot.modelData.icon
                    property string loaded: ""   // image held in the Canvas cache (SNI icon URLs change per update)

                    function load() {
                        if (loaded !== "" && loaded !== icon)
                            unloadImage(loaded);
                        loaded = icon;
                        if (icon !== "")
                            loadImage(icon);
                        requestPaint();          // already-cached images emit no imageLoaded
                    }

                    implicitWidth: 18
                    implicitHeight: 18
                    opacity: slot.iconOpacity

                    onIconChanged: load()
                    Component.onCompleted: load()
                    onImageLoaded: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (icon === "" || !isImageLoaded(icon))
                            return;
                        ctx.drawImage(icon, 0, 0, width, height);
                        const img = ctx.getImageData(0, 0, width, height);
                        const px = img.data;
                        for (let i = 0; i < px.length; i += 4) {
                            const l = Math.min(255, 0.299 * px[i] + 0.587 * px[i + 1] + 0.114 * px[i + 2] + 0.15 * 255);
                            px[i] = px[i + 1] = px[i + 2] = l;
                        }
                        // with the dirty rect: the 3-argument form is a no-op in this Qt (6.12, measured)
                        ctx.putImageData(img, 0, 0, 0, 0, width, height);
                    }
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const item = slot.modelData;
                    if (mouse.button === Qt.MiddleButton)
                        item.secondaryActivate();
                    else if (mouse.button === Qt.RightButton || item.onlyMenu)
                        root.bar.openTrayMenu(item, slot);
                    else
                        item.activate();
                }
                onWheel: wheel => slot.modelData.scroll(wheel.angleDelta.y, false)
            }
        }
    }
}
