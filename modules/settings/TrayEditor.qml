import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.widgets

// Значки трея для окна настроек: где показывать каждый — прямо на панели, во
// всплывающем окне трея (кнопка-стрелка на панели) или нигде. Значки запущенных
// приложений и те, что уже упомянуты в настройках (tray.pinned, tray.hidden),
// даже если приложение сейчас закрыто.
Column {
    id: root

    width: parent?.width ?? 0
    spacing: Theme.spacing.xs

    readonly property var running: SystemTray.items.values
    readonly property var rows: {
        const out = running.map(item => ({ id: item.id, item: item }));
        for (const id of Array.from(Settings.tray.pinned).concat(Array.from(Settings.tray.hidden))) {
            if (!out.some(r => r.id === id))
                out.push({ id: id, item: null });
        }
        return out;
    }

    function placeOf(id) {
        return Settings.tray.hidden.includes(id) ? "hidden"
            : Settings.tray.pinned.includes(id) ? "bar" : "tray";
    }

    function place(id, where) {
        const pinned = Array.from(Settings.tray.pinned).filter(x => x !== id);
        const hidden = Array.from(Settings.tray.hidden).filter(x => x !== id);
        if (where === "bar")
            pinned.push(id);
        else if (where === "hidden")
            hidden.push(id);
        Settings.tray.pinned = pinned;
        Settings.tray.hidden = hidden;
    }

    StyledText {
        width: parent.width
        text: "На панели — значок виден всегда; в трее — по кнопке-стрелке рядом с ними."
        color: Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        wrapMode: Text.Wrap
    }

    StyledText {
        width: parent.width
        topPadding: Theme.spacing.sm
        text: "Сейчас значков в трее нет"
        color: Theme.color.textMuted
        visible: root.rows.length === 0
    }

    Repeater {
        model: root.rows

        Item {
            id: row

            required property var modelData

            readonly property string where: root.placeOf(modelData.id)

            width: root.width
            implicitHeight: 48

            IconImage {
                id: icon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 20
                source: row.modelData.item?.icon ?? ""
                opacity: row.where === "hidden" ? 0.45 : 1
            }

            Column {
                anchors.left: icon.right
                anchors.right: choices.left
                anchors.leftMargin: Theme.spacing.md
                anchors.rightMargin: Theme.spacing.md
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: row.modelData.item?.tooltipTitle || row.modelData.item?.title || row.modelData.id
                    color: row.where === "hidden" ? Theme.color.textMuted : Theme.color.text
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: row.modelData.item ? row.modelData.id : row.modelData.id + " · не запущено"
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                    elide: Text.ElideRight
                }
            }

            Row {
                id: choices

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing.xs

                Repeater {
                    model: [["bar", "На панели"], ["tray", "В трее"], ["hidden", "Скрыт"]]

                    Chip {
                        required property var modelData

                        text: modelData[1]
                        checked: row.where === modelData[0]
                        onClicked: root.place(row.modelData.id, modelData[0])
                    }
                }
            }
        }
    }
}
