pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Пользовательские настройки в ~/.config/konshell/settings.json.
// Если файла нет, он создаётся со значениями по умолчанию.
Singleton {
    id: root

    readonly property string settingsPath:
        (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
        + "/konshell/settings.json"

    property alias bar: adapter.bar
    property alias clock: adapter.clock
    property alias dashboard: adapter.dashboard
    property alias notes: adapter.notes
    property alias network: adapter.network
    property alias weather: adapter.weather
    property alias clipboard: adapter.clipboard
    property alias recorder: adapter.recorder
    property alias launcher: adapter.launcher
    property alias notifications: adapter.notifications
    property alias audio: adapter.audio
    property alias brightness: adapter.brightness
    property alias osd: adapter.osd
    property alias tray: adapter.tray
    property alias controlCenter: adapter.controlCenter
    property alias theme: adapter.theme
    property alias wallpaper: adapter.wallpaper
    property alias shell: adapter.shell
    property alias system: adapter.system
    property alias session: adapter.session
    property alias media: adapter.media
    property alias lock: adapter.lock
    property alias dock: adapter.dock

    FileView {
        id: file

        path: root.settingsPath
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property JsonObject bar: JsonObject {
                property int height: 32
                // Расположение виджетов по зонам панели, слева направо.
                // Виджеты: workspaces, windowTitle, tray, keyboard, status, notifications, media, network, note, date, weather, sysmon, clock.
                // Не указанный ни в одной зоне виджет скрыт.
                property list<string> left: ["workspaces", "windowTitle"]
                property list<string> center: ["clock"]
                property list<string> right: ["tray", "keyboard", "status", "notifications"]
            }

            property JsonObject clock: JsonObject {
                property string format: "ddd d MMM  HH:mm"
                // Первый день недели в календаре: 1 — понедельник, 7 — воскресенье.
                property int weekStart: 1
                property bool showWeekNumbers: false
            }

            // Панель под часами: календарь, плеер, заметки.
            property JsonObject dashboard: JsonObject {
                // Карточки по колонкам сверху вниз: clock, weather, calendar, system,
                // media, notes, network. Не указанная ни в одной колонке — скрыта.
                // Карточка, указанная в нескольких колонках, показывается в первой из них.
                property list<string> left: ["clock", "calendar"]
                property list<string> middle: ["weather", "system"]
                property list<string> right: ["media", "notes"]
                // Четвёртая колонка — правее «right».
                property list<string> extra: ["network"]
                // Разделы, которых не показывать в карточке «Система» (точки монтирования).
                property list<string> hiddenDisks: ["/boot", "/boot/efi", "/efi"]
            }

            // Запись экрана (wf-recorder, slurp).
            property JsonObject recorder: JsonObject {
                // none | system — звук компьютера | mic — микрофон.
                property string audio: "system"
                // Кодировать видеокартой (VAAPI); если не выйдет — программно.
                property bool hardware: true
                // Пусто: «Видео/Записи экрана».
                property string directory: ""
            }

            // История буфера обмена (cliphist + wl-clipboard).
            property JsonObject clipboard: JsonObject {
                // Запоминать скопированное: оболочка держит наблюдатели wl-paste.
                property bool enabled: true
                // Сколько записей хранить.
                property int maxItems: 200
            }

            // Погода с Open-Meteo (без ключа). Город — название, как в поиске карт.
            property JsonObject weather: JsonObject {
                property bool enabled: true
                property string city: ""
                // celsius | fahrenheit
                property string units: "celsius"
                // Минуты между обновлениями.
                property int refreshMinutes: 30
            }

            property JsonObject network: JsonObject {
                // Узнавать внешний IP (запрос к ipinfo.io при открытии панели под часами,
                // не чаще раза в 5 минут).
                property bool externalIp: true
            }

            property JsonObject notes: JsonObject {
                // Пусто: ~/Documents/Notes.
                property string directory: ""
                // Дата в начале имени файла: «2026-10-18 Идея.md».
                property bool datePrefix: true
                // Сколько последних заметок показывать под полем ввода.
                property int recentCount: 5
                // Чем открывать заметку; пусто — программа по умолчанию (xdg-open).
                property string openCommand: ""
            }

            property JsonObject launcher: JsonObject {
                property int width: 560
                property int maxVisible: 8
                property bool showIcons: true
                property bool showDescriptions: true
                // Часто запускаемые — выше; счётчики в ~/.local/state/konshell/launcher-usage.json.
                property bool sortByUsage: true
            }

            property JsonObject notifications: JsonObject {
                property int width: 380
                // Мс, если приложение не задало свой таймаут.
                property int timeout: 5000
                property int maxPopups: 5
                property bool dnd: false
                // top-right | top-left | top-center | bottom-right | bottom-left | bottom-center
                property string position: "top-right"
                property bool showAppName: true
                property bool showActions: true
                // Сколько уведомлений хранить в истории; 0 — без ограничения.
                property int historyLimit: 50
                // Имена приложений, чьи уведомления не показывать вовсе (без учёта регистра).
                property list<string> blockedApps: []
            }

            property JsonObject audio: JsonObject {
                property real step: 0.05
                property real maxVolume: 1.0
            }

            property JsonObject brightness: JsonObject {
                // Пусто: первое устройство из /sys/class/backlight.
                property string device: ""
                // В процентах.
                property int step: 5
                property int minPercent: 1
            }

            property JsonObject controlCenter: JsonObject {
                property int width: 400
            }

            property JsonObject tray: JsonObject {
                property int iconSize: 18
                property int menuWidth: 260
                // Скрывать значки в статусе Passive (приложение просит их не показывать).
                property bool hidePassive: true
                // Id значков, которые не показывать. nm-applet дублирует индикатор сети,
                // но сам нужен: он запрашивает пароли для VPN и корпоративного Wi-Fi.
                property list<string> hidden: ["nm-applet"]
            }

            property JsonObject osd: JsonObject {
                property int timeout: 1500
                property int bottomMargin: 80
                property bool enabled: true
                // bottom | top | center
                property string position: "bottom"
                property bool showVolume: true
                property bool showMicrophone: true
                property bool showBrightness: true
            }

            property JsonObject theme: JsonObject {
                // dark | light: не зависит от того, светлые обои или тёмные.
                property string mode: "dark"
                // wallpaper: палитра из обоев; color: из seedColor.
                property string source: "wallpaper"
                property string seedColor: "#6b7fd7"
                // Вариант палитры matugen: tonal-spot, vibrant, expressive, neutral,
                // fidelity, content, monochrome, rainbow, fruit-salad.
                property string scheme: "tonal-spot"
                // От -1 (мягче) до 1 (контрастнее); 0 — как в спецификации Material You.
                property real contrast: 0
                // Какой из основных цветов картинки брать за основу: 0 — самый заметный.
                property int sourceColorIndex: 0
                // Плавный переход цветов при смене палитры.
                property bool animate: true
                // Без анимаций во всей оболочке: переходы становятся мгновенными.
                property bool reduceMotion: false
                // wallpaper — акцент точно цвета обоев; material — акцент схемы Material You (мягче).
                property string accent: "wallpaper"
                // Непрозрачность панели и плавающих панелей: 0.75–1. Ниже 0.75 не опускается:
                // приглушённый текст перестал бы проходить контраст WCAG над светлыми окнами.
                property real opacity: 0.8
                // Какие приложения перекрашивать под палитру: gtk, qt, kitty, niri, pywalfox, zed.
                // Строки подключения файлов цветов добавляет scripts/install-theme-hooks.sh.
                property list<string> exports: ["gtk", "qt", "kitty", "niri", "pywalfox", "zed"]
                // Сообщать системе тёмный или светлый режим (gsettings color-scheme).
                property bool syncColorScheme: true
                property string fontFamily: "Adwaita Sans"
                // Множитель размера текста и отступов, 0.85–1.3.
                property real textScale: 1
                // Множитель скругления углов: 0 — прямые углы, 2 — вдвое круглее.
                property real cornerScale: 1
                // Скорость анимаций: 0.5 — вдвое медленнее, 2 — вдвое быстрее.
                property real animationSpeed: 1
                // Чистый чёрный фон в тёмной теме (для OLED).
                property bool pureBlack: false
                property bool borders: true
                property bool shadows: true
            }

            property JsonObject lock: JsonObject {
                // Секунды простоя до блокировки; 0 — не блокировать по простою.
                property int idleTimeout: 300
                // Секунды на заблокированном экране до выключения мониторов; 0 — не выключать.
                property int screenOffTimeout: 60
                // Блокировать перед сном и гибернацией.
                property bool beforeSleep: true
                // Секунды после блокировки по простою, когда разблокирует любое нажатие без пароля.
                property int gracePeriod: 0
                // Размытие обоев (0–1) и затемнение поверх них (0–1) на экране блокировки.
                property real blur: 1
                property real tint: 0.5
                property bool showBattery: true
                // Картинка пользователя; пусто — ~/.face, если есть.
                property string avatarPath: ""
                property string dateFormat: "dddd, d MMMM"
            }

            property JsonObject dock: JsonObject {
                property bool enabled: true
                // Прятать док, пока мышь не подведена к нижнему краю экрана.
                // На пустом рабочем столе он виден всегда.
                property bool autoHide: true
                // attached — прижат к нижнему краю с плавными закруглениями в край экрана;
                // floating — плавающая панель над краем.
                property string style: "attached"
                property int iconSize: 40
                // Закреплённые приложения: id .desktop-файлов (без .desktop), слева направо.
                property list<string> pinned: ["firefox", "kitty", "dev.zed.Zed"]
                // Показывать запущенные приложения, которые не закреплены.
                property bool showRunning: true
                // Увеличивать значок под мышью.
                property bool magnify: true
            }

            property JsonObject shell: JsonObject {
                // Подписи раскладок: «English (US)=EN; Russian=RU». Пусто — две первые буквы.
                property string layoutLabels: ""
            }

            // Меню сеанса: блокировка, сон, выход, перезагрузка, выключение.
            property JsonObject session: JsonObject {
                // Перед выходом, перезагрузкой и выключением — обратный отсчёт с отменой.
                property bool confirm: true
                // Секунды обратного отсчёта.
                property int countdown: 3
            }

            property JsonObject system: JsonObject {
                // Предупреждение о низком заряде, %: обычное и срочное; 0 — не предупреждать.
                property int batteryWarning: 15
                property int batteryCritical: 5
            }

            property JsonObject media: JsonObject {
                // Плееры, которые не показывать в центре управления (имя или desktop-файл).
                property list<string> blacklist: []
            }

            property JsonObject wallpaper: JsonObject {
                // Пусто: первая картинка из папки directory.
                property string path: ""
                // Пусто: ~/Pictures/Wallpapers.
                property string directory: ""
                // crop — заполнить экран с обрезкой, fit — вписать целиком, center — без масштаба.
                property string fillMode: "crop"
                // Цвет полей при режимах fit и center; пусто — фон темы.
                property string fillColor: ""
                // Плавная смена обоев, мс; 0 — мгновенно.
                property int transitionDuration: 300
                // Автосмена обоев из папки.
                property bool rotate: false
                property int rotateMinutes: 30
                // sequential | random
                property string rotateOrder: "sequential"
                // Отдельные папки для светлой и тёмной темы; пусто — общая папка.
                property string lightDirectory: ""
                property string darkDirectory: ""
            }
        }
    }
}
