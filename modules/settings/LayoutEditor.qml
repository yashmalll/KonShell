import QtQuick
import qs.config
import qs.widgets

// Раскладка элементов по зонам для окна настроек: какие элементы где и в каком
// порядке; не указанные ни в одной зоне — скрыты. Общая для зон панели
// (BarLayoutEditor) и колонок панели под часами (DashboardLayoutEditor).
// Изменения сразу видны на месте — оно и есть предпросмотр.
//
// Управление — перетаскиванием: карточку элемента можно перенести в другое место
// зоны, в другую зону или в «Скрытые». Крестик на карточке — скрыть, клик по
// скрытому — вернуть в первую зону.
//
//   target   — объект настроек со списками по зонам;
//   zones    — [{ key, name }] — ключи списков в target и подписи (зоны слева направо);
//   catalog  — [{ id, name, icon, hint }] — все элементы;
//   defaults — { ключ зоны: [id…] } — для кнопки сброса.
Item {
    id: root

    required property var target
    required property var zones
    required property var catalog
    required property var defaults
    property string emptyText: "Перетащите сюда"

    width: parent?.width ?? 0
    implicitHeight: layout.implicitHeight

    readonly property var placed: zones.reduce((all, z) => all.concat(Array.from(target[z.key])), [])
    readonly property var hidden: catalog.filter(w => !placed.includes(w.id))

    readonly property Item dragLayer: dragLayerItem

    // Перетаскивание: что несём и куда положим ("" — никуда, "hidden" — в скрытые).
    property string dragId: ""
    property string dropZone: ""
    property int dropIndex: -1

    function find(id) {
        return catalog.find(w => w.id === id) ?? null;
    }

    function ids(zone) {
        return Array.from(target[zone]);
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

    // Положить id в зону на место index (index — среди остальных элементов зоны,
    // без самого id) или в скрытые.
    function placeAt(id, zone, index) {
        const layout = {};
        for (const z of zones)
            layout[z.key] = ids(z.key).filter(x => x !== id);
        if (zone !== "hidden") {
            const list = layout[zone];
            list.splice(Math.max(0, Math.min(index, list.length)), 0, id);
        }
        apply(layout);
    }

    function hide(id) {
        placeAt(id, "hidden", 0);
    }

    function show(id) {
        placeAt(id, zones[0].key, ids(zones[0].key).length);
    }

    function reset() {
        const layout = {};
        for (const zone of zones)
            layout[zone.key] = (defaults[zone.key] ?? []).slice();
        apply(layout);
    }

    function finishDrag() {
        if (dragId !== "" && dropZone !== "")
            placeAt(dragId, dropZone, dropIndex);
        dragId = "";
        dropZone = "";
        dropIndex = -1;
    }

    Column {
        id: layout

        width: parent.width
        spacing: Theme.spacing.md

        StyledText {
            width: parent.width
            text: "Перетаскивайте карточки: внутри зоны — порядок, между зонами — место, в «Скрытые» — убрать."
            color: Theme.color.textMuted
            font.pixelSize: Theme.font.caption
            wrapMode: Text.Wrap
        }

        // Зоны рядом, слева направо — как на самой панели.
        Row {
            id: zoneRow

            width: parent.width
            spacing: Theme.spacing.sm

            Repeater {
                model: root.zones

                Column {
                    id: zone

                    required property var modelData
                    required property int index

                    readonly property string key: modelData.key
                    readonly property var zoneIds: root.target[key]
                    readonly property bool dropHere: root.dropZone === key

                    width: (zoneRow.width - zoneRow.spacing * (root.zones.length - 1)) / root.zones.length
                    spacing: Theme.spacing.xs

                    StyledText {
                        leftPadding: Theme.spacing.xs
                        text: zone.modelData.name
                        color: Theme.color.textMuted
                        font.pixelSize: Theme.font.caption
                        font.weight: Theme.font.medium
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Rectangle {
                        id: zoneBox

                        width: parent.width
                        height: Math.max(96, list.implicitHeight + Theme.spacing.xs * 2)
                        radius: Theme.radius.control
                        color: zone.dropHere ? Theme.alpha(Theme.color.primary, 0.08) : Theme.color.background
                        border.width: 1
                        border.color: zone.dropHere ? Theme.color.primary : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.anim.fast }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            width: parent.width - Theme.spacing.md * 2
                            horizontalAlignment: Text.AlignHCenter
                            text: root.emptyText
                            color: Theme.color.textMuted
                            font.pixelSize: Theme.font.caption
                            wrapMode: Text.Wrap
                            visible: zone.zoneIds.length === 0 || (zone.zoneIds.length === 1 && zone.zoneIds[0] === root.dragId)
                        }

                        Column {
                            id: list

                            x: Theme.spacing.xs
                            y: Theme.spacing.xs
                            width: parent.width - Theme.spacing.xs * 2
                            spacing: Theme.spacing.xxs

                            Repeater {
                                model: zone.zoneIds

                                LayoutCard {
                                    required property string modelData

                                    editor: root
                                    itemId: modelData
                                    width: list.width
                                }
                            }
                        }

                        // Где окажется элемент — линия между карточками.
                        Rectangle {
                            x: Theme.spacing.xs
                            width: parent.width - Theme.spacing.xs * 2
                            height: 2
                            radius: 1
                            color: Theme.color.primary
                            visible: zone.dropHere && root.dropIndex >= 0
                            y: {
                                const cards = Array.from(list.children).filter(c => c.itemId !== undefined && c.itemId !== root.dragId);
                                if (cards.length === 0 || root.dropIndex < 0)
                                    return Theme.spacing.xs;
                                if (root.dropIndex < cards.length)
                                    return list.y + cards[root.dropIndex].y - Theme.spacing.xxs / 2 - 1;
                                const last = cards[cards.length - 1];
                                return list.y + last.y + last.height + Theme.spacing.xxs / 2 - 1;
                            }
                        }

                        DropArea {
                            anchors.fill: parent
                            keys: ["konshell-layout"]

                            function update(y) {
                                const cards = Array.from(list.children).filter(c => c.itemId !== undefined && c.itemId !== root.dragId);
                                let index = 0;
                                for (const card of cards) {
                                    if (y > list.y + card.y + card.height / 2)
                                        index++;
                                }
                                root.dropZone = zone.key;
                                root.dropIndex = index;
                            }

                            onEntered: drag => update(drag.y)
                            onPositionChanged: drag => update(drag.y)
                            onExited: {
                                if (root.dropZone === zone.key)
                                    root.dropZone = "";
                            }
                        }
                    }
                }
            }
        }

        // Скрытые элементы: перетащите в зону или кликните, чтобы вернуть.
        Column {
            width: parent.width
            spacing: Theme.spacing.xs

            StyledText {
                leftPadding: Theme.spacing.xs
                text: "Скрытые"
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
                font.weight: Theme.font.medium
            }

            Rectangle {
                readonly property bool dropHere: root.dropZone === "hidden"

                width: parent.width
                height: Math.max(52, hiddenFlow.implicitHeight + Theme.spacing.sm * 2)
                radius: Theme.radius.control
                color: dropHere ? Theme.alpha(Theme.color.primary, 0.08) : "transparent"
                border.width: 1
                border.color: dropHere ? Theme.color.primary : Theme.color.border

                StyledText {
                    anchors.centerIn: parent
                    text: "Перетащите сюда, чтобы скрыть"
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                    visible: root.hidden.length === 0
                }

                Flow {
                    id: hiddenFlow

                    x: Theme.spacing.sm
                    y: Theme.spacing.sm
                    width: parent.width - Theme.spacing.sm * 2
                    spacing: Theme.spacing.xs

                    Repeater {
                        model: root.hidden

                        LayoutCard {
                            required property var modelData

                            editor: root
                            itemId: modelData.id
                            compact: true
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["konshell-layout"]
                    onEntered: {
                        root.dropZone = "hidden";
                        root.dropIndex = 0;
                    }
                    onExited: {
                        if (root.dropZone === "hidden")
                            root.dropZone = "";
                    }
                }
            }
        }

        TextButton {
            text: "Вернуть расположение по умолчанию"
            onClicked: root.reset()
        }
    }

    // Слой над редактором: карточка, пока её несут, переезжает сюда и рисуется поверх всего.
    Item {
        id: dragLayerItem

        anchors.fill: parent
        z: 10
    }
}
