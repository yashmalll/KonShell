import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Панель под часами: крупные время и дата, календарь, плеер и быстрая заметка —
// колонками рядом (до четырёх), размер по содержимому.
// Открывается кликом по часам в панели или через IPC:
//   qs -c konshell ipc call dashboard toggle
//   qs -c konshell ipc call dashboard note     # сразу в поле новой заметки
// Esc или клик мимо закрывают.
Scope {
    id: root

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            Ui.dashboardOpen = !Ui.dashboardOpen;
        }
        function open(): void {
            Ui.openDashboard(false);
        }
        function note(): void {
            Ui.openDashboard(true);
        }
        function close(): void {
            Ui.dashboardOpen = false;
        }
    }

    // Диагностика монитора системы и «Не засыпать».
    IpcHandler {
        target: "system"

        function stats(): string {
            return JSON.stringify({
                cpu: SystemStats.cpu,
                memory: SystemStats.memory,
                memoryUsedGiB: SystemStats.memoryUsedGiB,
                temperature: SystemStats.temperature,
                temperaturePath: SystemStats.temperaturePath,
                disk: SystemStats.disk,
                diskFreeGiB: SystemStats.diskFreeGiB,
                disks: SystemStats.disks,
                swap: SystemStats.swap,
                swapTotalGiB: SystemStats.swapTotalGiB,
                polling: SystemStats.needed
            });
        }
        function caffeine(): string {
            return JSON.stringify({ active: Caffeine.active, minutesLeft: Caffeine.minutesLeft, summary: Caffeine.summary });
        }
        function toggleCaffeine(): void {
            Caffeine.active ? Caffeine.disable() : Caffeine.enable(0);
        }
    }

}
