import QtQuick
import qs.config
import qs.services
import qs.widgets

// Виджет панели «network»: скорость приёма и отдачи. Клик — панель под часами
// с подробностями (адреса, график). Опрос сети идёт, только пока виджет на панели
// или панель открыта (services/NetStats.qml).
Rectangle {
    id: root

    implicitWidth: row.implicitWidth + Theme.spacing.sm * 2
    implicitHeight: Math.max(row.implicitHeight + Theme.spacing.xs * 2, Settings.bar.height - 8)
    radius: Theme.radius.control
    color: area.containsMouse ? Theme.color.hover : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.sm

        Rate {
            arrow: "↓"
            value: NetStats.rxRate
            accent: Theme.color.primary
        }

        Rate {
            arrow: "↑"
            value: NetStats.txRate
            accent: Theme.color.tertiary
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.dashboardOpen = !Ui.dashboardOpen
    }

    component Rate: Row {
        id: rate

        property string arrow
        property real value: 0
        property color accent

        anchors.verticalCenter: parent?.verticalCenter
        spacing: 2

        StyledText {
            text: rate.arrow
            color: rate.accent
            font.pixelSize: Theme.font.caption
            font.weight: Theme.font.medium
        }

        // Ширина под «999 КБ/с»: значения меняются каждую секунду, виджет не прыгает.
        StyledText {
            width: Math.max(implicitWidth, 62)
            text: NetStats.bytes(rate.value, true)
            font.pixelSize: Theme.font.caption
            font.features: { "tnum": 1 }
        }
    }
}
