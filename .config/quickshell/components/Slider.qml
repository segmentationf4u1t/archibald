import QtQuick
import qs

// Horizontal slider, value 0..1. Stateless: bind `value`, apply `moved(v)` to the backing state.
Item {
    id: root

    property real value: 0
    property color color: Theme.magma
    property bool enabled: true
    property real wheelStep: 0.05

    signal moved(real value)

    readonly property real position: area.pressed ? area.dragValue : clamp(value)

    function clamp(v) {
        return Math.max(0, Math.min(1, v));
    }

    implicitWidth: 200
    implicitHeight: 20
    opacity: enabled ? 1 : 0.5

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.obsidian

        Rectangle {
            width: Math.max(parent.height, parent.width * root.position)
            height: parent.height
            radius: parent.radius
            color: root.color
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: (root.width - width) * root.position
        width: 14
        height: 14
        radius: 7
        color: Theme.text
        border.width: 2
        border.color: root.color
        scale: area.pressed || area.containsMouse ? 1.15 : 1

        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }

    MouseArea {
        id: area

        property real dragValue: 0

        function update(x) {
            dragValue = root.clamp(x / root.width);
            root.moved(dragValue);
        }

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) update(mouse.x);
        }
        onWheel: wheel => root.moved(root.clamp(root.value + (wheel.angleDelta.y > 0 ? root.wheelStep : -root.wheelStep)))
    }
}
