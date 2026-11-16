pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root
    property bool active: false
    property string sessionId: ""
    property real until: 0
    property real now: Date.now()
    readonly property int minutesLeft: until > 0 ? Math.max(0, Math.ceil((until - now) / 60000)) : 0
    readonly property string summary: !active ? "Выключен" : until > 0 ? `Фокус · ${minutesLeft} мин` : "Фокус"

    function start(minutes) {
        if (!Number.isFinite(minutes) || minutes < 0 || minutes > 720)
            return false;
        now = Date.now();
        until = minutes > 0 ? now + minutes * 60000 : 0;
        sessionId = String(now) + "-" + String(Math.random()).slice(2);
        active = true;
        save();
        return true;
    }
    function stop() { active = false; until = 0; sessionId = ""; save(); }
    function toggle() { active ? stop() : start(Settings.system.focusMinutes); }
    function save() { state.setText(JSON.stringify({ active, until, sessionId })); }

    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.until > 0
        onTriggered: {
            root.now = Date.now();
            if (root.now >= root.until) root.stop();
        }
    }
    FileView {
        id: state
        path: Paths.state + "/focus.json"
        atomicWrites: true
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text() || "{}");
                root.now = Date.now();
                root.until = Number.isFinite(data.until) ? Math.max(0, data.until) : 0;
                root.active = data.active === true && (root.until === 0 || root.until > root.now);
                root.sessionId = root.active ? (typeof data.sessionId === "string" && data.sessionId ? data.sessionId : "legacy") : "";
            } catch (error) { console.warn("focus: invalid saved state"); }
        }
    }
}
