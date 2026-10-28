import QtQuick
import qs

Text {
    property bool muted: false
    property bool small: false

    color: muted ? Theme.ash : Theme.text
    font.family: Theme.font
    font.pixelSize: small ? Theme.fontSizeSmall : Theme.fontSize
    font.weight: Font.Medium
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
