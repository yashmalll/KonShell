import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// IPC для обоев и темы:
//   qs -c konshell ipc call wallpaper set ~/Pictures/Wallpapers/a.jpg
//   qs -c konshell ipc call wallpaper next | prev | get | rescan
//   qs -c konshell ipc call theme status
//   qs -c konshell ipc call theme toggleMode | setMode light | setScheme vibrant | regenerate
Scope {
    // Ссылка на сервис создаёт его при запуске оболочки: синглтоны в QML ленивые.
    readonly property string themeStatus: ColorScheme.status
    readonly property string exportStatus: ThemeExport.lastError

    // Диагностика оболочки:
    //   qs -c konshell ipc call shell memory   # RSS и доля памяти (PSS), МБ
    //   qs -c konshell ipc call shell collectGarbage   # собрать мусор JavaScript
    IpcHandler {
        target: "shell"

        function memory(): string {
            memoryFile.reload();
            const field = name => Math.round(Number((memoryFile.text().match(new RegExp("^" + name + ":\\s+(\\d+)", "m")) ?? [0, 0])[1]) / 1024);
            return JSON.stringify({ rssMiB: field("Rss"), pssMiB: field("Pss"), anonMiB: field("Pss_Anon") });
        }
        function collectGarbage(): void {
            globalThis.gc();
        }
    }

    FileView {
        id: memoryFile

        path: "/proc/self/smaps_rollup"
        blockLoading: true
        printErrors: false
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            Wallpaper.set(path);
        }
        function next(): void {
            Wallpaper.step(1);
        }
        function prev(): void {
            Wallpaper.step(-1);
        }
        function get(): string {
            return Wallpaper.path;
        }
        function rescan(): void {
            Wallpaper.rescan();
        }
    }

    IpcHandler {
        target: "theme"

        function setMode(mode: string): void {
            Settings.theme.mode = mode === "light" ? "light" : "dark";
        }
        function toggleMode(): void {
            Settings.theme.mode = Theme.mode === "light" ? "dark" : "light";
        }
        function setScheme(scheme: string): void {
            Settings.theme.scheme = scheme;
        }
        function regenerate(): void {
            ColorScheme.regenerate();
        }
        // Для диагностики: состояние генерации, источник и последняя ошибка.
        function status(): string {
            return JSON.stringify({
                status: ColorScheme.status,
                error: ColorScheme.lastError,
                mode: Theme.mode,
                scheme: Settings.theme.scheme,
                source: Theme.palette?.source ?? null,
                usingFallback: Theme.palette === null,
                contrastFixes: ColorScheme.adjusted,
                exports: Settings.theme.exports,
                exportError: ThemeExport.lastError,
                lastWritten: ThemeExport.lastWritten
            }, null, 2);
        }
    }
}
