pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Яркость подсветки. Значение читается из sysfs, меняется через brightnessctl
// (он умеет писать через logind без прав root). sysfs не сообщает об изменениях,
// поэтому файл перечитывается после каждой установки.
Singleton {
    id: root

    // Первое устройство из /sys/class/backlight, если в настройках не задано своё.
    property string device: Settings.brightness.device

    readonly property bool available: device !== "" && max > 0
    readonly property int max: parseInt(maxFile.text()) || 0
    property int current: parseInt(currentFile.text()) || 0
    readonly property real percent: available ? current / max : 0

    // Только для изменений из оболочки: внешние sysfs не заметить.
    signal adjusted

    function setPercent(value) {
        if (!available)
            return;
        const minimum = Settings.brightness.minPercent / 100;
        const target = Math.round(Math.max(minimum, Math.min(1, value)) * max);
        current = target;
        setter.command = ["brightnessctl", "-q", "-d", device, "set", String(target)];
        setter.running = true;
        adjusted();
    }

    function increase() {
        setPercent(percent + Settings.brightness.step / 100);
    }

    function decrease() {
        setPercent(percent - Settings.brightness.step / 100);
    }

    Process {
        running: root.device === ""
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    Process {
        id: setter

        onExited: code => {
            if (code !== 0)
                console.warn("brightness: brightnessctl завершился с кодом", code);
        }
        // Срабатывает и когда brightnessctl не запустился: тогда onExited не вызывается.
        onRunningChanged: {
            if (!running)
                currentFile.reload();
        }
    }

    FileView {
        id: maxFile

        path: root.device ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        blockLoading: true
    }

    FileView {
        id: currentFile

        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        blockLoading: true
        onLoaded: root.current = parseInt(text()) || 0
    }
}
