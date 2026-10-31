import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
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

            // unknown app: its own icon in grayscale, tinted with the text color (a flat silhouette would
            // turn round app icons into blank discs). Only instantiated for items without a Tabler glyph,
            // so known items create neither the image nor the effect.
            Loader {
                anchors.centerIn: parent
                active: slot.glyph === ""
                sourceComponent: Item {
                    implicitWidth: 18
                    implicitHeight: 18

                    IconImage {
                        id: ownIcon
                        anchors.fill: parent
                        implicitSize: 18
                        visible: false
                        source: slot.modelData.icon
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: ownIcon
                        brightness: 0.15
                        saturation: -1.0
                        colorization: 1.0
                        colorizationColor: Theme.magma
                        opacity: slot.iconOpacity
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
