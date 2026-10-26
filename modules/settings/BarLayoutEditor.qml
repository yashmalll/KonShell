import QtQuick
import qs.config
import qs.modules.bar

// Расположение виджетов панели по зонам (слева, по центру, справа).
// Изменения сразу видны на самой панели — она и есть предпросмотр. Управление — перетаскиванием.
LayoutEditor {
    target: Settings.bar
    zones: [
        { key: "left", name: "Слева" },
        { key: "center", name: "По центру" },
        { key: "right", name: "Справа" }
    ]
    catalog: BarWidgets.all
    defaults: ({
        left: ["workspaces", "windowTitle"],
        center: ["clock"],
        right: ["tray", "keyboard", "status", "notifications"]
    })
    emptyText: "Пусто — перетащите виджет сюда"
}
