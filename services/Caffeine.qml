pragma Singleton

import QtQuick
import Quickshell

// «Не засыпать»: пока включено, панель держит Wayland idle-inhibit
// (IdleInhibitor в modules/bar/Bar.qml) — простой не наступает, экран
// не блокируется и не гаснет по таймеру (Lock: respectInhibitors).
// Можно включить на время: minutes > 0 — само выключится.
Singleton {
    id: root

    property bool active: false
    // Когда выключится само (мс с эпохи); 0 — пока не выключат.
    property real until: 0
    // Для подписи «ещё 42 мин»: обновляется раз в минуту.
    property real now: Date.now()

    readonly property int minutesLeft: until > 0 ? Math.max(0, Math.ceil((until - now) / 60000)) : 0

    function enable(minutes) {
        until = minutes > 0 ? Date.now() + minutes * 60000 : 0;
        now = Date.now();
        active = true;
    }

    function disable() {
        active = false;
        until = 0;
    }

    // Плитка: выкл → бессрочно → 1 ч → 2 ч → выкл.
    function cycle() {
        if (!active)
            enable(0);
        else if (until === 0)
            enable(60);
        else if (minutesLeft <= 60)
            enable(120);
        else
            disable();
    }

    readonly property string summary: !active ? "Выключено"
        : until === 0 ? "Пока не выключите"
        : minutesLeft >= 60 ? `Ещё ${Math.floor(minutesLeft / 60)} ч ${minutesLeft % 60 > 0 ? (minutesLeft % 60) + " мин" : ""}`.trim()
        : `Ещё ${minutesLeft} мин`

    Timer {
        interval: 30000
        repeat: true
        running: root.active && root.until > 0
        onTriggered: {
            root.now = Date.now();
            if (root.now >= root.until)
                root.disable();
        }
    }
}
