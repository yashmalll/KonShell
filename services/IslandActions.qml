pragma Singleton
import QtQuick
import Quickshell
import qs.config

Singleton {
    readonly property var quickCatalog: [
        { id: "focus", label: "Фокус", icon: "preferences-system-time-symbolic" },
        { id: "dnd", label: "Не беспокоить", icon: "notifications-disabled-symbolic" },
        { id: "mic", label: "Микрофон", icon: "microphone-sensitivity-high-symbolic" },
        { id: "caffeine", label: "Не засыпать", icon: "preferences-desktop-screensaver-symbolic" },
        { id: "volume", label: "Звук", icon: "audio-volume-high-symbolic" },
        { id: "wifi", label: "Wi-Fi", icon: "network-wireless-symbolic" },
        { id: "bluetooth", label: "Bluetooth", icon: "bluetooth-active-symbolic" },
        { id: "lock", label: "Блокировка", icon: "system-lock-screen-symbolic" }
    ]
    readonly property var pinCatalog: [
        { id: "note", label: "Новая заметка", icon: "document-new-symbolic" },
        { id: "folder", label: "Папка", icon: "folder-symbolic" },
        { id: "screenshot", label: "Скриншот", icon: "camera-photo-symbolic" },
        { id: "timer", label: "Таймер", icon: "preferences-system-time-symbolic" },
        { id: "search", label: "Поиск", icon: "system-search-symbolic" },
        { id: "clipboard", label: "Буфер обмена", icon: "edit-paste-symbolic" },
        { id: "settings", label: "Настройки", icon: "emblem-system-symbolic" }
    ]
    function chosen(ids, catalog) {
        return Array.from(ids).filter((id, i, all) => all.indexOf(id) === i)
            .map(id => catalog.find(item => item.id === id)).filter(Boolean).slice(0, 4);
    }
    readonly property var quick: chosen(Settings.bar.quickActions, quickCatalog)
    readonly property var pins: chosen(Settings.bar.pinnedActions, pinCatalog)
    function selected(id) {
        return ({ focus: FocusMode.active, dnd: Notifications.dnd, mic: Audio.micMuted,
            caffeine: Caffeine.active, volume: Audio.muted, wifi: NetworkState.wifiEnabled, bluetooth: BluetoothState.enabled })[id] ?? false;
    }
    function enabled(id) {
        return id === "mic" ? Audio.source !== null : id === "volume" ? Audio.sink !== null
            : id === "wifi" ? NetworkState.wifiDevice !== null : id === "bluetooth" ? BluetoothState.available : true;
    }
    function run(id) {
        switch (id) {
        case "focus": FocusMode.toggle(); break;
        case "dnd": Notifications.setDnd(!Notifications.dnd); break;
        case "mic": Audio.toggleMicMute(); break;
        case "caffeine": Caffeine.active ? Caffeine.disable() : Caffeine.enable(0); break;
        case "volume": Audio.toggleMute(); break;
        case "wifi": NetworkState.setWifiEnabled(!NetworkState.wifiEnabled); break;
        case "bluetooth": BluetoothState.setEnabled(!BluetoothState.enabled); break;
        case "lock": Lock.lock("manual"); break;
        case "note": Ui.openNote(""); break;
        case "folder": {
            const configured = Settings.bar.pinnedDirectory.trim();
            const home = Quickshell.env("HOME");
            const directory = !configured ? home : configured.startsWith("~/") ? home + configured.slice(1) : configured;
            Quickshell.execDetached(["xdg-open", directory]); break;
        }
        case "screenshot": Ui.islandDismissRequested(); ScreenRecorder.screenshot(500); break;
        case "timer": Ui.openTimer(); break;
        case "search": Ui.searchRequested(); break;
        case "clipboard": Ui.closeIslandPanels(); Ui.clipboardOpen = true; break;
        case "settings": Ui.openSettings("bar"); break;
        }
    }
}
