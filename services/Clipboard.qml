pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// История буфера обмена на cliphist + wl-clipboard. Оболочка сама держит
// два наблюдателя `wl-paste --watch cliphist store` (текст и картинки) и
// перезапускает их, если они завершились. Записи, помеченные менеджерами
// паролей как секретные, cliphist не сохраняет.
//
// Запись: { id, preview, image, line } — line нужна cliphist для удаления.
Singleton {
    id: root

    readonly property bool enabled: Settings.clipboard.enabled
    readonly property bool available: tools.found
    readonly property int maxItems: Math.max(20, Settings.clipboard.maxItems)

    property var entries: []
    property bool loading: false

    // Миниатюры картинок: id → путь к файлу в каталоге выполнения.
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/konshell/clipboard"

    function reload() {
        if (!available)
            return;
        loading = true;
        lister.running = true;
    }

    function search(query) {
        const q = query.trim().toLowerCase();
        if (q === "")
            return entries;
        return entries.filter(e => !e.image && e.preview.toLowerCase().includes(q));
    }

    // Вернуть запись в буфер обмена: она станет самой новой.
    function copy(entry) {
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id]);
    }

    function remove(entry) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", entry.line]);
        entries = entries.filter(e => e.id !== entry.id);
    }

    function wipe() {
        Quickshell.execDetached(["sh", "-c", 'cliphist wipe; rm -rf -- "$1"', "sh", cacheDir]);
        entries = [];
    }

    // Команда, которая сохраняет картинку записи в файл (если ещё нет) и печатает путь.
    function imageCommand(entry) {
        return ["sh", "-c", 'mkdir -p -- "$1" && f="$1/$2.png" && { [ -s "$f" ] || cliphist decode "$2" > "$f"; } && printf "%s" "$f"',
            "sh", cacheDir, entry.id];
    }

    // Есть ли cliphist и wl-paste.
    Process {
        id: tools

        property bool found: false

        running: true
        command: ["sh", "-c", "command -v cliphist >/dev/null && command -v wl-paste >/dev/null && command -v wl-copy >/dev/null"]
        onExited: code => found = code === 0
    }

    // Наблюдатели: текст и картинки.
    Instantiator {
        model: root.enabled && root.available ? ["text", "image"] : []

        Process {
            id: watcher

            required property string modelData

            // setpriv --pdeathsig: если оболочка умрёт, ядро уберёт и наблюдателя — без сирот.
            command: ["setpriv", "--pdeathsig", "KILL"]
                .concat(modelData === "image" ? ["wl-paste", "--type", "image", "--watch"] : ["wl-paste", "--watch"])
                .concat(["cliphist", "-max-items", String(root.maxItems), "store"])
            running: true
            // Упал (например, перезапустился композитор) — поднять через несколько секунд.
            onExited: restart.start()

            property Timer restart: Timer {
                interval: 3000
                onTriggered: watcher.running = true
            }
        }
    }

    Process {
        id: lister

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    const preview = line.slice(tab + 1);
                    list.push({
                        id: line.slice(0, tab),
                        preview: preview,
                        image: /^\[\[ binary data .*\]\]$/.test(preview),
                        line: line
                    });
                }
                root.entries = list;
                root.loading = false;
            }
        }
        // Пустая база — cliphist завершается с ошибкой «please store something first».
        onExited: code => {
            if (code !== 0) {
                root.entries = [];
                root.loading = false;
            }
        }
    }
}
