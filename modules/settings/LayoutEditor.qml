import QtQuick
import qs.config
import qs.widgets

// Раскладка элементов по зонам для окна настроек: какие элементы где и в каком
// порядке; не указанные ни в одной зоне — скрыты. Общая для зон панели
// (BarLayoutEditor) и колонок панели под часами (DashboardLayoutEditor).
// Изменения сразу видны на месте — оно и есть предпросмотр.
//
//   target   — объект настроек со списками по зонам;
//   zones    — [{ key, name }] — ключи списков в target и подписи;
//   catalog  — [{ id, name, icon, hint }] — все элементы;
//   defaults — { ключ зоны: [id…] } — для кнопки сброса.
Column {
    id: root

    required property var target
    required property var zones
    required property var catalog
    required property var defaults
    property string emptyText: "Пусто — добавьте элемент из скрытых ниже или перенесите стрелкой"

    width: parent?.width ?? 0

    readonly property var placed: zones.reduce((all, z) => all.concat(target[z.key]), [])
    readonly property var hidden: catalog.filter(w => !placed.includes(w.id))

    function find(id) {
        return catalog.find(w => w.id === id) ?? null;
    }

    function ids(zone) {
        return target[zone].slice();
    }

    // Все зоны записываются вместе и без повторов: перестановка — это одно изменение,
    // а не две записи подряд, между которыми настройки могли бы перечитаться из файла.
    function apply(layout) {
        const seen = new Set();
        for (const zone of zones) {
            const list = (layout[zone.key] ?? ids(zone.key)).filter(id => !seen.has(id));
            list.forEach(id => seen.add(id));
            layout[zone.key] = list;
        }
        for (const zone of zones) {
            if (JSON.stringify(layout[zone.key]) !== JSON.stringify(ids(zone.key)))
                target[zone.key] = layout[zone.key];
        }
    }

    function move(zone, index, delta) {
        const list = ids(zone);
        const to = index + delta;
        if (to < 0 || to >= list.length)
            return;
        [list[index], list[to]] = [list[to], list[index]];
        apply({ [zone]: list });
    }

    // В соседнюю зону: влево — в конец левой соседки, вправо — в начало правой,
    // чтобы элемент оказался рядом с тем местом, где был.
    function moveZone(zone, index, direction) {
        const order = zones.map(z => z.key);
        const targetZone = order[order.indexOf(zone) + direction];
        if (!targetZone)
            return;
        const from = ids(zone);
        const [id] = from.splice(index, 1);
        const to = ids(targetZone);
        if (direction < 0)
            to.push(id);
        else
            to.unshift(id);
        apply({ [zone]: from, [targetZone]: to });
    }

    function hide(zone, index) {
        const list = ids(zone);
        list.splice(index, 1);
        apply({ [zone]: list });
    }

    function show(id, zone) {
        apply({ [zone]: ids(zone).concat([id]) });
    }

    function reset() {
        const layout = {};
        for (const zone of zones)
            layout[zone.key] = (defaults[zone.key] ?? []).slice();
        apply(layout);
    }

    spacing: Theme.spacing.xl

    Repeater {
        model: root.zones

        Column {
            id: zoneColumn

            required property var modelData
            required property int index

            readonly property var zoneIds: root.target[modelData.key]

            width: root.width
            spacing: Theme.spacing.sm

            SectionLabel {
                text: zoneColumn.modelData.name
            }

            Rectangle {
                width: parent.width
                implicitHeight: zoneList.implicitHeight + Theme.spacing.xs * 2
                radius: Theme.radius.control
                color: Theme.color.surface

                Column {
                    id: zoneList

                    x: Theme.spacing.xs
                    y: Theme.spacing.xs
                    width: parent.width - Theme.spacing.xs * 2

                    StyledText {
                        width: parent.width
                        height: 40
                        leftPadding: Theme.spacing.md
                        text: root.emptyText
                        color: Theme.color.textMuted
                        font.pixelSize: Theme.font.caption
                        visible: zoneColumn.zoneIds.length === 0
                    }

                    Repeater {
                        model: zoneColumn.zoneIds

                        WidgetRow {
                            required property string modelData
                            required property int index

                            widget: root.find(modelData)
                            width: zoneList.width

                            IconButton {
                                icon: "go-up-symbolic"
                                iconSize: 14
                                enabled: index > 0
                                Accessible.name: "Выше"
                                onClicked: root.move(zoneColumn.modelData.key, index, -1)
                            }
                            IconButton {
                                icon: "go-down-symbolic"
                                iconSize: 14
                                enabled: index < zoneColumn.zoneIds.length - 1
                                Accessible.name: "Ниже"
                                onClicked: root.move(zoneColumn.modelData.key, index, 1)
                            }
                            IconButton {
                                icon: "go-previous-symbolic"
                                iconSize: 14
                                enabled: zoneColumn.index > 0
                                Accessible.name: "Левее"
                                onClicked: root.moveZone(zoneColumn.modelData.key, index, -1)
                            }
                            IconButton {
                                icon: "go-next-symbolic"
                                iconSize: 14
                                enabled: zoneColumn.index < root.zones.length - 1
                                Accessible.name: "Правее"
                                onClicked: root.moveZone(zoneColumn.modelData.key, index, 1)
                            }
                            IconButton {
                                icon: "view-conceal-symbolic"
                                iconSize: 14
                                Accessible.name: "Скрыть"
                                onClicked: root.hide(zoneColumn.modelData.key, index)
                            }
                        }
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacing.sm
        visible: root.hidden.length > 0

        SectionLabel {
            text: "Скрыто"
        }

        Rectangle {
            width: parent.width
            implicitHeight: hiddenList.implicitHeight + Theme.spacing.xs * 2
            radius: Theme.radius.control
            color: Theme.color.surface

            Column {
                id: hiddenList

                x: Theme.spacing.xs
                y: Theme.spacing.xs
                width: parent.width - Theme.spacing.xs * 2

                Repeater {
                    model: root.hidden

                    WidgetRow {
                        id: hiddenRow

                        required property var modelData

                        widget: modelData
                        width: hiddenList.width
                        dimmed: true

                        Repeater {
                            model: root.zones

                            TextButton {
                                required property var modelData

                                text: modelData.name
                                onClicked: root.show(hiddenRow.modelData.id, modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }

    TextButton {
        text: "Вернуть расположение по умолчанию"
        onClicked: root.reset()
    }

    // Строка элемента: иконка, название, подсказка; кнопки действий справа.
    component WidgetRow: Item {
        id: row

        property var widget
        property bool dimmed: false
        default property alias actions: actionRow.data

        implicitHeight: 48

        SymbolIcon {
            id: widgetIcon

            anchors.left: parent.left
            anchors.leftMargin: Theme.spacing.md
            anchors.verticalCenter: parent.verticalCenter
            name: row.widget?.icon ?? ""
            color: row.dimmed ? Theme.color.textMuted : Theme.color.text
        }

        Column {
            anchors.left: widgetIcon.right
            anchors.right: actionRow.left
            anchors.leftMargin: Theme.spacing.md
            anchors.rightMargin: Theme.spacing.sm
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: row.widget?.name ?? ""
                color: row.dimmed ? Theme.color.textMuted : Theme.color.text
            }

            StyledText {
                width: parent.width
                text: row.widget?.hint ?? ""
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
            }
        }

        Row {
            id: actionRow

            anchors.right: parent.right
            anchors.rightMargin: Theme.spacing.xs
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xxs
        }
    }
}
