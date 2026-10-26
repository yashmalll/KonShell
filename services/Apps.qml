pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Приложения из .desktop-файлов и нечёткий поиск по ним.
Singleton {
    id: root

    // Сколько раз запускали приложение (id → число), из launcher-usage.json.
    property var usage: ({})
    readonly property bool byUsage: Settings.launcher.sortByUsage

    readonly property var all: DesktopEntries.applications.values
        .filter(app => !app.noDisplay)
        .sort((a, b) => (byUsage ? (usage[b.id] ?? 0) - (usage[a.id] ?? 0) : 0) || a.name.localeCompare(b.name))

    function recordLaunch(app) {
        if (!byUsage)
            return;
        usage = Object.assign({}, usage, { [app.id]: (usage[app.id] ?? 0) + 1 });
        usageFile.setText(JSON.stringify(usage));
    }

    // Без запроса — по частоте запуска (если включено), затем по алфавиту;
    // с запросом — по оценке совпадения, частые приложения получают небольшой бонус.
    function search(query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return all;

        const scored = [];
        for (const app of all) {
            const score = Math.max(
                fuzzyScore(q, app.name),
                fuzzyScore(q, app.genericName) * 0.7,
                ...app.keywords.map(k => fuzzyScore(q, k) * 0.6),
                fuzzyScore(q, app.id) * 0.5
            );
            if (score > 0)
                scored.push({ app, score: score + (byUsage ? Math.min(10, Math.log2(1 + (usage[app.id] ?? 0)) * 3) : 0) });
        }
        return scored.sort((a, b) => b.score - a.score).map(s => s.app);
    }

    // Символы запроса должны встречаться в тексте по порядку.
    // Бонусы за подряд идущие совпадения, начала слов и совпадение префикса.
    // 0, если совпадения нет.
    function fuzzyScore(query, text) {
        if (!text)
            return 0;
        const t = text.toLowerCase();
        let qi = 0;
        let prev = -2;
        let score = 0;
        for (let i = 0; i < t.length && qi < query.length; i++) {
            if (t[i] !== query[qi])
                continue;
            score += 1;
            if (i === prev + 1)
                score += 5;
            if (i === 0 || " -_./".includes(t[i - 1]))
                score += 8;
            prev = i;
            qi++;
        }
        if (qi < query.length)
            return 0;
        if (t.startsWith(query))
            score += 20;
        return Math.max(score - t.length * 0.1, 0.01);
    }

    FileView {
        id: usageFile

        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/konshell/launcher-usage.json"
        printErrors: false
        blockLoading: true
        atomicWrites: true
        onLoaded: {
            try {
                root.usage = JSON.parse(text() || "{}");
            } catch (e) {
                root.usage = {};
            }
        }
    }
}
