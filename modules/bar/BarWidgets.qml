pragma Singleton

import QtQuick
import Quickshell

// Каталог виджетов панели: id из настроек bar.left/center/right → название и иконка
// для окна настроек. Сами компоненты создаёт Bar.qml (им нужен монитор панели).
Singleton {
    readonly property var all: [
        { id: "workspaces", name: "Рабочие столы", icon: "view-grid-symbolic", hint: "Мини-карта ленты niri" },
        { id: "windowTitle", name: "Заголовок окна", icon: "focus-windows-symbolic", hint: "Растягивается на свободное место" },
        { id: "tray", name: "Трей", icon: "view-app-grid-symbolic", hint: "Значки приложений" },
        { id: "keyboard", name: "Раскладка", icon: "input-keyboard-symbolic", hint: "EN / RU, клик переключает" },
        { id: "status", name: "Сеть, звук, батарея", icon: "network-wireless-symbolic", hint: "Открывает центр управления" },
        { id: "notifications", name: "Уведомления", icon: "preferences-system-notifications-symbolic", hint: "Колокольчик и счётчик" },
        { id: "media", name: "Плеер", icon: "audio-x-generic-symbolic", hint: "Что играет; клик — пауза, колесо — трек" },
        { id: "network", name: "Сеть", icon: "network-wireless-symbolic", hint: "Скорость приёма и отдачи" },
        { id: "note", name: "Заметка", icon: "accessories-text-editor-symbolic", hint: "Кнопка новой заметки" },
        { id: "date", name: "Дата", icon: "x-office-calendar-symbolic", hint: "Только дата, клик — календарь" },
        { id: "weather", name: "Погода", icon: "weather-few-clouds-symbolic", hint: "Значок и температура, клик — прогноз" },
        { id: "sysmon", name: "Монитор системы", icon: "power-profile-performance-symbolic", hint: "Процессор, память, температура" },
        { id: "clock", name: "Часы", icon: "preferences-system-time-symbolic", hint: "Календарь, плеер и заметки по клику" }
    ]

    function find(id) {
        return all.find(w => w.id === id) ?? null;
    }
}
