import QtQuick
import Quickshell
import qs.config

// LazyLoader для всплывающих окон с анимацией закрытия: после open = false окно
// живёт ещё exitDuration, пока PopupSurface сворачивается (shown: popup.open).
// Повторное открытие во время сворачивания разворачивает то же окно обратно.
//
// keepLoaded (по умолчанию): после первого открытия окно не удаляется, а только
// скрывается (windowVisible). Повторное открытие — показ готового окна, без
// построения содержимого заново: анимация плавная с первого кадра. Цена — память
// под скрытое окно (несколько мегабайт). Состояние (поиск, выбор) окно сбрасывает
// само при показе.
//
//   PopupLoader {
//       id: popup
//       open: Ui.dashboardOpen
//       PanelWindow {
//           visible: popup.windowVisible
//           WlrLayershell.keyboardFocus: popup.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
//           PopupSurface { shown: popup.open … }
//       }
//   }
LazyLoader {
    id: root

    property bool open: false
    // Окно ещё показано, но уже сворачивается.
    property bool closing: false
    // Было ли окно открыто — чтобы при запуске open = false не создавал окно ради закрытия.
    property bool wasOpen: false
    property bool keepLoaded: true

    // Окно на экране: открыто или доигрывает закрытие.
    readonly property bool windowVisible: open || closing

    readonly property int exitDuration: Theme.anim.normal

    active: open || closing || (keepLoaded && wasOpen)

    onOpenChanged: {
        if (open) {
            exitTimer.stop();
            closing = false;
            wasOpen = true;
        } else if (wasOpen && exitDuration > 0) {
            closing = true;
            exitTimer.restart();
        }
    }

    property Timer exitTimer: Timer {
        interval: root.exitDuration + 20
        onTriggered: root.closing = false
    }
}
