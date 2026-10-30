import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components

// Themed DBus menu of the tray item the bar points at (bar.trayMenuItem). Submenus open in place.
// Width follows the longest entry (min 220 px).
Item {
    id: root

    property var dropdown
    readonly property var trayItem: dropdown ? dropdown.bar.trayMenuItem : null
    property var stack: []      // opened submenu entries

    function plain(text) {
        return text.replace(/_([^_])/g, "$1");   // drop mnemonic underscores
    }

    implicitWidth: Math.max(220, col.implicitWidth)
    implicitHeight: col.implicitHeight

    onTrayItemChanged: stack = []

    QsMenuOpener {
        id: opener
        menu: root.stack.length > 0 ? root.stack[root.stack.length - 1] : root.trayItem?.menu ?? null
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 2

        Label {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.bottomMargin: 4
            visible: text !== ""
            text: root.trayItem ? (root.trayItem.tooltipTitle || root.trayItem.title || root.trayItem.id) : ""
            small: true
            muted: true
        }

        ListItem {
            Layout.fillWidth: true
            implicitWidth: 200
            visible: root.stack.length > 0
            icon: Icons.glyph("chevron-left")
            title: root.stack.length > 0 ? root.plain(root.stack[root.stack.length - 1].text) : ""
            onClicked: root.stack = root.stack.slice(0, -1)
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: entry

                required property QsMenuEntry modelData

                Layout.fillWidth: true
                implicitWidth: row.implicitWidth + 20
                implicitHeight: modelData.isSeparator ? 9 : 34

                Rectangle {
                    anchors.centerIn: parent
                    visible: entry.modelData.isSeparator
                    width: parent.width - 16
                    height: 1
                    color: Theme.obsidian
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !entry.modelData.isSeparator
                    radius: 8
                    color: area.containsMouse && entry.modelData.enabled ? Theme.lava : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    RowLayout {
                        id: row
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Glyph {
                            visible: entry.modelData.buttonType !== QsMenuButtonType.None
                            text: Icons.glyph(entry.modelData.checkState === Qt.Checked
                                ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "circle-dot" : "square-check")
                                : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "circle" : "square"))
                            color: entry.modelData.checkState === Qt.Checked ? Theme.magma : Theme.ash
                        }

                        IconImage {
                            visible: entry.modelData.icon !== ""
                            source: entry.modelData.icon
                            implicitSize: 16
                        }

                        Label {
                            Layout.fillWidth: true
                            text: root.plain(entry.modelData.text)
                            color: entry.modelData.enabled ? Theme.text : Theme.ashDim
                        }

                        Glyph {
                            visible: entry.modelData.hasChildren
                            text: Icons.glyph("chevron-right")
                            color: Theme.ash
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: entry.modelData.enabled
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                root.stack = root.stack.concat([entry.modelData]);
                                return;
                            }
                            entry.modelData.triggered();
                            root.dropdown.close();
                        }
                    }
                }
            }
        }
    }
}
