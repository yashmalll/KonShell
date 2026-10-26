pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Курсор: одна тема и один размер для niri, оболочки и приложений.
// Без этого niri, GTK (gsettings) и XWayland берут курсор каждый из своего места,
// и при переходе между окнами он меняет размер или вид — особенно если в конфиге
// niri указана неустановленная тема.
//
// При cursor.manage оболочка пишет:
//   ~/.config/niri/konshell-cursor.kdl — блок cursor (подключён в конце config.kdl,
//     переопределяет заданный выше); niri передаёт XCURSOR_THEME и XCURSOR_SIZE
//     запускаемым приложениям и рисует курсор над окнами и оболочкой;
//   gsettings org.gnome.desktop.interface cursor-theme и cursor-size — для GTK;
//   ~/.local/share/icons/default/index.theme — тема по умолчанию для XWayland.
// Уже запущенные приложения подхватят курсор после перезапуска.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || home + "/.config"
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"

    // Установленные темы курсора: каталоги с подкаталогом cursors.
    property var themes: []

    readonly property bool manage: Settings.cursor.manage
    // Выбранная тема, если установлена; иначе Adwaita (она есть всегда вместе с GTK).
    readonly property string theme: themes.length === 0 || themes.includes(Settings.cursor.theme)
        ? Settings.cursor.theme : (themes.includes("Adwaita") ? "Adwaita" : themes[0])
    readonly property int size: Math.max(16, Math.min(64, Settings.cursor.size))

    readonly property string niriText: manage
        ? `// Курсор KonShell. Файл создаётся оболочкой — не редактируйте; тема и размер —\n`
          + `// «Настройки KonShell» → «Интерфейс» → «Курсор».\n\n`
          + `cursor {\n    xcursor-theme "${theme}"\n    xcursor-size ${size}\n}\n`
        : `// Курсором KonShell не управляет («Настройки KonShell» → «Интерфейс» → «Курсор»).\n`

    readonly property string signature: JSON.stringify([manage, theme, size, themes.length > 0])
    onSignatureChanged: debounce.restart()

    function rescan() {
        scan.running = true;
    }

    Component.onCompleted: rescan()

    Process {
        id: scan

        command: ["sh", "-c", 'for d in "$1"/icons "$2"/.icons /usr/share/icons /usr/local/share/icons; do '
            + 'for t in "$d"/*/cursors; do [ -d "$t" ] && basename "$(dirname "$t")"; done; done 2>/dev/null | sort -u',
            "sh", root.dataHome, root.home]
        stdout: StdioCollector {
            onStreamFinished: root.themes = text.split("\n").filter(t => t !== "" && t !== "default")
        }
    }

    // Применение — с задержкой: ползунок размера меняет значение много раз подряд.
    Timer {
        id: debounce

        interval: 600
        onTriggered: root.apply()
    }

    function apply() {
        // Пока список тем не прочитан, неясно, установлена ли выбранная.
        if (themes.length === 0)
            return;
        if (niriFile.text() !== niriText) {
            niriFile.setText(niriText);
            Quickshell.execDetached(["sh", "-c", "command -v niri >/dev/null && niri msg action load-config-file >/dev/null 2>&1"]);
        }
        if (!manage)
            return;
        Quickshell.execDetached(["sh", "-c", 'command -v gsettings >/dev/null || exit 0; '
            + 'gsettings set org.gnome.desktop.interface cursor-theme "$1"; '
            + 'gsettings set org.gnome.desktop.interface cursor-size "$2"', "sh", theme, String(size)]);
        // Каталога icons/default может не быть — FileView его не создаёт.
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "[Icon Theme]\\nName=Default\\nComment=Курсор KonShell\\nInherits=%s\\n" "$2" > "$1/index.theme"',
            "sh", dataHome + "/icons/default", theme]);
    }

    FileView {
        id: niriFile

        path: root.configHome + "/niri/konshell-cursor.kdl"
        blockLoading: true
        printErrors: false
        atomicWrites: true
    }
}
