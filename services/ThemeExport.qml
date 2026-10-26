pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../config/color.js" as ColorUtil

// Перекраска приложений под палитру оболочки: GTK, Qt (qt6ct), kitty, niri, Firefox (Pywalfox), Zed.
// Для каждой включённой цели шаблон из templates/ заполняется токенами текущего
// режима и записывается в отдельный файл цветов, который приложение подключает
// у себя (include / @import). Основные конфиги приложений оболочка не трогает:
// строки подключения добавляет scripts/install-theme-hooks.sh.
//
// Файл перезаписывается и приложение перезагружается, только если содержимое изменилось.
Singleton {
    id: root

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string cacheHome: Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"

    // id — для настройки theme.exports; reload — команда перечитать цвета (необязательна).
    readonly property var targets: [
        {
            // GTK 4 понимает и @define-color, и CSS-переменные libadwaita.
            id: "gtk4",
            setting: "gtk",
            template: "gtk4.css",
            outputs: [configHome + "/gtk-4.0/konshell-colors.css"],
            reload: []
        },
        {
            // GTK 3 (adw-gtk3) — только @define-color: блок :root он не разбирает.
            id: "gtk3",
            setting: "gtk",
            template: "gtk3.css",
            outputs: [configHome + "/gtk-3.0/konshell-colors.css"],
            reload: []
        },
        {
            id: "kitty",
            template: "kitty.conf",
            outputs: [configHome + "/kitty/konshell-colors.conf"],
            // SIGUSR1 — kitty перечитывает конфиг во всех окнах.
            reload: ["pkill", "-USR1", "-x", "kitty"]
        },
        {
            id: "niri",
            template: "niri.kdl",
            outputs: [configHome + "/niri/konshell-colors.kdl"],
            reload: ["niri", "msg", "action", "load-config-file"]
        },
        {
            // Firefox через расширение Pywalfox: оно читает colors.json в формате pywal.
            // Цвета берёт по номерам: тёмный шаблон — фон color0, акценты color10 и color13,
            // текст color15; светлый — акценты color3 и color5. На этих местах — акценты
            // оболочки, а не цвета терминала (иначе Firefox был бы зелёно-розовым).
            id: "pywalfox",
            template: "pywalfox.json",
            outputs: [cacheHome + "/wal/colors.json"],
            reload: ["pywalfox", "update"]
        },
        {
            // Qt-приложения через qt6ct: схема цветов KonShell.conf. Подключение
            // (QT_QPA_PLATFORMTHEME=qt6ct, custom_palette в qt6ct.conf) — install-theme-hooks.sh.
            // qt6ct следит за qt6ct.conf: изменённое время файла — сигнал перечитать палитру.
            id: "qt",
            template: "qt6ct.conf",
            outputs: [configHome + "/qt6ct/colors/KonShell.conf"],
            reload: ["touch", configHome + "/qt6ct/qt6ct.conf"]
        },
        {
            // Обе темы (KonShell Dark и Light) в одном файле: Zed сам выбирает по системному режиму.
            id: "zed",
            template: "zed.json",
            outputs: [configHome + "/zed/themes/konshell.json"],
            reload: []
        }
    ]

    // setting — id в настройке theme.exports (gtk включает и GTK 4, и GTK 3).
    readonly property var enabled: targets.filter(t => Settings.theme.exports.includes(t.setting ?? t.id))

    // Все записываемые файлы плоским списком: по одному FileView на файл.
    // (flatMap в JS-движке Qt нет.)
    readonly property var outputs: enabled.reduce((all, t) => all.concat(t.outputs.map(path => ({ target: t.id, path: path }))), [])

    property string lastError: ""
    property var lastWritten: []

    // Повторный экспорт при смене токенов или набора целей; задержка схлопывает
    // серию изменений (палитра и режим часто меняются вместе).
    readonly property string signature: JSON.stringify([Theme.mode, Theme.palette, Theme.tokens, Wallpaper.path, Settings.theme.exports])
    onSignatureChanged: debounce.restart()

    // Тёмный или светлый режим для GTK, порталов, браузеров и сайтов.
    readonly property string colorScheme: Theme.mode === "light" ? "prefer-light" : "prefer-dark"
    onColorSchemeChanged: syncColorScheme()
    Component.onCompleted: {
        syncColorScheme();
        debounce.restart();
    }

    function syncColorScheme() {
        if (Settings.theme.syncColorScheme)
            Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", colorScheme]);
        // У Pywalfox свой режим (тёмный, светлый или «авто» — по времени суток: днём
        // светлый): без этого Firefox оставался светлым при тёмной теме оболочки.
        // Если Firefox не запущен, команда только запомнит режим.
        if (Settings.theme.exports.includes("pywalfox"))
            Quickshell.execDetached(["sh", "-c", 'command -v pywalfox >/dev/null && exec pywalfox "$1" >/dev/null 2>&1', "sh",
                Theme.mode === "light" ? "light" : "dark"]);
    }

    function exportAll() {
        const context = ColorUtil.templateContext(Theme.tokens, Theme.mode,
            Theme.palette ?? { dark: Theme.tokens, light: Theme.tokens }, { wallpaper: Wallpaper.path });
        const reloads = new Set();
        const written = [];
        const errors = [];

        for (const target of enabled) {
            const template = templateReaders.objectAt(targets.indexOf(target))?.text() ?? "";
            if (template === "") {
                errors.push(`нет шаблона templates/${target.template}`);
                continue;
            }
            const rendered = ColorUtil.renderTemplate(template, context);
            if (rendered.missing.length)
                errors.push(`${target.template}: неизвестные подстановки ${rendered.missing.join(", ")}`);

            for (let i = 0; i < outputs.length; i++) {
                if (outputs[i].target !== target.id)
                    continue;
                const writer = writers.objectAt(i);
                if (!writer || writer.text() === rendered.text)
                    continue;
                writer.setText(rendered.text);
                written.push(outputs[i].path);
                if (target.reload.length)
                    reloads.add(JSON.stringify(target.reload));
            }
        }

        lastWritten = written;
        lastError = errors.join("; ");
        if (errors.length)
            console.warn("theme-export:", lastError);
        if (written.length)
            console.info("theme-export: обновлены", written.join(", "));
        // Перезагрузка после записи: даём файлам записаться.
        if (reloads.size)
            Qt.callLater(() => reloads.forEach(cmd => Quickshell.execDetached(JSON.parse(cmd))));
    }

    Timer {
        id: debounce

        interval: 500
        onTriggered: root.exportAll()
    }

    // Шаблоны читаются из репозитория оболочки; правка шаблона тоже запускает экспорт.
    Instantiator {
        id: templateReaders

        model: root.targets

        FileView {
            required property var modelData

            path: Quickshell.shellDir + "/templates/" + modelData.template
            blockLoading: true
            watchChanges: true
            onFileChanged: {
                reload();
                debounce.restart();
            }
        }
    }

    Instantiator {
        id: writers

        model: root.outputs

        FileView {
            required property var modelData

            path: modelData.path
            blockLoading: true
            printErrors: false
            atomicWrites: true
            onSaveFailed: error => console.warn("theme-export: не удалось записать", path, "-", FileViewError.toString(error))
        }
    }
}
