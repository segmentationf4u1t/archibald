import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Memory: usage, segmented used / cache / buffers / free bar, history chart, swap, top processes by RSS.
Item {
    id: root

    property var dropdown

    readonly property real total: SysStats.memTotal
    readonly property real used: SysStats.memUsed
    readonly property real cache: SysStats.memCached
    readonly property real buffers: SysStats.memBuffers
    // available = free + cache + buffers (+ a little reclaimable slab), so this closes the bar to 100%
    readonly property real free: Math.max(0, total - used - cache - buffers)

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    Component.onCompleted: SysStats.memDetailUsers++
    Component.onDestruction: SysStats.memDetailUsers--

    // one segment of the bar; width is its share of the total
    component Segment: Rectangle {
        property real part: 0

        height: parent.height
        width: Math.max(0, Math.floor((parent.width - 6) * (root.total > 0 ? part / root.total : 0)))
        visible: width >= 1
        radius: 4

        Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    }

    component LegendItem: RowLayout {
        property color dot
        property string name
        property real bytes

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            implicitWidth: 10
            implicitHeight: 10
            radius: 3
            color: dot
        }
        Label {
            Layout.fillWidth: true
            text: name
            small: true
            muted: true
        }
        Label {
            text: SysStats.formatBytes(bytes)
            small: true
            font.weight: Font.Bold
        }
    }

    ColumnLayout {
        id: col

        width: parent.width
        spacing: 14

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: 10
                color: Theme.lava

                Glyph {
                    anchors.centerIn: parent
                    text: Icons.glyph("device-sd-card")
                    size: 22
                    color: Theme.magma
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    text: I18n.tr("Memory")
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
                Label {
                    Layout.fillWidth: true
                    text: SysStats.formatBytes(root.used) + " / " + SysStats.formatBytes(root.total)
                    small: true
                    muted: true
                }
            }

            Label {
                text: Math.round(SysStats.mem) + "%"
                color: Theme.heat(SysStats.mem / 100)
                font.pixelSize: 30
                font.weight: Font.Bold
            }
        }

        // ---- segmented bar + legend ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Item {
                id: bar

                Layout.fillWidth: true
                implicitHeight: 16

                Row {
                    anchors.fill: parent
                    spacing: 2

                    Segment {
                        part: root.used
                        color: Theme.ember
                    }
                    Segment {
                        part: root.cache
                        color: Theme.alpha(Theme.sulfur, 0.55)
                    }
                    Segment {
                        part: root.buffers
                        color: Theme.ash
                    }
                    Segment {
                        part: root.free
                        color: Theme.obsidian
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 20
                rowSpacing: 6

                LegendItem {
                    dot: Theme.ember
                    name: I18n.tr("Used")
                    bytes: root.used
                }
                LegendItem {
                    dot: Theme.alpha(Theme.sulfur, 0.55)
                    name: "Cache"
                    bytes: root.cache
                }
                LegendItem {
                    dot: Theme.ash
                    name: I18n.tr("Buffers")
                    bytes: root.buffers
                }
                LegendItem {
                    dot: Theme.obsidian
                    name: I18n.tr("Free")
                    bytes: root.free
                }
            }
        }

        // ---- history ----
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 92
            radius: 10
            color: Theme.crater

            AreaChart {
                anchors.fill: parent
                anchors.margins: 6
                values: SysStats.memHistory
                maxValue: 100
                color: Theme.ember
            }
            Label {
                x: 8
                y: 4
                text: "2 min"
                small: true
                color: Theme.ashDim
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 8
                y: 4
                text: I18n.tr("usage")
                small: true
                color: Theme.ashDim
            }
        }

        // ---- swap ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            SectionHeader {
                Layout.fillWidth: true
                text: "Swap"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                visible: SysStats.swapTotal > 0

                Meter {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    value: SysStats.swapTotal > 0 ? SysStats.swapUsed / SysStats.swapTotal : 0
                    fillColor: Theme.heat(value)
                }
                Label {
                    text: SysStats.formatBytes(SysStats.swapUsed) + " / " + SysStats.formatBytes(SysStats.swapTotal)
                    small: true
                    muted: true
                }
            }

            Label {
                visible: SysStats.swapTotal <= 0
                text: I18n.tr("No swap")
                small: true
                muted: true
            }
        }

        // ---- top processes ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            SectionHeader {
                Layout.fillWidth: true
                text: I18n.tr("Processes")
            }

            Repeater {
                model: 6
                delegate: RowLayout {
                    id: proc

                    required property int index
                    readonly property var p: SysStats.topMem[index]
                    readonly property real maxRss: SysStats.topMem.length > 0 ? SysStats.topMem[0].rss : 1

                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    spacing: 10
                    opacity: p ? 1 : 0

                    Label {
                        Layout.fillWidth: true
                        text: proc.p ? proc.p.name : ""
                    }
                    Meter {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 4
                        Layout.alignment: Qt.AlignVCenter
                        value: proc.p ? proc.p.rss / proc.maxRss : 0
                        fillColor: Theme.ember
                    }
                    Label {
                        Layout.preferredWidth: 64
                        horizontalAlignment: Text.AlignRight
                        text: proc.p ? SysStats.formatBytes(proc.p.rss) : ""
                        small: true
                        muted: true
                    }
                }
            }
        }

        // ---- footer ----
        RowLayout {
            Layout.fillWidth: true

            Label {
                Layout.fillWidth: true
                text: I18n.tr("Total: %1", SysStats.formatBytes(root.total))
                small: true
                muted: true
            }
            FooterLink {
                text: I18n.tr("System monitor…")
                command: SysStats.monitorCommand
                dropdown: root.dropdown
            }
        }
    }
}
