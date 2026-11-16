import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

Column {
    id: root
    property string selectedMode: Countdown.active ? Countdown.state.mode : "timer"
    property int minutes: Settings.timer.defaultMinutes
    spacing: 16
    Row {
        spacing: 8
        Chip { text: "Таймер"; checked: root.selectedMode === "timer"; onClicked: root.selectedMode = "timer" }
        Chip { text: "Pomodoro"; checked: root.selectedMode === "pomodoro"; onClicked: root.selectedMode = "pomodoro" }
    }
    Rectangle {
        width: parent.width
        implicitHeight: timerFace.implicitHeight + 32
        color: Theme.color.surface
        radius: 20
        Column {
            id: timerFace
            width: parent.width - 32
            x: 16
            y: 16
            spacing: 12
            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Countdown.active ? Countdown.phaseName : root.selectedMode === "pomodoro" ? "Работа и перерывы" : "Обратный отсчёт"
                color: Theme.color.textMuted
            }
            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Countdown.active ? Countdown.text : String(root.selectedMode === "pomodoro" ? Settings.timer.workMinutes : root.minutes) + ":00"
                font.pixelSize: Theme.scaled(44)
                font.features: { "tnum": 1 }
                font.weight: Font.Medium
                color: Countdown.attention ? Theme.color.primary : Theme.color.text
            }
            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Countdown.active && Countdown.state.mode === "pomodoro" ? `Завершено интервалов: ${Countdown.state.completed}`
                    : Countdown.active && !Countdown.running && !Countdown.attention ? "На паузе" : ""
                visible: text !== ""
                color: Theme.color.textMuted
            }
        }
    }
    Flow {
        width: parent.width
        spacing: 8
        visible: root.selectedMode === "timer"
        Repeater {
            model: [5, 10, 15, 25, 50]
            Chip {
                required property int modelData
                text: `${modelData} мин`
                checked: root.minutes === modelData
                onClicked: root.minutes = modelData
            }
        }
    }
    Column {
        width: parent.width
        spacing: 8
        visible: root.selectedMode === "timer"
        StyledText { text: `Длительность: ${root.minutes} мин`; color: Theme.color.textMuted }
        Slider { width: parent.width; value: (root.minutes - 1) / 119; onMoved: value => root.minutes = Math.max(1, Math.round(value * 119 + 1)) }
    }
    StyledText {
        width: parent.width
        visible: root.selectedMode === "pomodoro"
        wrapMode: Text.Wrap
        text: `${Settings.timer.workMinutes} мин работы · ${Settings.timer.breakMinutes} мин отдыха · после четырёх интервалов ${Settings.timer.longBreakMinutes} мин отдыха`
        color: Theme.color.textMuted
    }
    Flow {
        width: parent.width
        spacing: 10
        TextButton {
            primary: true
            text: Countdown.active ? "Начать заново" : "Начать"
            onClicked: root.selectedMode === "pomodoro" ? Countdown.startPomodoro() : Countdown.start(root.minutes * 60)
        }
        TextButton {
            visible: Countdown.active && !Countdown.attention
            text: Countdown.running ? "Пауза" : "Продолжить"
            onClicked: Countdown.running ? Countdown.pause() : Countdown.resume()
        }
        TextButton {
            visible: Countdown.active
            text: Countdown.attention ? "Готово" : "Остановить"
            onClicked: Countdown.stop()
        }
        TextButton { text: "Настроить Pomodoro"; onClicked: Ui.openSettings("timer") }
    }
}
