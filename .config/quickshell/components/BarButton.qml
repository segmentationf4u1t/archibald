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
    default property alias extra: extras.data
    readonly property bool hovered: area.containsMouse

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.width + 2 * padding
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

    // The content is positioned with bindings instead of a Row: a positioner lays out in a deferred
    // polish pass, so a label that changes width (a value with one more digit) would invalidate the
    // bar's module rows after the frame showing the new text, repainting the whole bar once more.
    Item {
        id: row
        anchors.centerIn: parent
        width: extras.width > 0 ? extras.x + extras.width
            : labelItem.visible ? labelItem.x + labelItem.width
            : iconItem.width
        height: Math.max(Math.max(iconItem.visible ? iconItem.height : 0, labelItem.visible ? labelItem.height : 0),
                         extras.height)

        Glyph {
            id: iconItem
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            text: root.icon
            size: root.iconSize
            color: root.iconColor
        }

        Label {
            id: labelItem
            anchors.verticalCenter: parent.verticalCenter
            x: iconItem.visible ? iconItem.width + 6 : 0
            visible: root.label !== ""
            text: root.label
            color: root.labelColor
            font.weight: root.bold ? Font.Bold : Font.Medium
        }

        Row {
            id: extras
            anchors.verticalCenter: parent.verticalCenter
            x: labelItem.visible ? labelItem.x + labelItem.width + 6 : iconItem.visible ? iconItem.width + 6 : 0
            spacing: 6
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
