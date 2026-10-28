import QtQuick
import qs

// Round glyph button (refresh, settings, mute, ...).
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.text
    property bool checked: false     // e.g. muted / scanning: tinted background
    property bool enabled: true

    signal clicked(var mouse)

    implicitWidth: 30
    implicitHeight: 30
    radius: width / 2
    opacity: enabled ? 1 : 0.5
    color: checked ? Theme.alpha(Theme.magma, 0.18) : area.containsMouse ? Theme.lava : "transparent"
    border.width: checked ? 1 : 0
    border.color: Theme.alpha(Theme.magma, 0.5)

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Glyph {
        anchors.centerIn: parent
        text: root.icon
        color: root.checked ? Theme.magma : root.iconColor
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
    }
}
