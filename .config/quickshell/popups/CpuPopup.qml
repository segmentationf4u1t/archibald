import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// CPU: usage, temperature / clocks / load, history charts, per-thread bars, top processes.
Item {
    id: root

    property var dropdown

    property string model: ""
    // hybrid CPUs list their P-core threads in sysfs ("0-15"); anything else = one group
    property int pThreads: -1

    readonly property var cores: SysStats.cores
    readonly property int pCount: pThreads >= 0 ? Math.min(pThreads, cores.length) : cores.length
    readonly property int eCount: cores.length - pCount
    readonly property real usage: SysStats.cpu

    function ghz(mhz) {
        return mhz > 0 ? (mhz / 1000).toFixed(2) + " GHz" : "–";
    }

    function formatUptime(s) {
        const d = Math.floor(s / 86400);
        const h = Math.floor(s % 86400 / 3600);
        const m = Math.floor(s % 3600 / 60);
        return (d > 0 ? d + " d " : "") + (d > 0 || h > 0 ? h + " h " : "") + m + " min";
    }

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    Component.onCompleted: SysStats.cpuDetailUsers++
    Component.onDestruction: SysStats.cpuDetailUsers--

    FileView {
        path: "/proc/cpuinfo"
        onLoaded: {
            const m = /^model name\s*:\s*(.+)$/m.exec(text());
            if (m)
                root.model = m[1].replace(/\((R|TM)\)/g, "").replace(/\s+CPU\b.*$/, "").replace(/\s+/g, " ").trim();
        }
    }

    FileView {
        path: "/sys/devices/cpu_core/cpus"
        blockLoading: true
        onLoaded: {
            const m = /(\d+)\s*$/.exec(text().trim());
            if (m)
                root.pThreads = Number(m[1]) + 1;
        }
    }

    component CoreBar: Item {
        property real value: 0

        Layout.fillWidth: true
        implicitHeight: 44

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Theme.obsidian
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(2, parent.height * Math.max(0, Math.min(1, value)))
            radius: 3
            color: Theme.heat(value)

            Behavior on height { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
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
                    text: "󰍛"
                    size: 22
                    color: Theme.magma
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    text: I18n.tr("Processor")
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
                Label {
                    Layout.fillWidth: true
                    text: root.model !== "" ? root.model : "…"
                    small: true
                    muted: true
                }
            }

            Label {
                text: Math.round(root.usage) + "%"
                color: Theme.heat(root.usage / 100)
                font.pixelSize: 30
                font.weight: Font.Bold
            }
        }

        // ---- stat chips ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Chip {
                Layout.preferredWidth: 70
                caption: "Temp."
                value: SysStats.cpuTemp >= 0 ? Math.round(SysStats.cpuTemp) + " °C" : "–"
                valueColor: SysStats.cpuTemp >= 0 ? Theme.heat((SysStats.cpuTemp - 35) / 60) : Theme.ash
            }
            Chip {
                Layout.preferredWidth: 70
                caption: I18n.tr("Avg clock")
                value: root.ghz(SysStats.cpuFreqAvg)
                compact: true
            }
            Chip {
                Layout.preferredWidth: 70
                caption: I18n.tr("Max clock")
                value: root.ghz(SysStats.cpuFreqMax)
                compact: true
            }
            Chip {
                Layout.preferredWidth: 118
                caption: I18n.tr("Load 1/5/15")
                value: SysStats.loadAvg.map(v => v.toFixed(2)).join(" ")
                compact: true
            }
        }

        // ---- history ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 92
                radius: 10
                color: Theme.crater

                AreaChart {
                    anchors.fill: parent
                    anchors.margins: 6
                    values: SysStats.cpuHistory
                    maxValue: 100
                    color: Theme.magma
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

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 10
                color: Theme.crater
                visible: SysStats.cpuTemp >= 0

                AreaChart {
                    anchors.fill: parent
                    anchors.margins: 5
                    values: SysStats.cpuTempHistory
                    maxValue: 100
                    gridLines: 0
                    lineWidth: 1.2
                    fillOpacity: 0.18
                    color: Theme.sulfur
                }
                Label {
                    x: 8
                    y: 2
                    text: I18n.tr("temperature")
                    small: true
                    color: Theme.ashDim
                }
            }
        }

        // ---- per-thread bars ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            SectionHeader {
                Layout.fillWidth: true
                text: I18n.tr("Threads (%1)", root.cores.length)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.pCount * 12
                    spacing: 4
                    visible: root.pCount > 0

                    Label {
                        text: root.eCount > 0 ? "P-cores" : I18n.tr("Cores")
                        small: true
                        color: Theme.ashDim
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Repeater {
                            model: root.pCount
                            delegate: CoreBar {
                                required property int index
                                value: (root.cores[index] ?? 0) / 100
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: root.eCount * 12
                    spacing: 4
                    visible: root.eCount > 0

                    Label {
                        text: "E-cores"
                        small: true
                        color: Theme.ashDim
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Repeater {
                            model: root.eCount
                            delegate: CoreBar {
                                required property int index
                                value: (root.cores[root.pCount + index] ?? 0) / 100
                            }
                        }
                    }
                }
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
                    readonly property var p: SysStats.topCpu[index]

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
                        value: proc.p ? proc.p.cpu / 100 : 0
                        fillColor: Theme.heat(value)
                    }
                    Label {
                        Layout.preferredWidth: 52
                        horizontalAlignment: Text.AlignRight
                        text: proc.p ? proc.p.cpu.toFixed(1) + "%" : ""
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
                text: I18n.tr("Uptime: %1", root.formatUptime(SysStats.uptime))
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
