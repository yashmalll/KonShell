import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Меню сеанса поверх затемнённого экрана: блокировка, сон, выход, перезагрузка,
// выключение. Выход, перезагрузка и выключение — после обратного отсчёта
// (session.confirm, session.countdown): повторное нажатие — сразу, Esc — отмена.
// Клавиатура: ←/→ или Tab — выбор, Enter или пробел — действие, Esc — назад.
// Открывается кнопкой питания в центре управления или через IPC:
//   qs -c konshell ipc call session toggle
Scope {
    id: root

    readonly property var actions: [
        { id: "lock", name: "Блокировка", icon: "system-lock-screen-symbolic", confirm: false },
        { id: "suspend", name: "Сон", icon: "weather-clear-night-symbolic", confirm: false },
        { id: "logout", name: "Выход", icon: "system-log-out-symbolic", confirm: true },
        { id: "reboot", name: "Перезагрузка", icon: "system-reboot-symbolic", confirm: true },
        { id: "poweroff", name: "Выключение", icon: "system-shutdown-symbolic", confirm: true }
    ]

    // Действие, ждущее конца отсчёта, и сколько осталось (секунды, дробные — для кольца).
    property string pending: ""
    property real remaining: 0

    function find(id) {
        return actions.find(a => a.id === id) ?? null;
    }

    function choose(id) {
        const action = find(id);
        if (!action)
            return;
        if (pending === id || !action.confirm || !Settings.session.confirm) {
            run(id);
            return;
        }
        pending = id;
        remaining = Math.max(1, Settings.session.countdown);
    }

    function cancel() {
        pending = "";
        remaining = 0;
    }

    // Сначала меню закрывается, потом действие: блокировке и сну не мешает
    // окно с захватом клавиатуры.
    function run(id) {
        cancel();
        Ui.sessionOpen = false;
        switch (id) {
        case "lock":
            Lock.lock("manual");
            break;
        case "suspend":
            // Блокировку перед сном делает сам Lock (lock.beforeSleep).
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "logout":
            Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]);
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "poweroff":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
    }

    Connections {
        target: Ui

        function onSessionOpenChanged() {
            if (!Ui.sessionOpen)
                root.cancel();
        }
    }

    // Обратный отсчёт: 20 тиков в секунду, чтобы кольцо шло плавно.
    Timer {
        interval: 50
        repeat: true
        running: root.pending !== ""
        onTriggered: {
            root.remaining = Math.max(0, root.remaining - interval / 1000);
            if (root.remaining <= 0)
                root.run(root.pending);
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            Ui.sessionOpen = !Ui.sessionOpen;
        }
        function open(): void {
            Ui.sessionOpen = true;
        }
        function close(): void {
            Ui.sessionOpen = false;
        }
        // lock | suspend | logout | reboot | poweroff — с отсчётом, как кнопкой.
        function request(action: string): void {
            Ui.sessionOpen = true;
            root.choose(action);
        }
    }

    // Время работы для подписи: «Работает 3 ч 12 мин».
    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false
    }

    PopupLoader {
        id: popup

        open: Ui.sessionOpen

        PanelWindow {

            // Скрытое окно (PopupLoader.keepLoaded) не показывается, но и не удаляется.

            visible: popup.windowVisible

            id: window

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-session"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: popup.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            // Пока сворачивается — клики и клавиатура уже не перехватываются.
            mask: popup.open ? null : closedMask

            Region {
                id: closedMask
            }

            BackgroundEffect.blurRegion: Region {
                item: card.blurItem
                radius: card.radius
            }

            property int selected: 0

            onVisibleChanged: {
                if (visible) {
                    selected = 0;
                    uptimeFile.reload();
                    card.forceActiveFocus();
                }
            }

            // Затемнение экрана: проявляется и гаснет вместе с меню.
            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.color.scrim, 0.55)
                opacity: popup.open ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: Theme.anim.slow; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Ui.sessionOpen = false
                }
            }

            PopupSurface {
                id: card

                shown: popup.open
                anchors.centerIn: parent
                width: content.implicitWidth + Theme.spacing.xl * 2
                height: content.implicitHeight + Theme.spacing.xl * 2
                radius: Theme.radius.panel + 8
                focus: true

                Keys.onEscapePressed: {
                    if (root.pending !== "")
                        root.cancel();
                    else
                        Ui.sessionOpen = false;
                }
                Keys.onLeftPressed: window.selected = (window.selected + root.actions.length - 1) % root.actions.length
                Keys.onRightPressed: window.selected = (window.selected + 1) % root.actions.length
                Keys.onTabPressed: window.selected = (window.selected + 1) % root.actions.length
                Keys.onBacktabPressed: window.selected = (window.selected + root.actions.length - 1) % root.actions.length
                Keys.onReturnPressed: root.choose(root.actions[window.selected].id)
                Keys.onEnterPressed: root.choose(root.actions[window.selected].id)
                Keys.onSpacePressed: root.choose(root.actions[window.selected].id)

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: content

                    x: Theme.spacing.xl
                    y: Theme.spacing.xl
                    spacing: Theme.spacing.lg

                    // Заголовок: кто и сколько работает — или что сейчас произойдёт.
                    Column {
                        width: buttons.width
                        spacing: Theme.spacing.xxs

                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: root.pending !== ""
                                ? `${root.find(root.pending).name} через ${Math.ceil(root.remaining)} с`
                                : Quickshell.env("USER") ?? ""
                            font.pixelSize: Theme.font.title
                            font.weight: Theme.font.medium
                        }

                        StyledText {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                if (root.pending !== "")
                                    return "Нажмите ещё раз — сразу, Esc — отмена";
                                const seconds = parseFloat(uptimeFile.text().split(" ")[0]) || 0;
                                const h = Math.floor(seconds / 3600);
                                const m = Math.floor(seconds / 60) % 60;
                                return h > 0 ? `Работает ${h} ч ${m} мин` : `Работает ${m} мин`;
                            }
                            color: Theme.color.textMuted
                            font.pixelSize: Theme.font.caption
                        }
                    }

                    Row {
                        id: buttons

                        spacing: Theme.spacing.md

                        Repeater {
                            model: root.actions

                            SessionButton {
                                required property var modelData
                                required property int index

                                action: modelData
                                selected: window.selected === index
                                pending: root.pending === modelData.id
                                // Доля оставшегося отсчёта: кольцо убывает от 1 к 0.
                                progress: pending ? root.remaining / Math.max(1, Settings.session.countdown) : 0
                                dimmed: root.pending !== "" && !pending
                                onHovered: window.selected = index
                                onActivated: root.choose(modelData.id)
                            }
                        }
                    }

                    // Отмена отсчёта мышью.
                    TextButton {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Отмена"
                        opacity: root.pending !== "" ? 1 : 0
                        enabled: root.pending !== ""
                        onClicked: root.cancel()

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.anim.fast }
                        }
                    }
                }
            }
        }
    }
}
