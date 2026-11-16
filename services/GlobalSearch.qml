pragma Singleton
import QtQuick
import Quickshell
import qs.config
import "../config/settings-schema.js" as Schema
import "../config/search.js" as Search
import "../config/settings-navigation.js" as Navigation

Singleton {
    id: root
    property int noteRevision: 0
    readonly property var actions: [
        { id: "timer", name: "Таймер и Pomodoro", icon: "preferences-system-time-symbolic", keywords: "timer помодоро таймер перерыв отсчёт" },
        { id: "work", name: "Профиль «Работа»", icon: "preferences-system-time-symbolic", keywords: "profile профиль работа тихий" },
        { id: "rest", name: "Профиль «Отдых»", icon: "audio-x-generic-symbolic", keywords: "profile профиль отдых музыка" },
        { id: "custom", name: "Мой профиль", icon: "view-grid-symbolic", keywords: "profile профиль обычный свои" },
        { id: "focus", name: FocusMode.active ? "Выключить фокусировку" : "Включить фокусировку", icon: "preferences-system-time-symbolic", keywords: "focus фокус концентрация не беспокоить" },
        { id: "privacy", name: "Приватность: микрофон, камера и экран", icon: "microphone-sensitivity-high-symbolic", keywords: "privacy доступ запись камера микрофон демонстрация" },
        { id: "dashboard", name: "Открыть виджеты", icon: "view-grid-symbolic", keywords: "календарь погода часы dashboard" },
        { id: "notifications", name: "История уведомлений", icon: "preferences-system-notifications-symbolic", keywords: "notifications история сообщения" },
        { id: "note", name: "Новая заметка", icon: "document-new-symbolic", keywords: "notes markdown запись" },
        { id: "dnd", name: Notifications.dnd ? "Выключить «Не беспокоить»" : "Включить «Не беспокоить»", icon: "notifications-disabled-symbolic", keywords: "dnd уведомления тишина" },
        { id: "settings", name: "Настройки оболочки", icon: "emblem-system-symbolic", keywords: "settings параметры" },
        { id: "control", name: "Центр управления", icon: "preferences-system-symbolic", keywords: "wifi bluetooth сеть звук яркость" },
        { id: "lock", name: "Заблокировать экран", icon: "system-lock-screen-symbolic", keywords: "lock блокировка пароль" }
    ]
    readonly property var notes: {
        const revision = noteRevision;
        const result = [];
        if (!Notes.exists) return result;
        for (let i = 0; i < Notes.recent.count; i++) {
            const base = Notes.recent.get(i, "fileBaseName");
            const path = Notes.recent.get(i, "filePath");
            result.push({ key: "note:" + path, kind: "notes", category: "Заметка",
                name: Notes.displayName(base), description: base, icon: "text-x-generic-symbolic", path });
        }
        return result;
    }
    Connections {
        target: Notes.recent
        function onDataChanged() { root.noteRevision++; }
        function onModelReset() { root.noteRevision++; }
    }

    function search(query, scope) {
        const parsed = Search.parseQuery(query, scope);
        const q = parsed.text;
        const candidates = [];
        if (parsed.scope === "all" || parsed.scope === "apps") {
            for (const app of Apps.all) {
                candidates.push({ key: "app:" + app.id, kind: "apps", category: "Приложение",
                    name: app.name, description: app.comment || app.genericName, icon: app.icon,
                    keywords: [app.genericName, app.id, ...app.keywords].join(" "), app,
                    boost: Settings.launcher.sortByUsage ? Math.min(10, Math.log2(1 + (Apps.usage[app.id] ?? 0)) * 3) : 0 });
            }
        }
        if ((parsed.scope === "all" && q !== "") || parsed.scope === "notes")
            candidates.push(...notes);
        if ((parsed.scope === "all" && q !== "") || parsed.scope === "settings") {
            for (const section of Schema.sections.filter(s => s.id !== "controlCenter")) {
                candidates.push({ key: "section:" + section.id, kind: "settings", category: "Настройки",
                    name: section.name, description: section.desc, keywords: section.desc,
                    icon: section.icon, section: section.id });
            }
            for (const option of Schema.options.filter(o => o.key && Navigation.isRelevant(o, key => {
                const parts = key.split(".");
                return Settings[parts[0]][parts[1]];
            }))) {
                const section = Schema.sections.find(s => s.id === option.section);
                candidates.push({ key: "setting:" + option.key, kind: "settings", category: "Настройки",
                    name: option.title, description: section?.name ?? "", icon: section?.icon ?? "emblem-system-symbolic",
                    keywords: [option.hint || "", option.keywords || "", option.key].join(" "), section: option.section });
            }
        }
        if (parsed.scope === "all" || parsed.scope === "actions") {
            candidates.push(...actions.map(action => Object.assign({ key: "action:" + action.id,
                kind: "actions", category: "Действие", description: "KonShell" }, action)));
        }
        return Search.rank(q, candidates);
    }

    function activate(result) {
        if (result.kind === "apps") { Apps.recordLaunch(result.app); result.app.execute(); return; }
        if (result.kind === "notes") { Ui.openNote(result.path); return; }
        if (result.kind === "settings") {
            Ui.openSettings(result.section, result.key.startsWith("setting:") ? result.name : "");
            return;
        }
        switch (result.id) {
        case "timer": Ui.openTimer(); break;
        case "work": Profiles.select("work"); break;
        case "rest": Profiles.select("rest"); break;
        case "custom": Profiles.select("custom"); break;
        case "focus": FocusMode.toggle(); break;
        case "privacy": Ui.openPrivacy(); break;
        case "dashboard": Ui.openDashboard(false); break;
        case "notifications": Notifications.centerOpen = true; break;
        case "note": Ui.openNote(""); break;
        case "dnd": Notifications.setDnd(!Notifications.dnd); break;
        case "settings": Ui.openSettings("appearance"); break;
        case "control": Ui.controlCenterOpen = true; break;
        case "lock": Lock.lock("manual"); break;
        }
    }
}
