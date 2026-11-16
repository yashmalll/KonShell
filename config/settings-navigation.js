.pragma library

// Presentation only: existing section ids and saved settings remain compatible.
var groups = [
    { id: "look", name: "Оформление", icon: "preferences-color-symbolic", sections: ["appearance", "wallpaper", "interface", "apps"] },
    { id: "island", name: "Островок и виджеты", icon: "view-grid-symbolic", sections: ["bar", "clock", "notifications", "profiles", "osd", "media"] },
    { id: "desktop", name: "Рабочий стол", icon: "video-display-symbolic", sections: ["dock", "sidebar", "launcher", "keyboard"] },
    { id: "tools", name: "Инструменты", icon: "accessories-text-editor-symbolic", sections: ["notes", "clipboard", "recorder", "timer"] },
    { id: "security", name: "Безопасность и фокус", icon: "system-lock-screen-symbolic", sections: ["lock", "privacy", "focus"] },
    { id: "devices", name: "Устройства и питание", icon: "audio-volume-high-symbolic", sections: ["sound", "power"] }
];

var labels = {
    bar: "Поведение", clock: "Виджеты", apps: "Цвета приложений", launcher: "Поиск"
};

var descriptions = {
    bar: "Появление островка, маркер и быстрые действия",
    clock: "Часы, погода и карточки обзора",
    interface: "Размер текста, курсор и оформление элементов",
    launcher: "Внешний вид общего поиска и порядок результатов",
    notifications: "Показ уведомлений и сохранение истории",
    osd: "Индикаторы громкости, микрофона и яркости"
};

var advancedKeys = [
    "theme.pureBlack", "theme.accent", "theme.contrast", "theme.fontFamily",
    "theme.animationSpeed", "theme.animate", "theme.syncColorScheme",
    "wallpaper.fillColor", "wallpaper.transitionDuration", "wallpaper.lightDirectory", "wallpaper.darkDirectory",
    "bar.height", "bar.rightClickDashboard", "bar.islandCollapseDelay", "tray.hidePassive",
    "clock.showWeekNumbers", "weather.refreshMinutes", "dashboard.hiddenDisks", "network.externalIp",
    "notes.openCommand", "notes.datePrefix", "notes.recentCount",
    "dock.magnify", "sidebar.delay", "sidebar.width",
    "launcher.width", "launcher.maxVisible", "launcher.showDescriptions",
    "notifications.showAppName", "notifications.showActions", "notifications.width",
    "notifications.maxPopups", "notifications.blockedApps", "osd.bottomMargin",
    "brightness.minPercent", "lock.gracePeriod", "lock.blur", "lock.tint", "lock.avatarPath", "lock.dateFormat"
];

function canonicalSection(section) {
    if (section === "controlCenter") return "bar";
    return groups.some(group => group.sections.includes(section)) ? section : "appearance";
}

function groupFor(section) {
    const canonical = canonicalSection(section);
    return groups.find(group => group.sections.includes(canonical)) || groups[0];
}

function label(section) {
    return labels[section.id] || section.name;
}

function description(section) {
    return section ? descriptions[section.id] || section.desc : "";
}

function groupLabel(name) {
    return { "Dynamic Island": "Поведение островка", "Панель под часами": "Карточки обзора",
        "Всплывающие": "Всплывающие уведомления" }[name] || name;
}

function isAdvanced(option) {
    return option.type === "action" || advancedKeys.includes(option.key)
        || ["barLayout", "dashboardLayout", "trayItems"].includes(option.component);
}

function isRelevant(option, read) {
    if (option.when) {
        const current = read(option.when[0]);
        if (Array.isArray(option.when[1]) ? !option.when[1].includes(current) : current !== option.when[1])
            return false;
    }
    if (option.key === "controlCenter.width") return false;
    if (["notifications.position", "notifications.width", "notifications.maxPopups"].includes(option.key)
        && read("bar.islandNotifications")) return false;
    if (["osd.position", "osd.bottomMargin"].includes(option.key) && read("bar.islandOsd")) return false;
    if (option.component === "pin" && !read("lock.pinEnabled")) return false;
    return true;
}
