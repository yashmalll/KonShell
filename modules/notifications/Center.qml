import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// История уведомлений и переключатель «не беспокоить».
// Открывается кнопкой в панели или через IPC:
//   qs -c konshell ipc call notifications toggleCenter
Scope {
    id: root

    IpcHandler {
        target: "notifications"

        function toggleCenter(): void {
            Notifications.centerOpen = !Notifications.centerOpen;
        }
        function toggleDnd(): void {
            Notifications.setDnd(!Notifications.dnd);
        }
        function clear(): void {
            Notifications.clearAll();
        }
    }

}
