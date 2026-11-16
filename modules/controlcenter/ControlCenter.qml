import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Центр управления: быстрые переключатели, звук, яркость, батарея, музыка.
// Wi-Fi, Bluetooth и выбор аудиоустройств открываются отдельными страницами.
// Открывается кликом по значкам в панели или через IPC:
//   qs -c konshell ipc call controlCenter toggle
//   qs -c konshell ipc call controlCenter open wifi
Scope {
    id: root

    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            Ui.controlCenterOpen = !Ui.controlCenterOpen;
        }
        // page: main | wifi | bluetooth | audio (appearance — окно настроек)
        function open(page: string): void {
            if (page === "appearance") {
                Ui.openSettings("appearance");
                return;
            }
            Ui.controlCenterPage = page || "main";
            Ui.controlCenterOpen = true;
        }
    }

    // Запись экрана и снимки:
    //   qs -c konshell ipc call recorder toggle          # весь экран; повторно — стоп
    //   qs -c konshell ipc call recorder region          # выбрать область
    //   qs -c konshell ipc call recorder stop | status
    //   qs -c konshell ipc call recorder screenshot      # инструмент снимков niri
    IpcHandler {
        target: "recorder"

        function toggle(): void {
            ScreenRecorder.toggle("screen");
        }
        function region(): void {
            if (ScreenRecorder.recording)
                ScreenRecorder.stop();
            else
                ScreenRecorder.start("region", 0);
        }
        function stop(): void {
            ScreenRecorder.stop();
        }
        function status(): string {
            return JSON.stringify({
                available: ScreenRecorder.available,
                recording: ScreenRecorder.recording,
                elapsed: ScreenRecorder.elapsed,
                file: ScreenRecorder.file,
                directory: ScreenRecorder.directory,
                lastError: ScreenRecorder.lastError
            });
        }
        function screenshot(): void {
            ScreenRecorder.screenshot(0);
        }
    }

}
