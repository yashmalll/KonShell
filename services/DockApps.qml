pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Значки дока: закреплённые приложения (dock.pinned), затем запущенные
// незакреплённые. Окно niri сопоставляется с .desktop-файлом по app_id.
//
// Значок: { key, entry, name, icon, pinned, windows }
//   key      — id .desktop-файла, а если его нет — app_id окна;
//   windows  — окна приложения, последнее в фокусе — первым.
Singleton {
    id: root

    // Приложения, запущенные из дока, пока у них не появилось окно: key → время запуска.
    property var launching: ({})

    readonly property var pinnedKeys: Settings.dock.pinned

    // Пересчитывается, когда меняются окна, закреплённые или список .desktop-файлов.
    readonly property var items: {
        DesktopEntries.applications.values; // зависимость: каталог .desktop мог обновиться
        const byKey = {};
        const order = [];

        function add(key, entry, pinned) {
            if (byKey[key])
                return byKey[key];
            const item = {
                key: key,
                entry: entry,
                name: entry?.name || key,
                icon: entry?.icon || key,
                pinned: pinned,
                windows: []
            };
            byKey[key] = item;
            order.push(item);
            return item;
        }

        for (const key of pinnedKeys)
            add(key, DesktopEntries.byId(key), true);

        for (const w of Niri.windows) {
            const entry = entryFor(w.app_id);
            const key = entry?.id ?? w.app_id ?? "";
            if (key === "")
                continue;
            const item = byKey[key] ?? (Settings.dock.showRunning ? add(key, entry, false) : null);
            if (item)
                item.windows.push(w);
        }

        for (const item of order)
            item.windows.sort((a, b) => Niri.focusTime(b) - Niri.focusTime(a));
        return order;
    }

    function entryFor(appId) {
        if (!appId)
            return null;
        return DesktopEntries.byId(appId) ?? DesktopEntries.heuristicLookup(appId);
    }

    function isFocused(item) {
        return item.windows.some(w => w.is_focused);
    }

    function isUrgent(item) {
        return item.windows.some(w => w.is_urgent);
    }

    // Клик: не запущено — запустить; в фокусе — следующее окно приложения;
    // иначе — окно, которое было в фокусе последним.
    function activate(item) {
        if (item.windows.length === 0) {
            launch(item);
            return;
        }
        const focusedIndex = item.windows.findIndex(w => w.is_focused);
        if (focusedIndex < 0) {
            Niri.focusWindow(item.windows[0].id);
            return;
        }
        // Окна по id — стабильный порядок для перебора, не зависящий от фокуса.
        const cycle = item.windows.slice().sort((a, b) => a.id - b.id);
        const current = cycle.findIndex(w => w.is_focused);
        Niri.focusWindow(cycle[(current + 1) % cycle.length].id);
    }

    function launch(item) {
        if (!item.entry) {
            console.warn("dock: нет .desktop-файла для", item.key);
            return;
        }
        Apps.recordLaunch(item.entry);
        item.entry.execute();
        launching = Object.assign({}, launching, { [item.key]: Date.now() });
        launchTimeout.restart();
    }

    function isLaunching(item) {
        return launching[item.key] !== undefined && item.windows.length === 0;
    }

    function closeAll(item) {
        for (const w of item.windows)
            Niri.closeWindow(w.id);
    }

    function pin(key) {
        if (!pinnedKeys.includes(key))
            Settings.dock.pinned = pinnedKeys.concat([key]);
    }

    function unpin(key) {
        Settings.dock.pinned = pinnedKeys.filter(k => k !== key);
    }

    // Сдвинуть закреплённый значок на step позиций (−1 — левее, 1 — правее).
    function move(key, step) {
        const list = pinnedKeys.slice();
        const from = list.indexOf(key);
        const to = from + step;
        if (from < 0 || to < 0 || to >= list.length)
            return;
        list.splice(to, 0, list.splice(from, 1)[0]);
        Settings.dock.pinned = list;
    }

    // Появилось окно — запуск закончен; не появилось за 10 с — тоже перестаём ждать.
    onItemsChanged: {
        const keys = Object.keys(launching);
        if (keys.length === 0)
            return;
        const still = {};
        for (const key of keys) {
            const item = items.find(i => i.key === key);
            if (item && item.windows.length === 0 && Date.now() - launching[key] < 10000)
                still[key] = launching[key];
        }
        if (keys.length !== Object.keys(still).length)
            launching = still;
    }

    Timer {
        id: launchTimeout

        interval: 10000
        onTriggered: root.launching = ({})
    }
}
