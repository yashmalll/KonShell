pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Где KonShell хранит свои файлы — всё в одной папке, рядом с самой оболочкой:
//
//   <папка оболочки>/user/
//     settings.json   настройки
//     state/          палитра, PIN, частота запусков в лаунчере
//     cache/          миниатюры обоев, погода
//     colors/         цвета для приложений: kitty, GTK, niri, Qt, Zed, Firefox
//     niri.kdl        автозапуск и клавиши для niri (пишет install.sh)
//     cursor.kdl      курсор для niri
//
// Программы подключают эти файлы по абсолютному пути (install.sh). Папку можно
// перенести переменной окружения KONSHELL_HOME. В git она не попадает (.gitignore).
Singleton {
    id: paths

    readonly property string home: Quickshell.env("HOME")
    readonly property string root: trim(Quickshell.env("KONSHELL_HOME") || Quickshell.shellDir + "/user")

    readonly property string settings: root + "/settings.json"
    readonly property string state: root + "/state"
    readonly property string cache: root + "/cache"
    readonly property string colors: root + "/colors"

    function trim(path) {
        return path.endsWith("/") ? path.slice(0, -1) : path;
    }

    // Папки создаются при запуске: в них сразу пишут настройки, палитра и кэш.
    Process {
        running: true
        command: ["mkdir", "-p", "--", paths.state, paths.cache, paths.colors]
    }
}
