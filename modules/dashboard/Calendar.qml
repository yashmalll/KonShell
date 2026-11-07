import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Календарь на месяц: листается стрелками и колесом мыши, сегодня — акцентный круг.
// Первый день недели — clock.weekStart, номера недель — clock.showWeekNumbers.
Column {
    id: root

    readonly property var locale: Qt.locale()
    readonly property date today: clock.date
    property int year: today.getFullYear()
    property int month: today.getMonth()
    // Выбранный день: под сеткой — его события и поле добавления.
    property var selected: null

    readonly property bool showingToday: year === today.getFullYear() && month === today.getMonth()
    // 0 — воскресенье, как у Date.getDay().
    readonly property int firstWeekday: Settings.clock.weekStart % 7
    readonly property bool weekNumbers: Settings.clock.showWeekNumbers
    readonly property int cell: Math.floor((width - (weekNumbers ? cellWeek : 0)) / 7)
    readonly property int cellWeek: 28

    // 42 дня (6 недель), начиная с первого дня недели, в которую попадает 1-е число.
    readonly property var days: {
        const first = new Date(year, month, 1);
        const offset = (first.getDay() - firstWeekday + 7) % 7;
        const list = [];
        for (let i = 0; i < 42; i++)
            list.push(new Date(year, month, 1 - offset + i));
        return list;
    }

    function shift(months) {
        const d = new Date(year, month + months, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    function goToday() {
        year = today.getFullYear();
        month = today.getMonth();
    }

    // Номер недели по ISO 8601.
    function isoWeek(date) {
        const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
        const day = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    spacing: Theme.spacing.sm

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Месяц и год, стрелки.
    Item {
        width: parent.width
        height: 32

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const name = root.locale.standaloneMonthName(root.month, Locale.LongFormat);
                return name.charAt(0).toUpperCase() + name.slice(1) + " " + root.year;
            }
            font.pixelSize: Theme.font.title
            font.weight: Theme.font.medium
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xxs

            TextButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Сегодня"
                visible: !root.showingToday
                onClicked: root.goToday()
            }

            IconButton {
                icon: "go-previous-symbolic"
                Accessible.name: "Предыдущий месяц"
                onClicked: root.shift(-1)
            }

            IconButton {
                icon: "go-next-symbolic"
                Accessible.name: "Следующий месяц"
                onClicked: root.shift(1)
            }
        }
    }

    // Дни недели.
    Row {
        x: root.weekNumbers ? root.cellWeek : 0

        Repeater {
            model: 7

            StyledText {
                required property int index

                readonly property int weekday: (root.firstWeekday + index) % 7

                width: root.cell
                horizontalAlignment: Text.AlignHCenter
                text: root.locale.dayName(weekday, Locale.ShortFormat)
                color: weekday === 0 || weekday === 6 ? Theme.color.tertiary : Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                font.weight: Theme.font.medium
            }
        }
    }

    // Сетка: 6 недель.
    Column {
        id: grid

        width: parent.width

        Repeater {
            model: 6

            Row {
                id: week

                required property int index

                StyledText {
                    width: root.cellWeek
                    height: root.cell
                    horizontalAlignment: Text.AlignHCenter
                    text: root.isoWeek(root.days[week.index * 7])
                    color: Theme.color.textDisabled
                    font.pixelSize: Theme.font.caption
                    font.features: { "tnum": 1 }
                    visible: root.weekNumbers
                }

                Repeater {
                    model: 7

                    Item {
                        id: day

                        required property int index

                        readonly property date date: root.days[week.index * 7 + index]
                        readonly property bool inMonth: date.getMonth() === root.month
                        readonly property bool isToday: root.sameDay(date, root.today)
                        readonly property bool weekend: date.getDay() === 0 || date.getDay() === 6
                        readonly property bool isSelected: root.selected !== null && root.sameDay(date, root.selected)
                        readonly property bool hasEvents: Events.hasEvents(date)

                        width: root.cell
                        height: root.cell

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) - 4
                            height: width
                            radius: Theme.radius.full
                            color: day.isToday ? Theme.color.primary
                                : dayArea.containsMouse ? Theme.color.hover
                                : "transparent"
                            border.width: day.isSelected ? 2 : 0
                            border.color: Theme.color.focus

                            Behavior on color {
                                ColorAnimation { duration: Theme.anim.fast }
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: day.date.getDate()
                            color: day.isToday ? Theme.color.primaryText
                                : !day.inMonth ? Theme.color.textDisabled
                                : day.weekend ? Theme.color.tertiary
                                : Theme.color.text
                            font.weight: day.isToday ? Theme.font.medium : Theme.font.regular
                            font.features: { "tnum": 1 }
                        }

                        // Точка под числом: в этот день есть события.
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 4
                            width: 4
                            height: 4
                            radius: 2
                            visible: day.hasEvents
                            color: day.isToday ? Theme.color.primaryText : Theme.color.primary
                        }

                        MouseArea {
                            id: dayArea

                            anchors.fill: parent
                            hoverEnabled: true
                            // День соседнего месяца — перейти к нему.
                            onClicked: {
                                if (!day.inMonth)
                                    root.shift(day.date < new Date(root.year, root.month, 1) ? -1 : 1);
                                root.selected = day.isSelected ? null : day.date;
                                if (root.selected)
                                    Qt.callLater(() => titleInput.forceActiveFocus());
                            }
                        }
                    }
                }
            }
        }

        // Колесо листает месяцы: месяц на щелчок колеса (120). Тачпад шлёт много
        // мелких событий — они копятся до того же порога.
        WheelHandler {
            property real accumulated: 0

            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                accumulated += event.angleDelta.y;
                if (Math.abs(accumulated) >= 120) {
                    root.shift(accumulated > 0 ? -1 : 1);
                    accumulated = 0;
                }
            }
        }
    }

    // События выбранного дня и добавление нового.
    Column {
        id: eventsBox

        width: parent.width
        spacing: Theme.spacing.xs
        visible: root.selected !== null

        function submit() {
            if (root.selected && Events.add(root.selected, timeInput.text, titleInput.text)) {
                titleInput.text = "";
                timeInput.text = "";
            }
        }

        StyledText {
            x: Theme.spacing.xs
            text: root.selected ? Qt.formatDate(root.selected, "d MMMM, dddd") : ""
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
            font.weight: Theme.font.medium
        }

        Repeater {
            model: root.selected ? Events.forDay(root.selected) : []

            Item {
                id: row

                required property var modelData

                width: eventsBox.width
                height: 28

                StyledText {
                    id: timeLabel

                    x: Theme.spacing.xs
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    text: row.modelData.time || "—"
                    color: Theme.color.textMuted
                    font.features: { "tnum": 1 }
                }

                StyledText {
                    anchors.left: timeLabel.right
                    anchors.right: removeButton.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.title
                    elide: Text.ElideRight
                }

                IconButton {
                    id: removeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "edit-delete-symbolic"
                    Accessible.name: "Удалить событие"
                    onClicked: Events.remove(row.modelData.id)
                }
            }
        }

        StyledText {
            x: Theme.spacing.xs
            visible: root.selected !== null && Events.forDay(root.selected).length === 0
            text: "Событий нет"
            color: Theme.color.textDisabled
            font.pixelSize: Theme.font.caption
        }

        // Время (необязательно, ЧЧ:ММ) и название; Enter — добавить.
        Rectangle {
            width: parent.width
            height: 34
            radius: Theme.radius.control
            color: Theme.color.surface
            border.width: timeInput.activeFocus || titleInput.activeFocus ? 2 : 1
            border.color: timeInput.activeFocus || titleInput.activeFocus ? Theme.color.focus : Theme.color.border

            TextInput {
                id: timeInput

                x: Theme.spacing.md
                width: 46
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.color.text
                selectionColor: Theme.color.selection
                selectedTextColor: Theme.color.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.body
                maximumLength: 5
                clip: true
                activeFocusOnTab: true
                Keys.onReturnPressed: titleInput.forceActiveFocus()
                Keys.onEnterPressed: titleInput.forceActiveFocus()

                StyledText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "ЧЧ:ММ"
                    color: Theme.color.textMuted
                    visible: timeInput.text === ""
                }
            }

            TextInput {
                id: titleInput

                anchors.left: timeInput.right
                anchors.leftMargin: Theme.spacing.sm
                anchors.right: addButton.left
                anchors.rightMargin: Theme.spacing.xs
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.color.text
                selectionColor: Theme.color.selection
                selectedTextColor: Theme.color.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.body
                clip: true
                activeFocusOnTab: true
                Keys.onReturnPressed: eventsBox.submit()
                Keys.onEnterPressed: eventsBox.submit()

                StyledText {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Новое событие"
                    color: Theme.color.textMuted
                    visible: titleInput.text === ""
                }
            }

            IconButton {
                id: addButton

                anchors.right: parent.right
                anchors.rightMargin: Theme.spacing.xs
                anchors.verticalCenter: parent.verticalCenter
                icon: "list-add-symbolic"
                Accessible.name: "Добавить событие"
                onClicked: eventsBox.submit()
            }
        }
    }
}
