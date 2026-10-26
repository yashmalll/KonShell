import QtQuick
import qs.config
import qs.services
import qs.widgets

// Карточка «Система» в панели под часами: процессор, память, температура, диск.
// Полоса — доля; при высоких значениях — цвет предупреждения.
Column {
    id: root

    // «950 МБ», «3,4 ГБ», «389 ГБ», «1,2 ТБ».
    function size(gib) {
        if (gib < 1)
            return `${Math.round(gib * 1024)} МБ`;
        if (gib >= 1024)
            return `${(gib / 1024).toFixed(1).replace(".", ",")} ТБ`;
        return gib < 10 ? `${gib.toFixed(1).replace(".", ",")} ГБ` : `${Math.round(gib)} ГБ`;
    }

    spacing: Theme.spacing.sm

    SectionLabel {
        text: "Система"
    }

    StatBar {
        label: "Процессор"
        value: SystemStats.cpu
        detail: `${Math.round(SystemStats.cpu * 100)}%`
        warn: SystemStats.cpu > 0.85
    }

    StatBar {
        label: "Память"
        value: SystemStats.memory
        detail: `${root.size(SystemStats.memoryUsedGiB)} из ${root.size(SystemStats.memoryTotalGiB)}`
        warn: SystemStats.memory > 0.9
    }

    StatBar {
        label: "Температура"
        // Шкала до 100 °C.
        value: SystemStats.temperature / 100
        detail: `${Math.round(SystemStats.temperature)} °C`
        warn: SystemStats.temperature >= 85
        visible: SystemStats.temperature > 0
    }

    StatBar {
        label: "Подкачка"
        value: SystemStats.swap
        detail: `${root.size(SystemStats.swapUsedGiB)} из ${root.size(SystemStats.swapTotalGiB)}`
        warn: SystemStats.swap > 0.5
        visible: SystemStats.swapTotalGiB > 0
    }

    SectionLabel {
        topPadding: Theme.spacing.xs
        text: "Диски"
        visible: SystemStats.disks.length > 0
    }

    // Разделы с файлами: корень, /home, /boot и любые другие смонтированные.
    Repeater {
        model: SystemStats.disks

        StatBar {
            required property var modelData

            label: `${modelData.name}  ${modelData.mount}`
            value: modelData.used
            detail: `свободно ${root.size(modelData.freeGiB)} из ${root.size(modelData.totalGiB)}`
            warn: modelData.used > 0.9
        }
    }

    component StatBar: Column {
        id: stat

        property string label
        property string detail
        property real value: 0
        property bool warn: false

        width: root.width
        spacing: Theme.spacing.xxs

        Item {
            width: parent.width
            height: labelText.implicitHeight

            // Подпись слева обрезается многоточием, а не наезжает на значение справа.
            StyledText {
                id: labelText

                width: Math.max(0, parent.width - detailText.implicitWidth - Theme.spacing.sm)
                text: stat.label
                font.pixelSize: Theme.font.caption
            }

            StyledText {
                id: detailText

                anchors.right: parent.right
                text: stat.detail
                color: stat.warn ? Theme.color.warning : Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                font.features: { "tnum": 1 }
            }
        }

        Rectangle {
            width: parent.width
            height: 4
            radius: Theme.radius.full
            color: Theme.color.surfaceVariant

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, stat.value))
                height: parent.height
                radius: parent.radius
                color: stat.warn ? Theme.color.warning : Theme.color.primary

                Behavior on width {
                    NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: Theme.anim.normal }
                }
            }
        }
    }
}
