import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import qs.config
import qs.services

// Экран блокировки. Блокирует сессию по протоколу ext-session-lock: если оболочка
// упадёт, niri оставит экран заблокированным. Пароль проверяется через PAM
// (стек swaylock или login), PIN — оболочкой (хэш в ~/.local/state/konshell/lock-pin).
//
//   qs -c konshell ipc call lock lock
//   qs -c konshell ipc call lock preview    — тот же экран в обычном окне, Esc или closePreview закрывает
//   qs -c konshell ipc call lock setPin <PIN> | clearPin
Scope {
    id: root

    // Общий для всех мониторов ввод: пароль, проверка, ошибка.
    property string password: ""
    property string error: ""
    readonly property bool busy: pam.active
    // Состояние предпросмотра — в сервисе Lock: его открывает и окно настроек.
    readonly property bool preview: Lock.previewOpen

    signal failed

    // Сначала PIN (проверяется на месте, без PAM: неверный PIN не тратит попытки
    // pam_faillock), иначе — системный пароль через PAM.
    function submit() {
        if (pam.active || password === "")
            return;
        error = "";
        if (Lock.checkPin(password)) {
            succeed();
            return;
        }
        pam.start();
    }

    function succeed() {
        password = "";
        error = "";
        if (preview)
            Lock.previewOpen = false;
        else
            Lock.unlock();
    }

    // Отсрочка после блокировки по простою: любое действие разблокирует без пароля.
    function tryGracePeriod() {
        if (!preview && Lock.inGracePeriod())
            succeed();
    }

    function cancelPreview() {
        if (preview) {
            pam.abort();
            password = "";
            error = "";
            Lock.previewOpen = false;
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }
        function preview(): void {
            Lock.preview();
        }
        // Закрывает только предпросмотр; настоящую блокировку снимает лишь пароль или PIN.
        function closePreview(): void {
            root.cancelPreview();
        }
        function isLocked(): bool {
            return Lock.locked;
        }
        // PIN из 4–12 цифр в дополнение к системному паролю; clearPin — убрать.
        function setPin(pin: string): bool {
            return Lock.setPin(pin);
        }
        function clearPin(): void {
            Lock.clearPin();
        }
    }

    // Стек PAM: swaylock (это «auth include login»), если он установлен, иначе сам login —
    // он есть в любой системе, проверка пароля та же.
    property bool swaylockPam: false

    FileView {
        path: "/etc/pam.d/swaylock"
        printErrors: false
        blockLoading: true
        onLoaded: root.swaylockPam = true
    }

    PamContext {
        id: pam

        config: root.swaylockPam ? "swaylock" : "login"

        // Стек login спрашивает только пароль.
        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.password);
        }
        // Сообщения PAM об ошибке (например, faillock: учётная запись временно заблокирована).
        onPamMessage: {
            if (messageIsError)
                root.error = message;
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.succeed();
                return;
            }
            root.password = "";
            Lock.pinRejected();
            if (result === PamResult.MaxTries)
                root.error = "Слишком много попыток. Подождите и попробуйте снова";
            else if (root.error === "")
                root.error = "Неверный пароль";
            root.failed();
        }
        onError: err => {
            root.password = "";
            root.error = "Не удалось проверить пароль: " + PamError.toString(err);
            console.warn("lock: ошибка PAM", PamError.toString(err));
            root.failed();
        }
    }

    WlSessionLock {
        id: sessionLock

        locked: Lock.locked
        onSecureChanged: Lock.secure = secure
        onLockedChanged: {
            if (!locked)
                Lock.secure = false;
        }

        WlSessionLockSurface {
            color: Theme.color.background

            LockContent {
                anchors.fill: parent
                context: root
            }
        }
    }

    // Предпросмотр: не блокирует сессию, нужен для настройки вида.
    LazyLoader {
        active: root.preview && !Lock.locked

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-lock-preview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: Theme.color.background

            LockContent {
                anchors.fill: parent
                context: root
            }
        }
    }
}
