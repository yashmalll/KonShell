import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

// Виджет панели «date»: только дата («вт, 21 окт.»). Клик — панель под часами
// с календарём.
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
        text: Qt.locale().toString(clock.date, "ddd, d MMM")
    }

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.dashboardOpen = !Ui.dashboardOpen
    }
}
