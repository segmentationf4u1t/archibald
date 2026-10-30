import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Throughput: caption + current rate over a self-scaling history chart (network / disk dropdowns).
ColumnLayout {
    id: chart

    property string caption: ""
    property color tint: Theme.magma
    property real rate: 0
    property var history: []

    Layout.fillWidth: true
    Layout.preferredWidth: 1
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Label {
            text: chart.caption
            color: chart.tint
            font.weight: Font.Bold
        }

        Label {
            Layout.fillWidth: true
            text: SysStats.formatRate(chart.rate)
            small: true
        }
    }

    AreaChart {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        values: chart.history
        maxValue: 0
        color: chart.tint
    }
}
