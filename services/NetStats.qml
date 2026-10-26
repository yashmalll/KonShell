pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Сеть для панели под часами: скорость и пакеты в секунду, объём с включения,
// внутренний IP, шлюз, VPN, внешний IP. Работает, только пока панель открыта
// или на панели стоит виджет «Сеть».
//
// Трафик считается по физическому интерфейсу с шлюзом (Wi-Fi или кабель):
// через него идёт и трафик VPN. VPN — маршрут по умолчанию без шлюза
// (tun, wg, xray…), его адрес показывается отдельно.
//
// Внешний IP знает только внешний сервис: запрос к ipinfo.io уходит при открытии
// панели не чаще раза в 5 минут (и по кнопке), network.externalIp = false — никогда.
Singleton {
    id: root

    readonly property bool needed: Ui.dashboardOpen
        || [Settings.bar.left, Settings.bar.center, Settings.bar.right].some(zone => zone.includes("network"))

    // Интерфейс, адрес, шлюз.
    property string iface: ""
    property string localIp: ""
    property string gateway: ""
    property string vpnIface: ""
    property string vpnIp: ""

    // Скорости — байт и пакетов в секунду; объём — байт с включения интерфейса.
    property real rxRate: 0
    property real txRate: 0
    property real rxPackets: 0
    property real txPackets: 0
    property real rxTotal: 0
    property real txTotal: 0
    // Последние 60 секунд, байт/с — для графика.
    property var rxHistory: []
    property var txHistory: []
    readonly property int historyLength: 60

    // Внешний адрес: ip, город, страна, провайдер. externalState: idle | loading | ok | error.
    property string externalIp: ""
    property string externalPlace: ""
    property string externalOrg: ""
    property string externalState: "idle"
    property real externalAt: 0

    // Предыдущий снимок счётчиков интерфейса.
    property var last: null

    function refreshExternal(force) {
        if (!Settings.network.externalIp || externalProc.running)
            return;
        if (!force && externalState === "ok" && Date.now() - externalAt < 5 * 60000)
            return;
        externalState = "loading";
        externalProc.running = true;
    }

    // «1,2 МБ/с», «340 КБ», «12 Б».
    function bytes(value, perSecond) {
        const units = ["Б", "КБ", "МБ", "ГБ", "ТБ"];
        let v = Math.max(0, value);
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        const text = i === 0 || v >= 100 ? Math.round(v).toString() : v.toFixed(1).replace(".", ",");
        return `${text} ${units[i]}${perSecond ? "/с" : ""}`;
    }

    function sample() {
        devFile.reload();
        if (iface === "")
            return;
        const line = devFile.text().split("\n").find(l => l.trim().startsWith(iface + ":"));
        if (!line)
            return;
        // rx: bytes packets … (8 полей), tx: bytes packets …
        const f = line.split(":")[1].trim().split(/\s+/).map(Number);
        const now = { t: Date.now(), rxB: f[0], rxP: f[1], txB: f[8], txP: f[9] };
        rxTotal = now.rxB;
        txTotal = now.txB;
        if (last && last.iface === iface && now.t > last.t && now.rxB >= last.rxB && now.txB >= last.txB) {
            const dt = (now.t - last.t) / 1000;
            rxRate = (now.rxB - last.rxB) / dt;
            txRate = (now.txB - last.txB) / dt;
            rxPackets = (now.rxP - last.rxP) / dt;
            txPackets = (now.txP - last.txP) / dt;
            rxHistory = rxHistory.concat([rxRate]).slice(-historyLength);
            txHistory = txHistory.concat([txRate]).slice(-historyLength);
        }
        now.iface = iface;
        last = now;
    }

    function start() {
        if (!needed)
            return;
        routeProc.running = true;
        refreshExternal(false);
    }

    onNeededChanged: start()
    // Синглтон создаётся при первом обращении — обычно уже при открытой панели.
    Component.onCompleted: start()

    Timer {
        interval: 1000
        repeat: true
        running: root.needed
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    // Маршруты и адреса меняются редко (переподключение, VPN) — раз в 10 секунд.
    Timer {
        interval: 10000
        repeat: true
        running: root.needed
        onTriggered: routeProc.running = true
    }

    Process {
        id: routeProc

        command: ["sh", "-c", "ip -j route show default; echo; ip -j -4 addr show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\n").filter(l => l.trim() !== "");
                let routes = [];
                let addrs = [];
                try {
                    routes = JSON.parse(parts[0] || "[]");
                    addrs = JSON.parse(parts[1] || "[]");
                } catch (e) {
                    console.warn("net: не удалось разобрать вывод ip:", e.message);
                    return;
                }
                const ipOf = name => {
                    const a = addrs.find(i => i.ifname === name)?.addr_info?.[0];
                    return a ? a.local : "";
                };
                const byMetric = (a, b) => (a.metric ?? 0) - (b.metric ?? 0);
                const physical = routes.filter(r => r.gateway).sort(byMetric)[0];
                const vpn = routes.filter(r => !r.gateway && r.dev).sort(byMetric)[0];
                if ((physical?.dev ?? "") !== root.iface) {
                    root.last = null;
                    root.rxHistory = [];
                    root.txHistory = [];
                }
                root.iface = physical?.dev ?? "";
                root.gateway = physical?.gateway ?? "";
                root.localIp = physical?.prefsrc || ipOf(root.iface);
                root.vpnIface = vpn?.dev ?? "";
                root.vpnIp = vpn ? ipOf(vpn.dev) : "";
            }
        }
    }

    Process {
        id: externalProc

        command: ["curl", "-fsS", "--max-time", "6", "https://ipinfo.io/json"]
        stdout: StdioCollector {
            id: externalOut
        }
        onExited: code => {
            try {
                if (code !== 0)
                    throw new Error("curl " + code);
                const info = JSON.parse(externalOut.text);
                root.externalIp = info.ip ?? "";
                root.externalPlace = [info.city, info.country].filter(s => s).join(", ");
                // «AS13335 Cloudflare, Inc.» → «Cloudflare, Inc.»
                root.externalOrg = (info.org ?? "").replace(/^AS\d+\s+/, "");
                root.externalState = root.externalIp !== "" ? "ok" : "error";
                root.externalAt = Date.now();
            } catch (e) {
                root.externalState = "error";
            }
        }
    }

    FileView {
        id: devFile

        path: "/proc/net/dev"
        blockLoading: true
        printErrors: false
    }
}
