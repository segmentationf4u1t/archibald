import QtQuick
import qs

// Horizontal fill bar, value 0..1.
Rectangle {
    id: root

    property real value: 0
    property color fillColor: Theme.magma

    implicitWidth: 120
    implicitHeight: 6
    radius: height / 2
    color: Theme.obsidian

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: parent.radius
        color: root.fillColor

        Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    }
}
