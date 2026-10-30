import QtQuick
import qs

// Tabler icon: text is a character from Icons.glyph("name").
Text {
    property int size: Theme.iconSize

    color: Theme.text
    font.family: Icons.font
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
