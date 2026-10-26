pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config

// Быстрые заметки в Markdown: каждая — отдельный .md-файл в папке notes.directory
// (по умолчанию «Документы/Notes», например ~/Документы/Notes). Оболочка их создаёт, показывает, правит
// (окно заметки modules/sidebar/NoteWindow.qml) и удаляет в корзину; открыть во
// внешнем редакторе — notes.openCommand или xdg-open.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    // Папка «Документы» пользователя — из ~/.config/user-dirs.dirs (XDG_DOCUMENTS_DIR):
    // у русской системы это ~/Документы, а не ~/Documents.
    readonly property string documents: {
        const match = userDirs.text().match(/^XDG_DOCUMENTS_DIR="(.*)"\s*$/m);
        const dir = match ? match[1].replace(/^\$HOME/, home) : "";
        return dir !== "" && dir !== home ? dir : home + "/Documents";
    }
    // Одна папка для всех заметок: боковой панели, панели под часами и окна заметки.
    readonly property string directory: {
        const dir = Settings.notes.directory.trim();
        if (dir === "")
            return documents + "/Notes";
        return dir.startsWith("~/") ? home + dir.slice(1) : dir;
    }

    FileView {
        id: userDirs

        path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/user-dirs.dirs"
        blockLoading: true
        printErrors: false
    }

    // Последние заметки, новые первыми: fileName, fileBaseName, filePath, fileModified.
    // Только если папка есть: для несуществующей FolderListModel показывает
    // текущую папку процесса (у оболочки — папку проекта).
    readonly property alias recent: folder
    property bool exists: false

    // callLater: при создании синглтона directory меняется раньше, чем появляется dirCheck.
    onDirectoryChanged: Qt.callLater(checkDirectory)
    Component.onCompleted: Qt.callLater(checkDirectory)

    function checkDirectory() {
        dirCheck.running = true;
    }

    property bool saving: false
    property string lastError: ""

    signal saved(string path)

    // Черновик новой заметки: окно заметки закрыли, не сохранив, — текст не пропадает.
    property string draftTitle: ""
    property string draftBody: ""

    // Имя для списка: без даты в начале («2026-10-18 Идея» → «Идея»).
    function displayName(baseName) {
        return baseName.replace(/^\d{4}-\d{2}-\d{2}\s+/, "") || baseName;
    }

    // Перезаписать существующую заметку.
    function write(path, text) {
        lastError = "";
        saving = true;
        writer.command = ["sh", "-c", 'printf "%s" "$2" > "$1" && printf "%s" "$1"', "sh", path, text];
        writer.running = true;
    }

    // В корзину (gio trash), а если её нет — удалить.
    function remove(path) {
        Quickshell.execDetached(["sh", "-c", 'gio trash -- "$1" 2>/dev/null || rm -f -- "$1"', "sh", path]);
    }

    // Имя файла из заголовка: без символов, запрещённых в именах, не длиннее 60 знаков.
    function fileTitle(text) {
        return text.replace(/^#+\s*/, "").replace(/[\/\\\x00-\x1f:*?"<>|]/g, " ")
            .replace(/\s+/g, " ").trim().slice(0, 60).trim();
    }

    // Заголовок — отдельной строкой «# …»; без него имя берётся из первой строки текста.
    function create(title, body) {
        title = title.trim();
        body = body.replace(/\s+$/, "");
        if (title === "" && body === "")
            return false;

        const name = fileTitle(title !== "" ? title : body.split("\n")[0]) || "Заметка";
        const base = Settings.notes.datePrefix ? `${Qt.formatDate(new Date(), "yyyy-MM-dd")} ${name}` : name;
        const content = (title !== "" ? `# ${title}\n\n${body}` : body) + "\n";

        lastError = "";
        saving = true;
        writer.command = ["sh", "-c",
            'dir=$1; base=$2; p="$dir/$base.md"; i=2; mkdir -p -- "$dir" || exit 1; '
            + 'while [ -e "$p" ]; do p="$dir/$base ($i).md"; i=$((i+1)); done; '
            + 'printf "%s" "$3" > "$p" && printf "%s" "$p"',
            "sh", directory, base, content];
        writer.running = true;
        return true;
    }

    function open(path) {
        const command = Settings.notes.openCommand.trim();
        Quickshell.execDetached(command !== "" ? command.split(/\s+/).concat([path]) : ["xdg-open", path]);
    }

    function openFolder() {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p -- "$1" && exec xdg-open "$1"', "sh", directory]);
    }

    // «5 мин назад», «вчера 14:30», «12 окт».
    function ago(date) {
        const seconds = (Date.now() - date.getTime()) / 1000;
        if (seconds < 60)
            return "только что";
        if (seconds < 3600)
            return `${Math.floor(seconds / 60)} мин назад`;
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        if (date >= today)
            return Qt.formatTime(date, "HH:mm");
        if (date >= new Date(today.getTime() - 86400000))
            return "вчера " + Qt.formatTime(date, "HH:mm");
        return Qt.formatDate(date, "d MMM");
    }

    Process {
        id: writer

        stdout: StdioCollector {
            id: writerOut
        }
        stderr: StdioCollector {
            id: writerErr
        }

        onExited: code => {
            root.saving = false;
            if (code === 0 && writerOut.text !== "") {
                // Папку могли только что создать — теперь модель может за ней следить.
                root.exists = true;
                root.saved(writerOut.text);
            } else {
                root.lastError = writerErr.text.trim() || `не удалось сохранить в ${root.directory}`;
                console.warn("notes:", root.lastError);
            }
        }
    }

    Process {
        id: dirCheck

        command: ["test", "-d", root.directory]
        onExited: code => root.exists = code === 0
    }

    FolderListModel {
        id: folder

        // Пока папки нет — заведомо пустая модель (см. exists).
        folder: root.exists ? "file://" + root.directory : ""
        nameFilters: ["*.md"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Time
    }
}
