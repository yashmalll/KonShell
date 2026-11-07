pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// События календаря: хранятся в user/state/events.json как список
// { id, date: "yyyy-MM-dd", time: "HH:mm" | "", title }. Календарь в панели под часами
// (modules/dashboard/Calendar.qml) показывает точку у дней с событиями
// и позволяет добавлять и удалять события выбранного дня.
Singleton {
    id: root

    property var events: []
    // Счётчик изменений: на него завязаны привязки, которым нужны отметки дней.
    property int revision: 0

    function key(date) {
        return Qt.formatDate(date, "yyyy-MM-dd");
    }

    // События по дням: считается один раз на изменение, а не по проходу на каждую из 42 ячеек.
    readonly property var byDay: {
        revision;
        const map = {};
        for (const e of events)
            (map[e.date] ??= []).push(e);
        for (const k in map)
            map[k].sort((a, b) => a.time.localeCompare(b.time));
        return map;
    }

    // События дня, по времени (без времени — первыми).
    function forDay(date) {
        return byDay[key(date)] ?? [];
    }

    function hasEvents(date) {
        return key(date) in byDay;
    }

    // time — «HH:mm» или пустая строка. false — название пустое или время неверное.
    function add(date, time, title) {
        title = title.trim();
        time = time.trim();
        if (title === "")
            return false;
        if (time !== "" && !/^([01]?\d|2[0-3]):[0-5]\d$/.test(time))
            return false;
        if (time.length === 4)
            time = "0" + time;
        const list = events.slice();
        list.push({ id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
            date: key(date), time: time, title: title });
        commit(list);
        return true;
    }

    function remove(id) {
        commit(events.filter(e => e.id !== id));
    }

    function commit(list) {
        events = list;
        revision++;
        file.setText(JSON.stringify(list, null, 2) + "\n");
    }

    FileView {
        id: file

        path: Paths.state + "/events.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true

        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (Array.isArray(saved)) {
                    root.events = saved.filter(e => e && typeof e.date === "string"
                        && typeof e.title === "string" && typeof e.id === "string")
                        .map(e => ({ id: e.id, date: e.date, time: typeof e.time === "string" ? e.time : "", title: e.title }));
                    root.revision++;
                }
            } catch (e) {
                // Повреждённый файл — начинаем с пустого списка.
            }
        }
    }
}
