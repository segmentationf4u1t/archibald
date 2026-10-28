import QtQuick
import qs

// On/off switch. Stateless: bind `checked`, apply `toggled(v)` to the backing state.
Item {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool checked)

    implicitWidth: 38
    implicitHeight: 22
    opacity: enabled ? 1 : 0.5

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.magma : Theme.obsidian

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.basalt : Theme.ash

            Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
