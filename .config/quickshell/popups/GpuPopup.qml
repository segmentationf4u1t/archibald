import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// One card per GPU (nvidia-smi via SysStats): utilization, history, VRAM, temperature, power, fan.
Item {
    id: root

    property var dropdown

    function gib(mib) {
        return (mib / 1024).toFixed(1);
    }

    implicitWidth: 400
    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col

        width: parent.width
        spacing: 14

        Repeater {
            // the count is stable between samples, so delegates (and their charts) survive updates
            model: SysStats.gpus.length

            delegate: ColumnLayout {
                id: card

                required property int index
                readonly property var g: SysStats.gpus[index]
                readonly property real util: g && !isNaN(g.util) ? g.util : 0
                readonly property bool hasVram: g && g.memTotal > 0

                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    implicitHeight: 1
                    color: Theme.obsidian
                    visible: card.index > 0
                }

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
                            text: "󰢮"
                            size: 22
                            color: Theme.magma
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            Layout.fillWidth: true
                            text: card.g ? card.g.name : ""
                            font.pixelSize: 16
                            font.weight: Font.Bold
                        }
                        Label {
                            text: "GPU " + card.index
                            small: true
                            muted: true
                        }
                    }

                    Label {
                        text: Math.round(card.util) + "%"
                        color: Theme.heat(card.util / 100)
                        font.pixelSize: 30
                        font.weight: Font.Bold
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
                        values: SysStats.gpuHistory[card.g ? card.g.index : -1] ?? []
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

                // ---- VRAM ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: card.hasVram

                    Label {
                        text: "VRAM"
                        small: true
                        muted: true
                    }
                    Meter {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        value: card.hasVram ? card.g.memUsed / card.g.memTotal : 0
                        fillColor: Theme.heat(value)
                    }
                    Label {
                        text: card.hasVram ? root.gib(card.g.memUsed) + " / " + root.gib(card.g.memTotal) + " GiB" : ""
                        small: true
                        font.weight: Font.Bold
                    }
                }

                // ---- temperature / power / fan (NaN = not reported, hidden) ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Chip {
                        visible: !!card.g && !isNaN(card.g.temp)
                        caption: "Temp."
                        value: card.g && !isNaN(card.g.temp) ? Math.round(card.g.temp) + " °C" : ""
                        valueColor: card.g && !isNaN(card.g.temp) ? Theme.heat((card.g.temp - 35) / 55) : Theme.text
                    }
                    Chip {
                        visible: !!card.g && !isNaN(card.g.power)
                        caption: I18n.tr("Power draw")
                        value: {
                            if (!card.g || isNaN(card.g.power))
                                return "";
                            const p = Math.round(card.g.power);
                            return isNaN(card.g.powerLimit) ? p + " W" : p + " / " + Math.round(card.g.powerLimit) + " W";
                        }
                    }
                    Chip {
                        visible: !!card.g && !isNaN(card.g.fan)
                        caption: I18n.tr("Fan")
                        value: card.g && !isNaN(card.g.fan) ? Math.round(card.g.fan) + "%" : ""
                    }
                }
            }
        }

        Label {
            visible: SysStats.gpus.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("No data from nvidia-smi")
            muted: true
        }
    }
}
