import QtQuick
import QtQuick.Layouts
import qs

// Small stat tile: muted caption over a bold value.
Rectangle {
    property string caption
    property string value
    property color valueColor: Theme.text
    property bool compact: false

    Layout.fillWidth: true
    implicitHeight: 48
    radius: 10
    color: Theme.lava

    Column {
        anchors.centerIn: parent
        spacing: 1

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: caption
            small: true
            muted: true
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: value
            color: valueColor
            font.weight: Font.Bold
            font.pixelSize: compact ? Theme.fontSizeSmall + 1 : Theme.fontSize
        }
    }
}
