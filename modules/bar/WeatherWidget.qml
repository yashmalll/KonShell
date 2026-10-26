import QtQuick
import qs.config
import qs.services
import qs.widgets

// Виджет панели «weather»: значок и температура. Клик открывает панель под часами
// с прогнозом. Пока город не указан или погода выключена — скрыт.
Rectangle {
    id: root

    visible: Settings.weather.enabled && Weather.available && Weather.loadState !== "idle"
    implicitWidth: visible ? row.implicitWidth + Theme.spacing.sm * 2 : 0
    implicitHeight: Math.max(row.implicitHeight + Theme.spacing.xs * 2, Settings.bar.height - 8)
    radius: Theme.radius.control
    color: area.containsMouse ? Theme.color.hover : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.xs

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Weather.icon
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.degrees(Weather.temperature)
            font.weight: Theme.font.medium
            font.features: { "tnum": 1 }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.dashboardOpen = !Ui.dashboardOpen
    }
}
