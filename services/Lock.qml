pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

// Состояние блокировки экрана и всё, что её вызывает: простой, сон, loginctl lock-session.
// Сам экран блокировки — modules/lock/LockScreen.qml.
//
// Перед сном оболочка держит у systemd «отложенную» задержку сна и отпускает её,
// только когда niri подтвердил блокировку (secure): после пробуждения не мелькнёт
// незаблокированный рабочий стол.
//
// Состояние «заблокировано» хранится в файле: если оболочку перезапустят, пока экран
// заблокирован, она сразу заблокирует его снова и примет ввод пароля.
Singleton {
    id: root

    property bool locked: false
    // niri показал экран блокировки на всех мониторах.
    property bool secure: false

    readonly property string markerPath:
        (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/konshell/locked"

    // PIN экрана блокировки — в дополнение к системному паролю, не вместо него.
    // Хранится как "соль:md5(соль+PIN)" в файле с правами 600. Четыре цифры перебираются
    // мгновенно, если файл прочитать: хеш защищает только от случайного взгляда.
    readonly property string pinPath:
        (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/konshell/lock-pin"
    readonly property var pinRecord: {
        const parts = pinFile.text().trim().split(":");
        return parts.length === 2 && parts[1].length === 32 ? { salt: parts[0], hash: parts[1] } : null;
    }
    readonly property bool hasPin: pinRecord !== null

    // После maxPinFailures неверных попыток PIN не принимается pinCooldown мс — только пароль.
    readonly property int maxPinFailures: 5
    readonly property int pinCooldown: 5 * 60 * 1000
    property int pinFailures: 0
    property bool pinBlocked: false

    // true — введён верный PIN. Неверный ввод засчитывается, только если и пароль не подошёл
    // (вызов pinRejected из экрана блокировки).
    function checkPin(input) {
        if (!hasPin || pinBlocked)
            return false;
        if (Qt.md5(pinRecord.salt + input) === pinRecord.hash) {
            pinFailures = 0;
            return true;
        }
        return false;
    }

    function pinRejected() {
        if (!hasPin)
            return;
        pinFailures++;
        if (pinFailures >= maxPinFailures) {
            pinFailures = 0;
            pinBlocked = true;
            pinUnblock.restart();
            console.warn("lock: слишком много неверных PIN — PIN отключён на 5 минут");
        }
    }

    function setPin(pin) {
        if (!/^[0-9]{4,12}$/.test(pin)) {
            console.warn("lock: PIN должен состоять из 4–12 цифр");
            return false;
        }
        const salt = Qt.md5(String(Math.random()) + Date.now()).slice(0, 16);
        pinFile.setText(salt + ":" + Qt.md5(salt + pin) + "\n");
        Quickshell.execDetached(["chmod", "600", pinPath]);
        return true;
    }

    // Пустой файл — PIN не задан (pinRecord разбирает только «соль:хеш»).
    function clearPin() {
        pinFile.setText("");
    }

    // Предпросмотр экрана блокировки в обычном окне (modules/lock/LockScreen.qml).
    property bool previewOpen: false

    function preview() {
        previewOpen = true;
    }

    // Когда и почему заблокирован: отсрочка (lock.gracePeriod) действует только
    // для блокировки по простою.
    property real lockedAt: 0
    property string lockReason: ""

    // reason: idle | sleep | manual
    function lock(reason) {
        if (locked)
            return;
        lockReason = reason || "manual";
        lockedAt = Date.now();
        locked = true;
        marker.setText(new Date().toISOString() + "\n");
        console.info("lock: экран заблокирован");
    }

    // Идёт отсрочка: только что заблокировано по простою — любое действие разблокирует.
    function inGracePeriod() {
        return lockReason === "idle" && Settings.lock.gracePeriod > 0
            && Date.now() - lockedAt < Settings.lock.gracePeriod * 1000;
    }

    // Вызывается экраном блокировки только после успешной проверки пароля.
    function unlock() {
        locked = false;
        Quickshell.execDetached(["rm", "-f", markerPath]);
        console.info("lock: экран разблокирован");
    }

    // Блокировка по простою (учитывает запреты простоя, например видео во весь экран).
    IdleMonitor {
        enabled: Settings.lock.idleTimeout > 0 && !root.locked
        timeout: Settings.lock.idleTimeout
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                root.lock("idle");
        }
    }

    // На заблокированном экране мониторы гаснут после простоя; niri включает их от любого ввода.
    IdleMonitor {
        enabled: Settings.lock.screenOffTimeout > 0 && root.locked
        timeout: Settings.lock.screenOffTimeout
        respectInhibitors: false
        onIsIdleChanged: {
            if (isIdle)
                Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
        }
    }

    // Сигналы logind: подготовка ко сну и loginctl lock-session.
    Process {
        id: logind

        // stdbuf: без построчного вывода gdbus копит строки в буфере, и сигнал о сне пришёл бы поздно.
        // gdbus — прямой потомок оболочки (без sh между ними): при перезагрузке Quickshell
        // убивает его сам, а если умрёт оболочка — ядро (setpriv --pdeathsig). Через sh
        // перезагрузка убивала только sh, и gdbus оставался сиротой — копились десятками.
        command: ["setpriv", "--pdeathsig", "KILL", "stdbuf", "-oL", "gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("org.freedesktop.login1.Manager.PrepareForSleep (true")) {
                    if (Settings.lock.beforeSleep)
                        root.lock("sleep");
                } else if (line.includes("org.freedesktop.login1.Session.Lock ()")) {
                    root.lock("manual");
                }
            }
        }
        // gdbus может упасть при перезапуске D-Bus: перезапускаем.
        onExited: restartLogind.start()
    }

    Timer {
        id: restartLogind

        interval: 2000
        onTriggered: logind.running = true
    }

    // Задержка сна, пока экран не заблокирован надёжно. systemd-inhibit держит её, пока
    // жив его потомок (sleep). Оба умирают вместе с оболочкой (setpriv --pdeathsig), так
    // что задержка не повиснет у systemd и сирот не останется.
    Process {
        command: ["setpriv", "--pdeathsig", "KILL", "systemd-inhibit", "--what=sleep", "--who=KonShell",
            "--why=Заблокировать экран перед сном", "--mode=delay",
            "setpriv", "--pdeathsig", "KILL", "sleep", "infinity"]
        running: Settings.lock.beforeSleep && !(root.locked && root.secure)
    }

    Timer {
        id: pinUnblock

        interval: root.pinCooldown
        onTriggered: root.pinBlocked = false
    }

    FileView {
        id: pinFile

        path: root.pinPath
        printErrors: false
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        onFileChanged: reload()
    }

    FileView {
        id: marker

        path: root.markerPath
        printErrors: false
        blockLoading: true
        atomicWrites: true
    }

    // Оболочку перезапустили, пока экран был заблокирован: блокируем снова.
    Component.onCompleted: {
        if (marker.text() !== "") {
            console.warn("lock: при запуске найдена незавершённая блокировка — блокирую экран снова");
            locked = true;
        }
    }
}
