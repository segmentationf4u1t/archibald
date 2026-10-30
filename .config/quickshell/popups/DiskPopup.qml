import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Disks: per physical disk activity (% of time busy), read / write throughput with history,
// temperature and totals since boot (/proc/diskstats via SysStats); usage of mounted local filesystems.
Item {
    id: root

    property var dropdown

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    Component.onCompleted: SysStats.diskDetailUsers++
    Component.onDestruction: SysStats.diskDetailUsers--

    ColumnLayout {
        id: col

        width: parent.width
        spacing: 14

        // ---- header: all disks ----
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
                    text: Icons.glyph("server")
                    size: 22
                    color: Theme.magma
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    text: I18n.tr("Disks")
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
                Label {
                    Layout.fillWidth: true
                    text: I18n.tr("Read %1 · write %2", SysStats.formatRate(SysStats.diskRead), SysStats.formatRate(SysStats.diskWrite))
                    small: true
                    muted: true
                }
            }

            Label {
                text: Math.round(SysStats.diskUtil) + "%"
                color: Theme.heat(SysStats.diskUtil / 100)
                font.pixelSize: 30
                font.weight: Font.Bold
            }
        }

        // ---- one card per disk ----
        Repeater {
            // the count is stable between samples, so delegates (and their charts) survive updates
            model: SysStats.disks.length

            delegate: ColumnLayout {
                id: card

                required property int index
                readonly property var d: SysStats.disks[index]
                readonly property real temp: d && SysStats.diskTemps[d.name] !== undefined ? SysStats.diskTemps[d.name] : NaN

                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.obsidian
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            Layout.fillWidth: true
                            text: card.d ? card.d.model || card.d.name : ""
                            font.weight: Font.Bold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: card.d ? card.d.name + (card.d.size > 0 ? " · " + SysStats.formatBytes(card.d.size) : "") : ""
                            small: true
                            muted: true
                        }
                    }

                    Label {
                        text: card.d ? Math.round(card.d.util) + "%" : ""
                        color: Theme.heat(card.d ? card.d.util / 100 : 0)
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    RateChart {
                        caption: I18n.tr("R")
                        tint: Theme.magma
                        rate: card.d ? card.d.read : 0
                        history: card.d ? SysStats.diskReadHistory[card.d.name] ?? [] : []
                    }

                    RateChart {
                        caption: I18n.tr("W")
                        tint: Theme.sulfur
                        rate: card.d ? card.d.write : 0
                        history: card.d ? SysStats.diskWriteHistory[card.d.name] ?? [] : []
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Chip {
                        visible: !isNaN(card.temp)
                        caption: "Temp."
                        value: isNaN(card.temp) ? "" : Math.round(card.temp) + " °C"
                        valueColor: isNaN(card.temp) ? Theme.text : Theme.heat((card.temp - 30) / 45)
                    }
                    Chip {
                        caption: I18n.tr("Total read")
                        value: card.d ? SysStats.formatBytes(card.d.readTotal) : ""
                    }
                    Chip {
                        caption: I18n.tr("Total written")
                        value: card.d ? SysStats.formatBytes(card.d.writtenTotal) : ""
                    }
                }
            }
        }

        Label {
            visible: SysStats.disks.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("No disks found")
            muted: true
        }

        // ---- mounted local filesystems ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: SysStats.filesystems.length > 0

            SectionHeader {
                Layout.fillWidth: true
                text: I18n.tr("Filesystems")
            }

            Repeater {
                model: SysStats.filesystems.length

                delegate: RowLayout {
                    id: fsRow

                    required property int index
                    readonly property var fs: SysStats.filesystems[index]
                    // like df's Use%: reserved blocks count as neither used nor available
                    readonly property real usage: fs && fs.used + fs.avail > 0 ? fs.used / (fs.used + fs.avail) : 0

                    Layout.fillWidth: true
                    Layout.preferredHeight: 22
                    spacing: 10

                    Label {
                        Layout.preferredWidth: 72
                        text: fsRow.fs ? fsRow.fs.target : ""
                    }
                    Meter {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        value: fsRow.usage
                        fillColor: Theme.heat(fsRow.usage)
                    }
                    Label {
                        text: fsRow.fs ? SysStats.formatBytes(fsRow.fs.used) + " / " + SysStats.formatBytes(fsRow.fs.size) : ""
                        small: true
                        muted: true
                    }
                }
            }
        }

        // ---- footer ----
        RowLayout {
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }
            FooterLink {
                text: I18n.tr("System monitor…")
                command: SysStats.monitorCommand
                dropdown: root.dropdown
            }
        }
    }
}
