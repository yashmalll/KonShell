import QtQuick
import qs.config
import qs.services
import qs.widgets

// Виджет панели «sysmon»: загрузка процессора, память, температура.
// Высокие значения — цветом предупреждения. Клик открывает панель под часами,
// там подробнее.
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
        spacing: Theme.spacing.md

        Stat {
            label: "ЦП"
            value: `${Math.round(SystemStats.cpu * 100)}%`
            warn: SystemStats.cpu > 0.85
        }

        Stat {
            label: "ОЗУ"
            value: `${Math.round(SystemStats.memory * 100)}%`
            warn: SystemStats.memory > 0.9
        }

        Stat {
            label: ""
            value: `${Math.round(SystemStats.temperature)}°`
            warn: SystemStats.temperature >= 85
            visible: SystemStats.temperature > 0
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Ui.dashboardOpen = !Ui.dashboardOpen
    }

    component Stat: Row {
        property string label
        property string value
        property bool warn: false

        spacing: Theme.spacing.xs

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            visible: text !== ""
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: parent.warn ? Theme.color.warning : Theme.color.text
            font.pixelSize: Theme.font.caption
            font.weight: Theme.font.medium
            font.features: { "tnum": 1 }
        }
    }
}
