//@ pragma UseQApplication
//@ pragma IconTheme Adwaita
// Без заголовка Qt у окна настроек: в стиле niri окна без декораций, закрыть — кнопкой в окне.
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1
// Невидимым поверхностям (обои под окнами, задник обзора) niri шлёт сигнал кадра
// примерно раз в секунду. По умолчанию Qt ждёт его 100 мс, объявляет окно скрытым,
// а с приходом сигнала — снова видимым и перерисовывает целиком: кадр в секунду
// и лишние пробуждения в простое. С долгим ожиданием окно просто не рисует, пока скрыто.
//@ pragma Env QT_WAYLAND_FRAME_CALLBACK_TIMEOUT=3600000
import Quickshell
import qs.modules.appearance
import qs.modules.bar
import qs.modules.clipboard
import qs.modules.controlcenter
import qs.modules.dashboard
import qs.modules.dock
import qs.modules.launcher
import qs.modules.lock
import qs.modules.notifications
import qs.modules.osd
import qs.modules.polkit
import qs.modules.session
import qs.modules.settings
import qs.modules.sidebar

ShellRoot {
    Backdrop {}
    AppearanceIpc {}
    Bar {}
    Dock {}
    Dashboard {}
    Launcher {}
    ClipboardHistory {}
    Popups {}
    Center {}
    ControlCenter {}
    Sidebar {}
    NoteWindow {}
    Osd {}
    LockScreen {}
    SettingsWindow {}
    PolkitDialog {}
    SessionMenu {}
}
