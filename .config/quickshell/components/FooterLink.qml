import QtQuick
import qs

// Muted link at the bottom of a dropdown: starts `command` (argv list, via Launch.exec), then closes `dropdown`.
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
            Launch.exec(root.command);
            if (root.dropdown)
                root.dropdown.close();
        }
    }
}
