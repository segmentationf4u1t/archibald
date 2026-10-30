import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components

// This monitor's workspaces: number + Tabler icons of the windows on it. The one shown here is a raised
// pill (number in magma when this monitor has focus); urgent ones are fire.
// Click switches, wheel goes to the previous / next workspace.
Item {
    id: root

    required property var bar

    readonly property int maxIcons: 4   // more windows -> "+N"

    readonly property var workspaces: Hyprland.workspaces.values
        .filter(ws => ws.id > 0 && ws.monitor !== null && ws.monitor === root.bar.monitor)
        .sort((a, b) => a.id - b.id)

    // by window class, then by the icon / id of its desktop entry (e.g. a class that differs from the binary)
    function iconFor(toplevel) {
        const appId = toplevel.wayland?.appId || toplevel.lastIpcObject?.class || "";
        const entry = appId !== "" ? DesktopEntries.heuristicLookup(appId) : null;
        return Icons.app([appId, entry?.icon, entry?.id]);
    }

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.workspaces

            delegate: Item {
                id: slot

                required property HyprlandWorkspace modelData
                readonly property bool shownHere: root.bar.monitor !== null && root.bar.monitor.activeWorkspace === modelData
                readonly property bool focusedHere: shownHere && root.bar.monitor.focused
                readonly property var windows: modelData.toplevels.values

                width: content.implicitWidth + 18
                height: Theme.barHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    anchors.bottomMargin: 4
                    radius: height / 2
                    color: slot.shownHere || hover.hovered ? Theme.lava : "transparent"
                    border.width: slot.shownHere ? 1 : 0
                    border.color: Theme.obsidian

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }

                Row {
                    id: content
                    anchors.centerIn: parent
                    spacing: 5

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: slot.modelData.name
                        font.weight: slot.shownHere ? Font.Bold : Font.Medium
                        color: slot.modelData.urgent ? Theme.fire
                            : slot.focusedHere ? Theme.magma
                            : slot.shownHere || hover.hovered ? Theme.text
                            : Theme.ash

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }

                    Repeater {
                        model: slot.windows.slice(0, root.maxIcons)

                        delegate: Glyph {
                            required property HyprlandToplevel modelData

                            anchors.verticalCenter: parent.verticalCenter
                            text: root.iconFor(modelData)
                            size: 16
                            opacity: slot.shownHere || hover.hovered ? 1 : 0.55

                            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                        }
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: slot.windows.length > root.maxIcons
                        text: "+" + (slot.windows.length - root.maxIcons)
                        small: true
                        muted: true
                    }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: slot.modelData.activate()
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Hyprland.dispatch(`hl.dsp.focus({ workspace = "e${event.angleDelta.y > 0 ? "-" : "+"}1" })`)
    }
}
