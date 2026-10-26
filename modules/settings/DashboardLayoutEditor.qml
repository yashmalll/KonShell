import QtQuick
import qs.config

// Карточки панели под часами по колонкам: какие, где и в каком порядке.
// Изменения видны при следующем открытии панели (клик по часам).
LayoutEditor {
    target: Settings.dashboard
    zones: [
        { key: "left", name: "Первая колонка" },
        { key: "middle", name: "Вторая колонка" },
        { key: "right", name: "Третья колонка" },
        { key: "extra", name: "Четвёртая колонка" }
    ]
    catalog: [
        { id: "clock", name: "Время и дата", icon: "preferences-system-time-symbolic", hint: "Крупное время и дата" },
        { id: "weather", name: "Погода", icon: "weather-few-clouds-symbolic", hint: "Сейчас и на 5 дней — город в «Погода» выше" },
        { id: "calendar", name: "Календарь", icon: "x-office-calendar-symbolic", hint: "Месяц, листается колесом" },
        { id: "system", name: "Система", icon: "power-profile-performance-symbolic", hint: "Процессор, память, температура, диски" },
        { id: "media", name: "Плеер", icon: "audio-x-generic-symbolic", hint: "Что играет, перемотка" },
        { id: "notes", name: "Быстрая заметка", icon: "accessories-text-editor-symbolic", hint: "Новая .md-заметка и последние" },
        { id: "network", name: "Сеть", icon: "network-wireless-symbolic", hint: "Скорость, пакеты, IP" }
    ]
    defaults: ({
        left: ["clock", "calendar"],
        middle: ["weather", "system"],
        right: ["media", "notes"],
        extra: ["network"]
    })
    emptyText: "Пусто — колонка не показывается"
}
