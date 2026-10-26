.pragma library

// Реестр настроек KonShell: каждый параметр описан один раз, а окно настроек
// и поиск строятся из этого описания (как у Noctalia).
//
// Раздел: id, name, icon, category — категория в боковом меню (categories);
// desc — что в разделе (строка под заголовком).
//
// Поля параметра:
//   section, group      — раздел и группа внутри раздела;
//   key                 — путь в Settings: «группа.поле» (config/Settings.qml);
//   type                — switch | choice | slider | text | color | list | flags | action | custom;
//   title, hint         — название и пояснение;
//   def                 — значение по умолчанию (кнопка сброса показывается, если значение другое);
//   choices             — [[значение, подпись], …] для choice и flags;
//   choicesFrom         — вместо choices: имя списка, который окно настроек строит само
//                         (dynamicChoices в modules/settings/SettingsWindow.qml);
//   min, max, step, unit — для slider; unit: px | percent | factor | seconds | ms;
//   when                — [ключ, значение]: показывать, только если параметр ключа равен значению;
//   action, component   — имя действия или встроенного компонента окна (modules/settings/SettingsWindow.qml);
//   keywords            — дополнительные слова для поиска.

var categories = [
    { id: "look", name: "Внешний вид" },
    { id: "desktop", name: "Рабочий стол" },
    { id: "system", name: "Система" }
];

var sections = [
    { id: "appearance", category: "look", name: "Тема", icon: "preferences-color-symbolic",
      desc: "Тёмный или светлый режим и цвета: из обоев или свой" },
    { id: "interface", category: "look", name: "Интерфейс", icon: "video-display-symbolic",
      desc: "Шрифт, скругления, прозрачность, анимации и курсор" },
    { id: "wallpaper", category: "look", name: "Обои", icon: "preferences-desktop-wallpaper-symbolic",
      desc: "Картинка рабочего стола, режим показа и автосмена" },
    { id: "apps", category: "look", name: "Приложения", icon: "applications-graphics-symbolic",
      desc: "Какие приложения перекрашивать под палитру оболочки" },

    { id: "bar", category: "desktop", name: "Панель", icon: "view-grid-symbolic",
      desc: "Высота панели, виджеты слева, по центру и справа, значки трея" },
    { id: "clock", category: "desktop", name: "Часы и календарь", icon: "x-office-calendar-symbolic",
      desc: "Формат часов, календарь, погода и окно, открывающееся по клику на часы" },
    { id: "notes", category: "desktop", name: "Заметки", icon: "accessories-text-editor-symbolic",
      desc: "Где хранить заметки и чем их открывать" },
    { id: "dock", category: "desktop", name: "Док", icon: "view-app-grid-symbolic",
      desc: "Закреплённые приложения, вид и автоскрытие" },
    { id: "launcher", category: "desktop", name: "Лаунчер", icon: "system-search-symbolic",
      desc: "Окно запуска приложений по Mod+Space: вид и порядок" },
    { id: "clipboard", category: "desktop", name: "Буфер обмена", icon: "edit-paste-symbolic",
      desc: "История скопированного по Mod+Alt+V" },
    { id: "recorder", category: "desktop", name: "Запись экрана", icon: "media-record-symbolic",
      desc: "Запись экрана: звук, кодирование, папка" },
    { id: "notifications", category: "desktop", name: "Уведомления", icon: "preferences-system-notifications-symbolic",
      desc: "Всплывающие уведомления, история и «Не беспокоить»" },
    { id: "osd", category: "desktop", name: "Индикаторы", icon: "display-brightness-symbolic",
      desc: "Индикаторы громкости, микрофона и яркости при нажатии клавиш" },
    { id: "controlCenter", category: "desktop", name: "Центр управления", icon: "sidebar-show-symbolic",
      desc: "Окно быстрых настроек: сеть, звук, переключатели — его ширина" },
    { id: "media", category: "desktop", name: "Музыка", icon: "audio-x-generic-symbolic",
      desc: "Какие плееры не показывать в панели и центре управления" },

    { id: "sound", category: "system", name: "Звук и яркость", icon: "audio-volume-high-symbolic",
      desc: "Шаг и пределы громкости и яркости" },
    { id: "keyboard", category: "system", name: "Клавиатура", icon: "input-keyboard-symbolic",
      desc: "Подписи раскладок клавиатуры на панели" },
    { id: "power", category: "system", name: "Питание", icon: "battery-good-symbolic",
      desc: "Предупреждения о заряде и меню выключения" },
    { id: "lock", category: "system", name: "Блокировка", icon: "system-lock-screen-symbolic",
      desc: "Экран блокировки, PIN и блокировка по простою" }
];

var options = [
    // ---------- Тема ----------
    { section: "appearance", group: "Режим", key: "theme.mode", type: "choice", title: "Режим", def: "dark",
      choices: [["dark", "Тёмный"], ["light", "Светлый"]], keywords: "тёмная светлая ночь день" },
    { section: "appearance", group: "Режим", key: "theme.pureBlack", type: "switch", title: "Чистый чёрный",
      hint: "Чёрный фон в тёмной теме — для OLED-экранов", def: false, keywords: "oled amoled" },

    { section: "appearance", group: "Палитра", key: "theme.source", type: "choice", title: "Источник цветов", def: "wallpaper",
      choices: [["wallpaper", "Из обоев"], ["color", "Свой цвет"]], keywords: "палитра matugen" },
    { section: "appearance", group: "Палитра", key: "theme.seedColor", type: "color", title: "Основной цвет", def: "#6b7fd7",
      hint: "Из него строится палитра", when: ["theme.source", "color"] },
    { section: "appearance", group: "Палитра", key: "theme.scheme", type: "choice", title: "Вариант палитры", def: "tonal-spot",
      choices: [["tonal-spot", "Спокойная"], ["vibrant", "Яркая"], ["expressive", "Выразительная"],
                ["fidelity", "Как на обоях"], ["neutral", "Нейтральная"], ["monochrome", "Монохром"]],
      keywords: "схема matugen material you" },
    { section: "appearance", group: "Палитра", key: "theme.accent", type: "choice", title: "Акцент", def: "wallpaper",
      choices: [["wallpaper", "Точный цвет обоев"], ["material", "Мягкий цвет схемы"]] },
    { section: "appearance", group: "Палитра", key: "theme.contrast", type: "slider", title: "Контраст палитры", def: 0,
      min: -1, max: 1, step: 0.25, unit: "factor" },

    // ---------- Интерфейс ----------
    { section: "interface", group: "Шрифт и размеры", key: "theme.fontFamily", type: "text", title: "Шрифт", def: "Adwaita Sans",
      hint: "Название семейства, как в fc-list", keywords: "font" },
    { section: "interface", group: "Шрифт и размеры", key: "theme.textScale", type: "slider", title: "Размер текста", def: 1,
      hint: "Текст и отступы; иконки не меняются", min: 0.85, max: 1.3, step: 0.05, unit: "percent", keywords: "масштаб шрифт" },
    { section: "interface", group: "Шрифт и размеры", key: "theme.cornerScale", type: "slider", title: "Скругление углов", def: 1,
      min: 0, max: 2, step: 0.25, unit: "factor", keywords: "радиус" },

    { section: "interface", group: "Панели", key: "theme.opacity", type: "slider", title: "Непрозрачность панелей", def: 0.8,
      hint: "Ниже 75 % текст хуже читается над светлыми окнами", min: 0.75, max: 1, step: 0.05, unit: "percent",
      keywords: "прозрачность размытие blur" },
    { section: "interface", group: "Панели", key: "theme.borders", type: "switch", title: "Рамки у панелей", def: true },
    { section: "interface", group: "Панели", key: "theme.shadows", type: "switch", title: "Тени у панелей", def: true,
      hint: "У полупрозрачных панелей тени нет" },

    { section: "interface", group: "Движение", key: "theme.reduceMotion", type: "switch", title: "Без анимаций", def: false,
      hint: "Все переходы мгновенные", keywords: "анимация motion" },
    { section: "interface", group: "Движение", key: "theme.animationSpeed", type: "choice", title: "Скорость анимаций", def: 1,
      choices: [[0.5, "Медленно"], [1, "Обычно"], [1.5, "Быстро"], [2, "Очень быстро"]], when: ["theme.reduceMotion", false] },
    { section: "interface", group: "Движение", key: "theme.animate", type: "switch", title: "Плавная смена цветов", def: true,
      when: ["theme.reduceMotion", false] },

    { section: "interface", group: "Курсор", key: "cursor.manage", type: "switch", title: "Единый курсор", def: true,
      hint: "Одна тема и размер для niri, оболочки и приложений — курсор не меняется при переходе между окнами",
      keywords: "мышь указатель cursor размер" },
    { section: "interface", group: "Курсор", key: "cursor.theme", type: "choice", title: "Тема курсора", def: "Adwaita",
      choicesFrom: "cursorThemes", when: ["cursor.manage", true], keywords: "мышь указатель cursor xcursor" },
    { section: "interface", group: "Курсор", key: "cursor.size", type: "slider", title: "Размер курсора", def: 24,
      hint: "Уже открытые приложения подхватят после перезапуска", min: 16, max: 48, step: 4, unit: "px",
      when: ["cursor.manage", true], keywords: "мышь указатель cursor" },

    // ---------- Обои ----------
    { section: "wallpaper", group: "Выбор", type: "custom", component: "wallpaperGrid", title: "Обои",
      keywords: "картинка фон" },
    { section: "wallpaper", group: "Показ", key: "wallpaper.fillMode", type: "choice", title: "Режим", def: "crop",
      choices: [["crop", "Заполнить"], ["fit", "Вписать"], ["center", "По центру"]] },
    { section: "wallpaper", group: "Показ", key: "wallpaper.fillColor", type: "color", title: "Цвет полей", def: "",
      hint: "Для режимов «Вписать» и «По центру»; пусто — фон темы", when: ["wallpaper.fillMode", ["fit", "center"]] },
    { section: "wallpaper", group: "Показ", key: "wallpaper.transitionDuration", type: "choice", title: "Переход", def: 300,
      choices: [[0, "Мгновенно"], [300, "Быстрый"], [700, "Плавный"], [1500, "Медленный"]] },
    { section: "wallpaper", group: "Папки", key: "wallpaper.directory", type: "text", title: "Папка обоев", def: "",
      hint: "Пусто — ~/Pictures/Wallpapers" },
    { section: "wallpaper", group: "Папки", key: "wallpaper.lightDirectory", type: "text", title: "Папка для светлой темы", def: "",
      hint: "Пусто — общая папка" },
    { section: "wallpaper", group: "Папки", key: "wallpaper.darkDirectory", type: "text", title: "Папка для тёмной темы", def: "",
      hint: "Пусто — общая папка" },
    { section: "wallpaper", group: "Автосмена", key: "wallpaper.rotate", type: "switch", title: "Менять обои автоматически", def: false,
      keywords: "слайдшоу ротация" },
    { section: "wallpaper", group: "Автосмена", key: "wallpaper.rotateMinutes", type: "choice", title: "Раз в", def: 30,
      choices: [[5, "5 мин"], [15, "15 мин"], [30, "30 мин"], [60, "1 ч"], [180, "3 ч"]], when: ["wallpaper.rotate", true] },
    { section: "wallpaper", group: "Автосмена", key: "wallpaper.rotateOrder", type: "choice", title: "Порядок", def: "sequential",
      choices: [["sequential", "По порядку"], ["random", "Случайно"]], when: ["wallpaper.rotate", true] },

    // ---------- Приложения ----------
    { section: "apps", group: "Перекраска", key: "theme.exports", type: "flags", title: "Перекрашивать под палитру",
      def: ["gtk", "qt", "kitty", "niri", "pywalfox", "zed"],
      choices: [["gtk", "GTK"], ["qt", "Qt"], ["kitty", "kitty"], ["niri", "Рамки niri"], ["pywalfox", "Firefox"], ["zed", "Zed"]],
      hint: "Подключение к приложениям — scripts/install-theme-hooks.sh", keywords: "шаблоны templates тема" },
    { section: "apps", group: "Система", key: "theme.syncColorScheme", type: "switch",
      title: "Сообщать системе режим", hint: "Тёмный или светлый режим видят браузеры и сайты", def: true,
      keywords: "gsettings color-scheme" },

    // ---------- Панель ----------
    { section: "bar", group: "Вид", key: "bar.height", type: "slider", title: "Высота панели", def: 32,
      min: 24, max: 48, step: 2, unit: "px" },
    { section: "bar", group: "Виджеты", type: "custom", component: "barLayout", title: "Расположение виджетов",
      keywords: "зоны слева справа центр" },
    { section: "bar", group: "Трей", type: "custom", component: "trayItems", title: "Значки трея",
      keywords: "трей tray значки закрепить скрыть панель" },
    { section: "bar", group: "Трей", key: "tray.hidePassive", type: "switch", title: "Скрывать неактивные значки", def: true,
      hint: "Значки, которые приложение само просит не показывать" },

    // ---------- Часы и календарь ----------
    { section: "clock", group: "Часы в панели", key: "clock.format", type: "choice", title: "Формат", def: "ddd d MMM  HH:mm",
      choices: [["ddd d MMM  HH:mm", "Вс 18 окт  14:30"], ["d MMMM, HH:mm", "18 октября, 14:30"], ["ddd HH:mm", "Вс 14:30"],
                ["HH:mm", "14:30"], ["HH:mm:ss", "14:30:05"]],
      hint: "Клик по часам открывает календарь, плеер и заметки", keywords: "время дата формат" },
    { section: "clock", group: "Календарь", key: "clock.weekStart", type: "choice", title: "Первый день недели", def: 1,
      choices: [[1, "Понедельник"], [7, "Воскресенье"], [6, "Суббота"]] },
    { section: "clock", group: "Календарь", key: "clock.showWeekNumbers", type: "switch", title: "Номера недель", def: false },
    { section: "clock", group: "Погода", key: "weather.enabled", type: "switch", title: "Показывать погоду", def: true,
      hint: "Данные Open-Meteo, без ключа и регистрации", keywords: "погода температура прогноз" },
    { section: "clock", group: "Погода", key: "weather.city", type: "text", title: "Город", def: "",
      hint: "Например: Москва, Saint Petersburg, Berlin", when: ["weather.enabled", true], keywords: "погода место" },
    { section: "clock", group: "Погода", key: "weather.units", type: "choice", title: "Единицы", def: "celsius",
      choices: [["celsius", "°C"], ["fahrenheit", "°F"]], when: ["weather.enabled", true] },
    { section: "clock", group: "Погода", key: "weather.refreshMinutes", type: "choice", title: "Обновлять раз в", def: 30,
      choices: [[15, "15 мин"], [30, "30 мин"], [60, "1 ч"], [180, "3 ч"]], when: ["weather.enabled", true] },
    { section: "clock", group: "Панель под часами", type: "custom", component: "dashboardLayout",
      title: "Карточки и колонки", keywords: "плеер заметка сеть система погода календарь расположение" },
    { section: "clock", group: "Панель под часами", key: "dashboard.hiddenDisks", type: "list", title: "Скрытые разделы",
      def: ["/boot", "/boot/efi", "/efi"], hint: "Точки монтирования через запятую — их нет в карточке «Система»",
      keywords: "диск boot раздел" },
    { section: "clock", group: "Панель под часами", key: "network.externalIp", type: "switch", title: "Узнавать внешний IP",
      def: true, hint: "Запрос к ipinfo.io при открытии панели, не чаще раза в 5 минут",
      keywords: "ip адрес vpn" },

    // ---------- Заметки ----------
    { section: "notes", group: "Файлы", key: "notes.directory", type: "text", title: "Папка заметок", def: "",
      hint: "Пусто — ~/Documents/Notes", keywords: "markdown md" },
    { section: "notes", group: "Файлы", key: "notes.datePrefix", type: "switch", title: "Дата в имени файла", def: true,
      hint: "«2026-10-18 Идея.md»: по имени видно, когда записано" },
    { section: "notes", group: "Файлы", key: "notes.openCommand", type: "text", title: "Открывать в", def: "",
      hint: "Команда редактора, например zeditor; пусто — программа по умолчанию", keywords: "редактор zed" },
    { section: "notes", group: "Панель под часами", key: "notes.recentCount", type: "choice", title: "Последних заметок в списке",
      def: 5, choices: [[0, "Не показывать"], [3, "3"], [5, "5"], [8, "8"]] },
    { section: "notes", group: "Действия", type: "action", action: "newNote", title: "Новая заметка",
      keywords: "записать" },
    { section: "notes", group: "Действия", type: "action", action: "openNotesFolder", title: "Открыть папку заметок" },

    // ---------- Док ----------
    { section: "dock", group: "Общее", key: "dock.enabled", type: "switch", title: "Показывать док", def: true,
      hint: "Закреплённые и запущенные приложения внизу экрана", keywords: "dock панель задач приложения" },
    { section: "dock", group: "Общее", key: "dock.autoHide", type: "switch", title: "Прятать автоматически", def: true,
      hint: "Выезжает, когда мышь у нижнего края; на пустом столе виден всегда. Выключено — окна не заходят под док",
      when: ["dock.enabled", true], keywords: "скрывать autohide" },
    { section: "dock", group: "Общее", key: "dock.showRunning", type: "switch", title: "Запущенные приложения", def: true,
      hint: "Показывать и незакреплённые приложения с открытыми окнами", when: ["dock.enabled", true] },
    { section: "dock", group: "Вид", key: "dock.style", type: "choice", title: "Стиль", def: "attached",
      choices: [["attached", "Прижат к краю"], ["floating", "Плавающий"]],
      hint: "Прижат — плавно переходит в нижний край экрана; плавающий — отдельная панель над краем",
      when: ["dock.enabled", true], keywords: "вид форма закругления углы край" },
    { section: "dock", group: "Вид", key: "dock.iconSize", type: "slider", title: "Размер значков", def: 40,
      min: 28, max: 64, step: 4, unit: "px", when: ["dock.enabled", true] },
    { section: "dock", group: "Вид", key: "dock.magnify", type: "switch", title: "Увеличивать значок под мышью", def: true,
      when: ["dock.enabled", true], keywords: "анимация" },
    { section: "dock", group: "Закреплённые", key: "dock.pinned", type: "list", title: "Закреплённые приложения",
      def: ["firefox", "kitty", "dev.zed.Zed"],
      hint: "Id .desktop-файлов через запятую. Проще — правый клик по значку → «Закрепить»",
      when: ["dock.enabled", true], keywords: "избранное pin" },

    // ---------- Лаунчер ----------
    { section: "launcher", group: "Вид", key: "launcher.width", type: "slider", title: "Ширина", def: 560,
      min: 400, max: 900, step: 20, unit: "px" },
    { section: "launcher", group: "Вид", key: "launcher.maxVisible", type: "choice", title: "Строк в списке", def: 8,
      choices: [[5, "5"], [8, "8"], [10, "10"], [12, "12"]] },
    { section: "launcher", group: "Вид", key: "launcher.showIcons", type: "switch", title: "Иконки приложений", def: true },
    { section: "launcher", group: "Вид", key: "launcher.showDescriptions", type: "switch", title: "Описания", def: true },
    { section: "launcher", group: "Поиск", key: "launcher.sortByUsage", type: "switch", title: "Часто запускаемые выше", def: true,
      hint: "Оболочка считает запуски из лаунчера и дока", keywords: "история частота" },

    // ---------- Буфер обмена ----------
    { section: "clipboard", group: "История", key: "clipboard.enabled", type: "switch", title: "Запоминать скопированное", def: true,
      hint: "Текст и картинки; пароли из менеджеров паролей не сохраняются. Нужны cliphist и wl-clipboard",
      keywords: "буфер обмена история cliphist копировать вставить" },
    { section: "clipboard", group: "История", key: "clipboard.maxItems", type: "choice", title: "Хранить записей", def: 200,
      choices: [[50, "50"], [100, "100"], [200, "200"], [500, "500"]], when: ["clipboard.enabled", true] },
    { section: "clipboard", group: "Действия", type: "action", action: "openClipboard", title: "Открыть историю" },
    { section: "clipboard", group: "Действия", type: "action", action: "wipeClipboard", title: "Очистить историю" },

    // ---------- Запись экрана ----------
    { section: "recorder", group: "Запись", key: "recorder.audio", type: "choice", title: "Звук", def: "system",
      choices: [["none", "Без звука"], ["system", "Звук компьютера"], ["mic", "Микрофон"]],
      keywords: "запись экрана видео wf-recorder скринкаст" },
    { section: "recorder", group: "Запись", key: "recorder.hardware", type: "switch", title: "Кодировать видеокартой", def: true,
      hint: "Почти не нагружает процессор; если не получится — запись пойдёт программно", keywords: "vaapi h264" },
    { section: "recorder", group: "Запись", key: "recorder.directory", type: "text", title: "Папка", def: "",
      hint: "Пусто — «Видео/Записи экрана»" },
    { section: "recorder", group: "Начать", type: "action", action: "recordScreen", title: "Записать экран" },
    { section: "recorder", group: "Начать", type: "action", action: "recordRegion", title: "Записать область" },

    // ---------- Уведомления ----------
    { section: "notifications", group: "Общее", key: "notifications.dnd", type: "switch", title: "Не беспокоить", def: false,
      hint: "Не всплывают, кроме срочных; остаются в истории", keywords: "dnd тишина" },
    { section: "notifications", group: "Общее", key: "notifications.showAppName", type: "switch", title: "Имя приложения", def: true },
    { section: "notifications", group: "Общее", key: "notifications.showActions", type: "switch", title: "Кнопки действий", def: true },
    { section: "notifications", group: "Всплывающие", key: "notifications.position", type: "choice", title: "Положение", def: "top-right",
      choices: [["top-left", "Слева сверху"], ["top-center", "Сверху"], ["top-right", "Справа сверху"],
                ["bottom-left", "Слева снизу"], ["bottom-center", "Снизу"], ["bottom-right", "Справа снизу"]] },
    { section: "notifications", group: "Всплывающие", key: "notifications.width", type: "slider", title: "Ширина", def: 380,
      min: 300, max: 520, step: 20, unit: "px" },
    { section: "notifications", group: "Всплывающие", key: "notifications.timeout", type: "choice", title: "Время показа", def: 5000,
      hint: "Если приложение задало своё — используется оно. Срочные висят до закрытия",
      choices: [[3000, "3 с"], [5000, "5 с"], [8000, "8 с"], [12000, "12 с"]] },
    { section: "notifications", group: "Всплывающие", key: "notifications.maxPopups", type: "choice", title: "Одновременно на экране",
      def: 5, choices: [[1, "1"], [3, "3"], [5, "5"], [8, "8"]] },
    { section: "notifications", group: "История", key: "notifications.historyLimit", type: "choice", title: "Хранить в истории", def: 50,
      choices: [[20, "20"], [50, "50"], [100, "100"], [0, "Без ограничения"]] },
    { section: "notifications", group: "История", key: "notifications.blockedApps", type: "list", title: "Не показывать от приложений",
      def: [], hint: "Имена приложений через запятую; срочные показываются всегда", keywords: "фильтр блокировать" },
    { section: "notifications", group: "Проверка", type: "action", action: "testNotification", title: "Показать пробное уведомление" },
    { section: "notifications", group: "Проверка", type: "action", action: "clearNotifications", title: "Очистить историю" },

    // ---------- Индикаторы ----------
    { section: "osd", group: "Общее", key: "osd.enabled", type: "switch", title: "Показывать индикаторы", def: true,
      hint: "Громкость, микрофон и яркость при изменении", keywords: "osd" },
    { section: "osd", group: "Общее", key: "osd.position", type: "choice", title: "Положение", def: "bottom",
      choices: [["bottom", "Снизу"], ["center", "По центру"], ["top", "Сверху"]], when: ["osd.enabled", true] },
    { section: "osd", group: "Общее", key: "osd.bottomMargin", type: "slider", title: "Отступ от края", def: 80,
      min: 16, max: 240, step: 8, unit: "px", when: ["osd.position", ["bottom", "top"]] },
    { section: "osd", group: "Общее", key: "osd.timeout", type: "choice", title: "Скрывать через", def: 1500,
      choices: [[1000, "1 с"], [1500, "1,5 с"], [2500, "2,5 с"], [4000, "4 с"]], when: ["osd.enabled", true] },
    { section: "osd", group: "События", key: "osd.showVolume", type: "switch", title: "Громкость", def: true, when: ["osd.enabled", true] },
    { section: "osd", group: "События", key: "osd.showMicrophone", type: "switch", title: "Микрофон", def: true, when: ["osd.enabled", true] },
    { section: "osd", group: "События", key: "osd.showBrightness", type: "switch", title: "Яркость", def: true, when: ["osd.enabled", true] },

    // ---------- Центр управления ----------
    { section: "controlCenter", group: "Вид", key: "controlCenter.width", type: "slider", title: "Ширина", def: 400,
      min: 340, max: 520, step: 20, unit: "px", keywords: "быстрые настройки" },

    // ---------- Музыка ----------
    { section: "media", group: "Плееры", key: "media.blacklist", type: "list", title: "Не показывать плееры", def: [],
      hint: "Имена плееров через запятую — в центре управления и под часами", keywords: "mpris" },

    // ---------- Звук и яркость ----------
    { section: "sound", group: "Звук", key: "audio.step", type: "choice", title: "Шаг громкости", def: 0.05,
      choices: [[0.02, "2 %"], [0.05, "5 %"], [0.1, "10 %"]] },
    { section: "sound", group: "Звук", key: "audio.maxVolume", type: "choice", title: "Максимальная громкость", def: 1,
      hint: "Выше 100 % звук может искажаться", choices: [[1, "100 %"], [1.25, "125 %"], [1.5, "150 %"]], keywords: "усиление overdrive" },
    { section: "sound", group: "Яркость", key: "brightness.step", type: "choice", title: "Шаг яркости", def: 5,
      choices: [[2, "2 %"], [5, "5 %"], [10, "10 %"]] },
    { section: "sound", group: "Яркость", key: "brightness.minPercent", type: "choice", title: "Минимальная яркость", def: 1,
      hint: "Чтобы экран не гас полностью", choices: [[1, "1 %"], [5, "5 %"], [10, "10 %"]] },

    // ---------- Клавиатура ----------
    { section: "keyboard", group: "Раскладки", key: "shell.layoutLabels", type: "text", title: "Подписи раскладок", def: "",
      hint: "Например: English (US)=EN; Russian=RU. Пусто — две первые буквы", keywords: "раскладка язык" },

    // ---------- Питание ----------
    { section: "power", group: "Батарея", key: "system.batteryWarning", type: "choice", title: "Предупреждать о низком заряде",
      def: 15, choices: [[0, "Нет"], [10, "10 %"], [15, "15 %"], [20, "20 %"], [30, "30 %"]] },
    { section: "power", group: "Батарея", key: "system.batteryCritical", type: "choice", title: "Срочное предупреждение",
      def: 5, choices: [[0, "Нет"], [3, "3 %"], [5, "5 %"], [10, "10 %"]] },

    { section: "power", group: "Меню выключения", key: "session.confirm", type: "switch", title: "Подтверждать отсчётом",
      def: true, hint: "Выход, перезагрузка и выключение — после обратного отсчёта, который можно отменить",
      keywords: "выключение перезагрузка выход сеанс shutdown reboot logout" },
    { section: "power", group: "Меню выключения", key: "session.countdown", type: "choice", title: "Длительность отсчёта", def: 3,
      choices: [[2, "2 с"], [3, "3 с"], [5, "5 с"], [10, "10 с"]], when: ["session.confirm", true] },
    { section: "power", group: "Меню выключения", type: "action", action: "sessionMenu", title: "Открыть меню выключения" },

    // ---------- Блокировка ----------
    { section: "lock", group: "Когда блокировать", key: "lock.idleTimeout", type: "choice", title: "После простоя", def: 300,
      hint: "Видео во весь экран блокировку не вызывает",
      choices: [[0, "Никогда"], [60, "1 мин"], [120, "2 мин"], [300, "5 мин"], [600, "10 мин"], [900, "15 мин"], [1800, "30 мин"]] },
    { section: "lock", group: "Когда блокировать", key: "lock.gracePeriod", type: "choice", title: "Отсрочка", def: 0,
      hint: "Сразу после блокировки по простою любое действие разблокирует без пароля",
      choices: [[0, "Нет"], [5, "5 с"], [10, "10 с"], [30, "30 с"], [60, "1 мин"]] },
    { section: "lock", group: "Когда блокировать", key: "lock.beforeSleep", type: "switch", title: "Перед сном", def: true,
      hint: "Система уснёт только после блокировки экрана" },
    { section: "lock", group: "Когда блокировать", key: "lock.screenOffTimeout", type: "choice", title: "Гасить экран на заблокированном",
      def: 60, choices: [[0, "Никогда"], [30, "30 с"], [60, "1 мин"], [120, "2 мин"], [300, "5 мин"]] },
    { section: "lock", group: "Вид", key: "lock.blur", type: "slider", title: "Размытие обоев", def: 1,
      min: 0, max: 1, step: 0.1, unit: "percent" },
    { section: "lock", group: "Вид", key: "lock.tint", type: "slider", title: "Затемнение обоев", def: 0.5,
      min: 0, max: 1, step: 0.1, unit: "percent" },
    { section: "lock", group: "Вид", key: "lock.dateFormat", type: "choice", title: "Дата", def: "dddd, d MMMM",
      choices: [["dddd, d MMMM", "Четверг, 16 октября"], ["d MMMM yyyy", "16 октября 2026"], ["dd.MM.yyyy", "16.10.2026"]] },
    { section: "lock", group: "Вид", key: "lock.showBattery", type: "switch", title: "Заряд батареи", def: true },
    { section: "lock", group: "Вид", key: "lock.avatarPath", type: "text", title: "Аватар", def: "",
      hint: "Путь к картинке; пусто — ~/.face" },
    { section: "lock", group: "PIN", type: "custom", component: "pin", title: "PIN", keywords: "пароль код" },
    { section: "lock", group: "Проверка", type: "action", action: "previewLock", title: "Посмотреть экран блокировки" },
    { section: "lock", group: "Проверка", type: "action", action: "lockNow", title: "Заблокировать сейчас" }
];

// Подпись значения ползунка.
function formatValue(option, value) {
    switch (option.unit) {
    case "px":
        return `${Math.round(value)} px`;
    case "percent":
        return `${Math.round(value * 100)} %`;
    case "factor":
        return `×${Number(value).toFixed(2).replace(/0+$/, "").replace(/\.$/, "")}`;
    default:
        return String(value);
    }
}

// Совпадает ли параметр с поисковым запросом (без учёта регистра).
function matches(option, query) {
    const section = sections.find(s => s.id === option.section);
    const text = [option.title, option.hint, option.group, section?.name, option.keywords,
                  (option.choices || []).map(c => c[1]).join(" ")].join(" ").toLowerCase();
    return query.toLowerCase().split(/\s+/).filter(w => w).every(word => text.includes(word));
}
