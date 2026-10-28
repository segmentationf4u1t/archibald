import QtQuick
import qs

// Nerd Font icon (Material Design range); write the glyph character literally.
Text {
    property int size: Theme.iconSize

    color: Theme.text
    font.family: Theme.font
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
