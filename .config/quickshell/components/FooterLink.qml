import QtQuick
import Quickshell
import qs

// Muted link at the bottom of a dropdown: starts `command` (argv list) detached, then closes `dropdown`.
Label {
    id: root

    required property var command
    property var dropdown

    small: true
    color: hover.hovered ? Theme.magma : Theme.ash

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            Quickshell.execDetached(root.command);
            if (root.dropdown)
                root.dropdown.close();
        }
    }
}
