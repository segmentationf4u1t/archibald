import QtQuick
import QtQuick.Layouts
import qs

// Small muted section title with an optional trailing slot (children).
RowLayout {
    id: root

    property string text: ""
    default property alias trailing: trailingRow.data

    spacing: 8

    Label {
        Layout.fillWidth: true
        text: root.text.toUpperCase()
        small: true
        muted: true
        font.letterSpacing: 1
    }

    RowLayout {     // RowLayout centers children of different heights vertically
        id: trailingRow
        spacing: 6
        Layout.alignment: Qt.AlignVCenter
    }
}
