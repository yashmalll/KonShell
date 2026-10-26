pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../config/color.js" as ColorUtil

// Генерация палитры: единственное место, где запускается matugen.
// Следит за обоями и настройками темы, строит токены для тёмного и светлого
// режима и пишет их в palette.json, который читает Theme. Режим (тёмный/светлый)
// переключается без генерации: в файле лежат оба.
//
// При ошибке palette.json не трогается: остаётся последняя рабочая палитра,
// а при первом запуске — резервная из config/fallback-palette.js.
Singleton {
    id: root

    readonly property bool fromWallpaper: Settings.theme.source !== "color"
    readonly property string input: fromWallpaper ? Wallpaper.path : Settings.theme.seedColor

    // Всё, от чего зависит палитра. Любое изменение запускает генерацию (с задержкой).
    readonly property string request: JSON.stringify([fromWallpaper, input, Wallpaper.revision,
        Settings.theme.scheme, Settings.theme.contrast, Settings.theme.sourceColorIndex, Settings.theme.accent])

    // idle | running | ok | error
    property string status: "idle"
    property string lastError: ""
    property string lastSource: ""
    property var adjusted: []

    // Ключ из palette.json: если он совпадает, скрипт ответит "unchanged" без matugen.
    // Ключ скрипта не знает про настройку акцента и версию сборки токенов,
    // поэтому при их расхождении кэш не используется.
    readonly property string cachedKey: Theme.palette?.source?.tokensVersion === ColorUtil.TOKENS_VERSION
        && Theme.palette?.source?.accent === Settings.theme.accent
        ? (Theme.palette?.source?.key ?? "") : ""

    property int failures: 0
    property bool force: false
    property bool pending: false

    function regenerate() {
        force = true;
        generate();
    }

    function generate() {
        if (proc.running) {
            pending = true;
            return;
        }
        if (input === "") {
            status = "idle";
            lastError = fromWallpaper ? `Нет обоев: задайте wallpaper.path или положите картинку в ${Wallpaper.directory}` : "Не задан theme.seedColor";
            return;
        }
        status = "running";
        proc.command = [Quickshell.shellDir + "/scripts/generate-palette.sh",
            fromWallpaper ? "image" : "color", input,
            Settings.theme.scheme, String(Settings.theme.contrast), String(Settings.theme.sourceColorIndex),
            force ? "" : cachedKey];
        force = false;
        proc.running = true;
    }

    function fail(message, retryable) {
        status = "error";
        lastError = message;
        console.warn("color-scheme:", message, "- оставляю текущую палитру");
        if (retryable) {
            failures++;
            retryTimer.restart();
        }
    }

    function handleOutput(code, out, err) {
        if (code !== 0) {
            const message = err.trim() || `generate-palette.sh завершился с кодом ${code}`;
            // 2 — нет файла, 4 — matugen не разобрал картинку: повтор не поможет.
            // 3 — нет matugen и прочие сбои: возможно, временные, пробуем снова.
            fail(message, code !== 2 && code !== 4);
            return;
        }
        if (out.startsWith("unchanged")) {
            status = "ok";
            failures = 0;
            return;
        }

        // Строки: "key …", "achromatic 0|1", дальше JSON matugen.
        const first = out.indexOf("\n");
        const second = out.indexOf("\n", first + 1);
        const key = out.slice(0, first).replace(/^key /, "");
        const achromatic = out.slice(first + 1, second).trim() === "achromatic 1";
        let roles;
        try {
            roles = ColorUtil.rolesFromMatugen(JSON.parse(out.slice(second + 1)));
        } catch (e) {
            fail(`Не удалось разобрать вывод matugen: ${e.message}`, true);
            return;
        }

        const result = { version: 1, source: {
            key: key,
            kind: fromWallpaper ? "wallpaper" : "color",
            input: input,
            scheme: Settings.theme.scheme,
            contrast: Settings.theme.contrast,
            sourceColor: roles.dark.source_color ?? "",
            // Обои без цвета: палитра серая с их оттенком (см. generate-palette.sh).
            achromatic: achromatic,
            accent: Settings.theme.accent,
            tokensVersion: ColorUtil.TOKENS_VERSION,
            generatedAt: new Date().toISOString()
        } };
        const notes = [];
        for (const mode of ["dark", "light"]) {
            const built = ColorUtil.buildTokens(roles[mode], mode, {
                accent: Settings.theme.accent,
                achromatic: achromatic
            });
            result[mode] = built.tokens;
            for (const line of built.adjusted)
                notes.push(`${mode}: ${line}`);
            const failed = ColorUtil.audit(built.tokens);
            if (failed.length)
                console.warn("color-scheme: контраст не дотягивает в режиме", mode, "-", failed.join("; "));
        }

        adjusted = notes;
        lastSource = result.source.sourceColor;
        // Запись атомарная: Theme никогда не увидит наполовину записанный файл.
        writer.setText(JSON.stringify(result, null, 2));
        status = "ok";
        lastError = "";
        failures = 0;
        console.info("color-scheme: палитра обновлена из", input, "основной цвет", lastSource,
            notes.length ? `исправлений контраста: ${notes.length}` : "");
    }

    onRequestChanged: debounce.restart()
    Component.onCompleted: debounce.restart()

    // Задержка, чтобы серия изменений (например, путь и схема сразу) дала один запуск.
    Timer {
        id: debounce

        interval: 300
        onTriggered: root.generate()
    }

    // Повтор при временных сбоях: 2, 4, 8 … до 60 секунд.
    Timer {
        id: retryTimer

        interval: Math.min(60000, 2000 * Math.pow(2, Math.max(0, root.failures - 1)))
        onTriggered: root.generate()
    }

    Process {
        id: proc

        stdout: StdioCollector {
            id: stdoutCollector
        }
        stderr: StdioCollector {
            id: stderrCollector
        }

        onExited: code => {
            root.handleOutput(code, stdoutCollector.text, stderrCollector.text);
            if (root.pending) {
                root.pending = false;
                root.generate();
            }
        }
    }

    FileView {
        id: writer

        path: Theme.palettePath
        preload: false
        atomicWrites: true
        onSaved: Theme.reloadPalette()
        onSaveFailed: error => root.fail(`Не удалось записать ${path}: ${FileViewError.toString(error)}`, true)
    }
}
