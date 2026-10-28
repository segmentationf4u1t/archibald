import QtQuick
import QtQuick.Layouts
import qs

// Clickable row: glyph, title, optional subtitle, trailing slot (children), busy spinner.
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: highlighted ? Theme.magma : Theme.text
    property string title: ""
    property string subtitle: ""
    property bool highlighted: false   // e.g. connected / default device
    property bool busy: false
    property bool clickable: true
    default property alias trailing: trailingRow.data

    signal clicked(var mouse)

    implicitWidth: 320
    implicitHeight: subtitle !== "" ? 48 : 40
    radius: 10
    color: clickable && area.containsMouse ? Theme.lava : highlighted ? Theme.alpha(Theme.magma, 0.08) : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => root.clicked(mouse)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Glyph {
            visible: root.icon !== ""
            text: root.icon
            color: root.iconColor
            Layout.preferredWidth: 20
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Label {
                Layout.fillWidth: true
                text: root.title
                color: root.highlighted ? Theme.magma : Theme.text
            }

            Label {
                Layout.fillWidth: true
                visible: root.subtitle !== ""
                text: root.subtitle
                small: true
                muted: true
            }
        }

        Spinner {
            visible: root.busy
            running: root.busy
        }

        RowLayout {     // RowLayout centers children of different heights vertically
            id: trailingRow
            spacing: 6
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
