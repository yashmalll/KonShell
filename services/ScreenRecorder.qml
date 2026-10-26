pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Запись экрана через wf-recorder: монитор с фокусом целиком или область,
// выбранная slurp. Видео кодирует видеокарта (VAAPI, H.264); если она не
// справилась — повтор с программным libx264. Звук — системный (монитор
// устройства вывода по умолчанию) или микрофон (recorder.audio).
// Остановка — SIGINT: wf-recorder дописывает файл и выходит.
//
// Файлы: recorder.directory или «Видео/Записи экрана» (xdg-user-dir VIDEOS).
Singleton {
    id: root

    readonly property bool available: tools.found
    property bool recording: false
    // Выбор области (slurp) или пауза перед стартом — запись ещё не идёт.
    property bool preparing: false
    property real startedAt: 0
    property int elapsed: 0
    property string file: ""
    property string lastError: ""

    property string videosDir: Quickshell.env("HOME") + "/Videos"
    readonly property string directory: {
        const custom = Settings.recorder.directory.trim();
        if (custom !== "")
            return custom.startsWith("~/") ? Quickshell.env("HOME") + custom.slice(1) : custom;
        return videosDir + "/Записи экрана";
    }

    // Параметры текущей записи — для повтора без видеокарты.
    // VAAPI уже отказал в этом сеансе — дальше сразу программное кодирование.
    property bool vaapiBroken: false

    property string geometry: ""
    property string output: ""
    property bool software: false

    // «0:42», «1:05:12».
    function format(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds / 60) % 60;
        const s = String(seconds % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${s}` : `${m}:${s}`;
    }

    // mode: screen — монитор с фокусом; region — выбрать область мышью.
    // delay — мс до начала (успеть закрыть панель, из которой запустили).
    function start(mode, delay) {
        if (!available || recording || preparing)
            return;
        lastError = "";
        preparing = true;
        output = Niri.focusedWorkspace?.output ?? "";
        geometry = "";
        software = !Settings.recorder.hardware || vaapiBroken;
        if (mode === "region") {
            // Пауза — чтобы панель, из которой запустили, успела закрыться до выбора.
            regionDelay.interval = Math.max(0, delay ?? 0);
            regionDelay.start();
        } else {
            startDelay.interval = Math.max(0, delay ?? 0);
            startDelay.start();
        }
    }

    function stop() {
        if (recording)
            recorder.signal(2);
        else if (preparing) {
            startDelay.stop();
            regionDelay.stop();
            preparing = false;
        }
    }

    function toggle(mode) {
        recording || preparing ? stop() : start(mode, 0);
    }

    // Инструмент снимков niri (область, окно, экран). Задержка — чтобы панель,
    // из которой его вызвали, успела закрыться и не попала в снимок.
    function screenshot(delay) {
        screenshotDelay.interval = Math.max(0, delay ?? 0);
        screenshotDelay.restart();
    }

    function launch() {
        const name = "Запись " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH-mm-ss") + ".mp4";
        file = directory + "/" + name;
        const audio = Settings.recorder.audio;
        recorder.command = ["sh", "-c",
            'dir=$1 file=$2 out=$3 geom=$4 audio=$5 soft=$6; mkdir -p -- "$dir" || exit 1\n'
            + 'set -- -y -f "$file"\n'
            + '[ -n "$out" ] && [ -z "$geom" ] && set -- "$@" -o "$out"\n'
            + '[ -n "$geom" ] && set -- "$@" -g "$geom"\n'
            + '[ "$soft" = 1 ] || set -- "$@" -c h264_vaapi -d /dev/dri/renderD128\n'
            + 'case $audio in\n'
            + '  system) set -- "$@" --audio="$(pactl get-default-sink).monitor";;\n'
            + '  mic) set -- "$@" --audio="$(pactl get-default-source)";;\n'
            + 'esac\n'
            // Оболочка умерла посреди записи — SIGINT: wf-recorder корректно допишет файл.
            + 'exec setpriv --pdeathsig INT wf-recorder "$@"',
            "sh", directory, file, output, geometry, audio, software ? "1" : "0"];
        startedAt = Date.now();
        elapsed = 0;
        preparing = false;
        recording = true;
        recorder.running = true;
    }

    Timer {
        id: startDelay

        onTriggered: root.launch()
    }

    Timer {
        id: screenshotDelay

        onTriggered: Quickshell.execDetached(["niri", "msg", "action", "screenshot"])
    }

    Timer {
        id: regionDelay

        onTriggered: slurp.running = true
    }

    // Счётчик времени для индикатора — только пока идёт запись.
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }

    Process {
        id: tools

        property bool found: false

        running: true
        command: ["sh", "-c", "command -v wf-recorder >/dev/null && command -v slurp >/dev/null"]
        onExited: code => found = code === 0
    }

    Process {
        id: xdgVideos

        running: true
        command: ["xdg-user-dir", "VIDEOS"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                if (dir !== "" && dir !== Quickshell.env("HOME"))
                    root.videosDir = dir;
            }
        }
    }

    // Выбор области: «x,y WxH»; Esc в slurp — отмена.
    Process {
        id: slurp

        command: ["slurp", "-d"]
        stdout: StdioCollector {
            id: slurpOut
        }
        onExited: code => {
            const geom = slurpOut.text.trim();
            if (code !== 0 || geom === "") {
                root.preparing = false;
                return;
            }
            root.geometry = geom;
            root.launch();
        }
    }

    Process {
        id: recorder

        stderr: StdioCollector {
            id: recorderErr
        }

        onExited: code => {
            const seconds = (Date.now() - root.startedAt) / 1000;
            root.recording = false;
            // wf-recorder и при сбое захвата выходит с кодом 0 («Failed to copy frame
            // too many times, exiting!» — так бывает с VAAPI), поэтому сбой узнаём и по тексту.
            const failed = (code !== 0 && code !== 130)
                || /too many times|Failed to select output|Couldn't find requested output|Failed to detect output/.test(recorderErr.text);
            // Видеокарта не справилась сразу — то же самое программно.
            if (!root.software && seconds < 3 && failed) {
                console.warn("recorder: VAAPI не сработал, повтор с libx264:", recorderErr.text.trim().split("\n").pop());
                root.vaapiBroken = true;
                root.software = true;
                root.launch();
                return;
            }
            if (failed && (seconds < 1.5 || code === 0)) {
                root.lastError = recorderErr.text.trim().split("\n").pop() || `wf-recorder завершился с кодом ${code}`;
                console.warn("recorder:", root.lastError);
                Quickshell.execDetached(["notify-send", "-a", "KonShell", "-i", "media-record-symbolic",
                    "Запись не началась", root.lastError]);
                return;
            }
            // Готово: уведомление с действиями «Открыть» и «Показать в папке».
            Quickshell.execDetached(["sh", "-c",
                'a=$(notify-send -a KonShell -i media-record-symbolic -A open=Открыть -A folder="Показать в папке" '
                + '"Запись сохранена" "$(basename "$1") · $2"); '
                + 'case $a in open) xdg-open "$1";; folder) xdg-open "$(dirname "$1")";; esac',
                "sh", root.file, root.format(Math.round(seconds))]);
        }
    }
}
