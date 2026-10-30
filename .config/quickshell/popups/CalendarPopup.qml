import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Month grid (Monday first) with ISO week numbers; wheel / arrows change the month,
// clicking the title jumps back to today.
ColumnLayout {
    id: root

    property var dropdown
    readonly property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()      // 0-based

    function shift(delta) {
        const d = new Date(year, month + delta, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - yearStart) / 86400000 + 1) / 7);
    }

    // 42 cells starting at the Monday on/before the 1st
    readonly property var cells: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(year, month, 1 - offset + i));
        return out;
    }

    spacing: 10
    implicitWidth: 300

    RowLayout {
        Layout.fillWidth: true

        IconButton {
            icon: Icons.glyph("chevron-left")
            onClicked: root.shift(-1)
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: I18n.locale.standaloneMonthName(root.month) + " " + root.year
            color: Theme.magma
            font.weight: Font.Bold

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.year = root.today.getFullYear();
                    root.month = root.today.getMonth();
                }
            }
        }

        IconButton {
            icon: Icons.glyph("chevron-right")
            onClicked: root.shift(1)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 8
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: 7
            delegate: Label {
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                small: true
                font.weight: Font.Bold
                color: Theme.sulfur
                text: I18n.locale.dayName((index + 1) % 7, Locale.ShortFormat)
            }
        }

        Label {
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignHCenter
            small: true
            muted: true
            text: "W"
        }

        // 6 rows x (7 days + ISO week)
        Repeater {
            model: 48

            delegate: Item {
                id: cell

                required property int index
                readonly property int row: Math.floor(index / 8)
                readonly property bool isWeek: index % 8 === 7
                readonly property date day: root.cells[row * 7 + Math.min(index % 8, 6)]
                readonly property bool inMonth: day.getMonth() === root.month
                readonly property bool isToday: !isWeek && day.toDateString() === root.today.toDateString()

                Layout.fillWidth: !isWeek
                Layout.preferredWidth: isWeek ? 30 : 34
                implicitHeight: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    visible: cell.isToday
                    color: Theme.magma
                }

                Label {
                    anchors.centerIn: parent
                    small: cell.isWeek
                    text: cell.isWeek ? "W" + root.isoWeek(cell.day) : cell.day.getDate()
                    font.weight: cell.isToday ? Font.Bold : Font.Medium
                    color: cell.isWeek ? Theme.ashDim
                        : cell.isToday ? Theme.basalt
                        : cell.inMonth ? Theme.text
                        : Theme.ashDim
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => root.shift(event.angleDelta.y > 0 ? -1 : 1)
    }
}
