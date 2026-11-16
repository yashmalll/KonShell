pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../config/countdown.js" as Logic

Singleton {
    id: root
    property var state: Logic.idle()
    property real now: Date.now()
    property string ownedFocusId: ""
    readonly property bool active: state.phase !== "idle"
    readonly property bool attention: state.phase === "finished"
    readonly property bool running: state.running
    readonly property real remaining: Logic.remaining(state, now)
    readonly property string text: Logic.format(remaining)
    readonly property real progress: state.total > 0 ? Math.max(0, Math.min(1, 1 - remaining / state.total)) : 0
    readonly property string phaseName: ({ timer: "Таймер", work: "Работа", rest: "Перерыв", longRest: "Длинный перерыв", finished: "Время вышло", idle: "Таймер" })[state.phase]
    readonly property string summary: attention ? "Время вышло" : `${phaseName} · ${text}${running ? "" : " · пауза"}`

    function save() { file.setText(JSON.stringify(Object.assign({}, state, { ownedFocusId }))); }
    function clearAlerts() {
        for (const notification of Notifications.history.filter(item => item.appName === "KonShell Timer"))
            notification.dismiss();
    }
    function releaseFocus() {
        if (ownedFocusId && FocusMode.sessionId === ownedFocusId) FocusMode.stop();
        ownedFocusId = "";
    }
    function syncFocus() {
        if (!(state.mode === "pomodoro" && state.phase === "work" && running && Settings.timer.focusDuringWork)) {
            releaseFocus();
        } else if (!FocusMode.active) {
            FocusMode.start(0);
            ownedFocusId = FocusMode.sessionId;
        }
    }
    function start(seconds) {
        const next = Logic.start(seconds, Date.now());
        if (!next) return false;
        releaseFocus(); clearAlerts(); now = Date.now(); state = next; save(); return true;
    }
    function startPomodoro() {
        const next = Logic.pomodoro(Settings.timer.workMinutes * 60, Settings.timer.breakMinutes * 60,
            Settings.timer.longBreakMinutes * 60, Settings.timer.autoAdvance, Date.now());
        if (!next) return false;
        releaseFocus(); clearAlerts(); now = Date.now(); state = next; syncFocus(); save(); return true;
    }
    function pause() { update(); state = Logic.pause(state, now); releaseFocus(); save(); }
    function resume() { now = Date.now(); state = Logic.resume(state, now); syncFocus(); save(); }
    function stop() { releaseFocus(); clearAlerts(); state = Logic.idle(); save(); }
    function update() {
        now = Date.now();
        const result = Logic.advance(state, now);
        if (!result.event) return;
        state = result.state;
        syncFocus();
        save();
        if (Settings.timer.notify) {
            const message = result.event === "finished" ? "Заданный интервал завершён."
                : result.event === "work" ? (running ? "Начинается следующий рабочий интервал." : "Следующий рабочий интервал готов к запуску.")
                : running ? "Рабочий интервал завершён. Пора отдохнуть."
                : "Рабочий интервал завершён. Нажмите «Продолжить», чтобы начать перерыв.";
            Quickshell.execDetached(["notify-send", "-a", "KonShell Timer", "-u", "critical", "-i", "preferences-system-time-symbolic", phaseName, message]);
        }
    }
    Timer { interval: 1000; repeat: true; running: root.running; onTriggered: root.update() }
    Connections {
        target: Settings.timer
        function onFocusDuringWorkChanged() { root.syncFocus(); root.save(); }
        function onAutoAdvanceChanged() {
            if (root.state.mode === "pomodoro") {
                root.state = Object.assign({}, root.state, { autoAdvance: Settings.timer.autoAdvance });
                root.save();
            }
        }
    }
    FileView {
        id: file
        path: Paths.state + "/countdown.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text() || "{}");
                root.state = Logic.restore(data);
                root.ownedFocusId = typeof data.ownedFocusId === "string" ? data.ownedFocusId : "";
                if (root.ownedFocusId !== FocusMode.sessionId) root.ownedFocusId = "";
                if (!root.running || root.state.phase !== "work") root.releaseFocus();
                root.update();
            } catch (error) { console.warn("timer: invalid saved state"); }
        }
    }
}
