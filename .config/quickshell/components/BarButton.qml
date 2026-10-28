import QtQuick
import qs

// Bar module: glyph + optional label (+ extra children appended to the row),
// hover/open state = pill inset in the bar.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property color iconColor: Theme.text
    property color labelColor: iconColor
    property int iconSize: Theme.iconSize
    property bool active: false        // its dropdown is open
    property int padding: 10
    property bool bold: false
    default property alias extra: row.data

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.implicitWidth + 2 * padding
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        radius: height / 2
        color: root.active || area.containsMouse ? Theme.lava : "transparent"
        border.width: root.active ? 1 : 0
        border.color: Theme.obsidian

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            size: root.iconSize
            color: root.iconColor
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.label !== ""
            text: root.label
            color: root.labelColor
            font.weight: root.bold ? Font.Bold : Font.Medium
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheel(wheel)
    }
}
