import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

// StatusNotifier icons. Left click: activate (or menu if the item only has a menu),
// middle: secondary action, right: themed menu dropdown (bar's "traymenu" popup).
Row {
    id: root

    required property var bar

    spacing: 2
    leftPadding: 6
    rightPadding: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: slot

            required property SystemTrayItem modelData

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

            IconImage {
                anchors.centerIn: parent
                implicitSize: 18
                source: slot.modelData.icon
                opacity: slot.modelData.status === Status.Passive ? 0.55 : 1
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
