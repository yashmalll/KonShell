import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Часы с табличными цифрами: ширина не прыгает при смене минут.
// Клик открывает панель с календарём, плеером и заметками (modules/dashboard).
Rectangle {
    id: root

    implicitWidth: label.implicitWidth + Theme.spacing.md * 2
    implicitHeight: Math.max(label.implicitHeight + Theme.spacing.xs * 2, Settings.bar.height - 8)
    radius: Theme.radius.control
    color: Ui.dashboardOpen ? Theme.color.pressed
        : area.containsMouse ? Theme.color.hover
        : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        // Через локаль системы: Qt.formatDateTime пишет дни и месяцы по-английски.
        text: Qt.locale().toString(clock.date, Settings.clock.format)
        font.weight: Theme.font.medium
        font.features: { "tnum": 1 }
    }

    SystemClock {
        id: clock
        precision: Settings.clock.format.includes("s") ? SystemClock.Seconds : SystemClock.Minutes
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.dashboardOpen = !Ui.dashboardOpen
    }
}
