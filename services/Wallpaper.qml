pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Текущие обои. Путь хранится в settings.json (wallpaper.path); если он пуст,
// берётся первая картинка из папки обоев. Смена пути или замена файла
// по тому же пути перерисовывает обои и перестраивает палитру.
Singleton {
    id: root

    // Папка для текущего режима (wallpaper.lightDirectory / darkDirectory), иначе общая.
    readonly property string modeDirectory: Theme.mode === "light" ? Settings.wallpaper.lightDirectory : Settings.wallpaper.darkDirectory
    readonly property string directory: modeDirectory || Settings.wallpaper.directory
        || Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // Картинки из папки, по алфавиту.
    property var images: []

    // Выбранная картинка; если для режима задана своя папка — только картинка из неё,
    // иначе первая картинка этой папки.
    readonly property string path: {
        const chosen = Settings.wallpaper.path;
        if (chosen && (!modeDirectory || chosen.startsWith(modeDirectory.replace(/\/$/, "") + "/")))
            return chosen;
        return images[0] ?? chosen;
    }

    // Растёт при замене файла по тому же пути: от него зависят перерисовка и палитра.
    property int revision: 0

    // Миниатюры для страницы «Оформление»: делаются один раз в фоне (scripts/make-thumbnails.sh).
    readonly property string thumbnailDir:
        (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/konshell/thumbnails"
    // Растёт, когда готова новая партия миниатюр: сетка перечитывает их.
    property int thumbnailRevision: 0

    // Адрес миниатюры; имя — md5 пути, так же считает скрипт.
    function thumbnail(path) {
        return `file://${thumbnailDir}/${Qt.md5(path)}.jpg?${thumbnailRevision}`;
    }

    function set(path) {
        Settings.wallpaper.path = path;
    }

    // Следующая или предыдущая картинка из папки по кругу.
    function step(offset) {
        if (images.length === 0)
            return;
        const i = images.indexOf(path);
        set(images[(i + offset + images.length) % images.length]);
    }

    property bool rescanPending: false

    // Команда собирается здесь, а не привязкой: иначе при смене папки
    // процесс мог стартовать со старым путём.
    function rescan() {
        if (scanner.running) {
            rescanPending = true;
            return;
        }
        scanner.command = ["find", directory, "-maxdepth", "1", "-type", "f",
            "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png",
            "-o", "-iname", "*.webp", "-o", "-iname", "*.jxl", "-o", "-iname", "*.avif",
            "-o", "-iname", "*.bmp", "-o", "-iname", "*.gif", "-o", "-iname", "*.tif", "-o", "-iname", "*.tiff", ")"];
        scanner.running = true;
    }

    // Только картинки верхнего уровня папки, без вложенных.
    Process {
        id: scanner

        stdout: StdioCollector {
            onStreamFinished: {
                root.images = text.split("\n").filter(line => line !== "").sort();
                root.makeThumbnails();
            }
        }
        onExited: {
            if (root.rescanPending) {
                root.rescanPending = false;
                root.rescan();
            }
        }
    }

    function makeThumbnails() {
        if (images.length === 0)
            return;
        if (thumbnailer.running) {
            thumbnailsPending = true;
            return;
        }
        thumbnailer.command = [Quickshell.shellDir + "/scripts/make-thumbnails.sh", thumbnailDir].concat(images);
        thumbnailer.running = true;
    }

    property bool thumbnailsPending: false

    Process {
        id: thumbnailer

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("wallpaper:", text.trim());
            }
        }
        onExited: {
            root.thumbnailRevision++;
            if (root.thumbnailsPending) {
                root.thumbnailsPending = false;
                root.makeThumbnails();
            }
        }
    }

    // Автосмена обоев (wallpaper.rotate): по порядку или случайно, раз в rotateMinutes.
    Timer {
        running: Settings.wallpaper.rotate && root.images.length > 1
        repeat: true
        interval: Math.max(1, Settings.wallpaper.rotateMinutes) * 60 * 1000
        onTriggered: {
            if (Settings.wallpaper.rotateOrder !== "random") {
                root.step(1);
                return;
            }
            const others = root.images.filter(image => image !== root.path);
            root.set(others[Math.floor(Math.random() * others.length)]);
        }
    }

    // Перескан при изменении содержимого папки.
    FileView {
        path: root.directory
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: root.rescan()
    }

    // Замена картинки по тому же пути. Содержимое не читается (preload: false).
    FileView {
        path: root.path
        watchChanges: true
        preload: false
        printErrors: false
        onFileChanged: root.revision++
    }

    // Старый список сразу сбрасываем, чтобы не показать картинку из прежней папки.
    onDirectoryChanged: {
        images = [];
        rescan();
    }
    Component.onCompleted: rescan()
}
