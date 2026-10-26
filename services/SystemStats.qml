pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Загрузка процессора, память, температура процессора и место на диске.
// Читает /proc и /sys раз в 2 секунды — только пока данные кому-то нужны:
// виджет «sysmon» стоит на панели, открыта панель под часами или центр управления.
Singleton {
    id: root

    readonly property bool needed: Ui.dashboardOpen || Ui.controlCenterOpen
        || [Settings.bar.left, Settings.bar.center, Settings.bar.right].some(zone => zone.includes("sysmon"))

    // Доли 0–1; температура — °C (0 — датчик не найден).
    property real cpu: 0
    property real memory: 0
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0
    property real temperature: 0
    property real disk: 0
    property real diskFreeGiB: 0
    // Все смонтированные разделы с файлами: [{ mount, name, used (0–1), totalGiB, freeGiB }],
    // корень первым. disk и diskFreeGiB — то же для корня.
    property var disks: []
    // Подкачка (раздел или файл): доля и объём; swapTotalGiB 0 — подкачки нет.
    property real swap: 0
    property real swapUsedGiB: 0
    property real swapTotalGiB: 0

    // Понятные названия частых точек монтирования.
    function diskName(mount) {
        return ({ "/": "Корень", "/home": "Домашняя", "/boot": "Загрузчик", "/boot/efi": "Загрузчик EFI" })[mount]
            ?? mount.split("/").pop() ?? mount;
    }

    // Предыдущий снимок /proc/stat: загрузка — доля не-простоя между снимками.
    property real lastTotal: 0
    property real lastIdle: 0

    property string temperaturePath: ""

    function update() {
        statFile.reload();
        const cpuLine = statFile.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (cpuLine.length >= 4) {
            // user nice system idle iowait irq softirq steal
            const idle = cpuLine[3] + (cpuLine[4] || 0);
            const total = cpuLine.slice(0, 8).reduce((a, b) => a + (b || 0), 0);
            if (lastTotal > 0 && total > lastTotal)
                cpu = Math.max(0, Math.min(1, 1 - (idle - lastIdle) / (total - lastTotal)));
            lastTotal = total;
            lastIdle = idle;
        }

        memFile.reload();
        const mem = {};
        for (const line of memFile.text().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                mem[m[1]] = Number(m[2]);
        }
        if (mem.MemTotal) {
            const used = mem.MemTotal - (mem.MemAvailable ?? mem.MemFree);
            memory = used / mem.MemTotal;
            memoryUsedGiB = used / 1048576;
            memoryTotalGiB = mem.MemTotal / 1048576;
        }
        if (mem.SwapTotal !== undefined) {
            const swapUsed = mem.SwapTotal - (mem.SwapFree ?? mem.SwapTotal);
            swapTotalGiB = mem.SwapTotal / 1048576;
            swapUsedGiB = swapUsed / 1048576;
            swap = mem.SwapTotal > 0 ? swapUsed / mem.SwapTotal : 0;
        }

        if (temperaturePath !== "") {
            tempFile.reload();
            temperature = (Number(tempFile.text().trim()) || 0) / 1000;
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.needed
        triggeredOnStart: true
        onTriggered: root.update()
    }

    // Место на разделах меняется медленно — раз в 30 секунд.
    Timer {
        interval: 30000
        repeat: true
        running: root.needed
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    Process {
        id: diskProc

        // Все разделы с файлами: без виртуальных (tmpfs и т. п.), только устройства /dev/…;
        // один раздел, смонтированный в нескольких местах, — один раз. LC_ALL=C — без перевода заголовка.
        command: ["env", "LC_ALL=C", "df", "-Pk", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs",
            "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const seen = {};
                for (const line of text.trim().split("\n").slice(1)) {
                    const f = line.trim().split(/\s+/);
                    // Точка монтирования может содержать пробелы — всё после шестого поля.
                    const device = f[0];
                    const total = Number(f[1]);
                    const usedBlocks = Number(f[2]);
                    const free = Number(f[3]);
                    const mount = f.slice(5).join(" ");
                    if (!device.startsWith("/dev/") || !(total > 0) || seen[device]
                            || Settings.dashboard.hiddenDisks.includes(mount))
                        continue;
                    seen[device] = true;
                    list.push({
                        mount: mount,
                        name: root.diskName(mount),
                        // Как «Use%» у df: без места, зарезервированного под root (у ext4 — 5 %).
                        used: usedBlocks / Math.max(1, usedBlocks + free),
                        totalGiB: total / 1048576,
                        freeGiB: free / 1048576
                    });
                }
                list.sort((a, b) => (a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount)));
                root.disks = list;
                const rootDisk = list.find(d => d.mount === "/");
                if (rootDisk) {
                    root.disk = rootDisk.used;
                    root.diskFreeGiB = rootDisk.freeGiB;
                }
            }
        }
    }

    // Датчик температуры пакета процессора (Intel — x86_pkg_temp, AMD — k10temp через hwmon).
    Process {
        running: true
        command: ["sh", "-c",
            'for z in /sys/class/thermal/thermal_zone*; do [ "$(cat "$z/type")" = x86_pkg_temp ] && echo "$z/temp" && exit; done; '
            + 'for h in /sys/class/hwmon/hwmon*; do case "$(cat "$h/name")" in k10temp|coretemp|zenpower) echo "$h/temp1_input"; exit;; esac; done']
        stdout: StdioCollector {
            onStreamFinished: root.temperaturePath = text.trim()
        }
    }

    FileView {
        id: statFile

        path: "/proc/stat"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: tempFile

        path: root.temperaturePath
        blockLoading: true
        printErrors: false
    }
}
