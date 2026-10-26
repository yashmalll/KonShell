pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "fallback-palette.js" as Fallback

// Дизайн-токены оболочки. Цвета читаются из palette.json (его пишет сервис
// ColorScheme по обоям) для режима из настроек и меняются на лету с плавным
// переходом. Пока файла нет или он повреждён, действует резервная палитра.
//
// Имена цветов текста на акцентах — primaryText, errorText и т. п.:
// имена вида onPrimary QML принимает за обработчики сигналов.
Singleton {
    id: root

    readonly property string stateDir:
        (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/konshell"
    readonly property string palettePath: stateDir + "/palette.json"

    readonly property string mode: Settings.theme.mode === "light" ? "light" : "dark"

    // Последний успешно разобранный palette.json. При ошибке разбора остаётся прежний.
    property var palette: null
    readonly property var fallback: Fallback.palette[mode]
    readonly property var tokens: palette?.[mode] ?? fallback

    // Переход цветов включается после первой загрузки: иначе при запуске
    // было бы видно переливание от резервной палитры к сохранённой.
    property bool loaded: false
    readonly property bool pureBlack: Settings.theme.pureBlack && mode === "dark"
    readonly property bool animate: loaded && Settings.theme.animate && !reduceMotion

    // Непрозрачность панелей из настроек, не ниже 0.75: ниже приглушённый текст
    // над светлыми окнами перестаёт проходить контраст 4.5:1 (проверено tools/check-palette.js).
    readonly property real surfaceOpacity: Math.max(0.75, Math.min(1, Settings.theme.opacity))
    readonly property bool translucent: surfaceOpacity < 1

    function token(name) {
        return tokens[name] ?? fallback[name];
    }

    // Цвет токена с другой прозрачностью, например для слоёв поверх акцента.
    function alpha(color, value) {
        return Qt.rgba(color.r, color.g, color.b, value);
    }

    // Вызывается после записи палитры: если при запуске файла не было,
    // слежение за изменениями его появления не заметит.
    function reloadPalette() {
        paletteFile.reload();
    }

    function applyPalette(text) {
        try {
            const parsed = JSON.parse(text);
            if (!parsed.dark || !parsed.light)
                throw new Error("нет разделов dark и light");
            palette = parsed;
        } catch (e) {
            console.warn("theme: не удалось разобрать", palettePath, "-", e.message, "- оставляю текущую палитру");
        }
        Qt.callLater(() => loaded = true);
    }

    readonly property QtObject color: QtObject {
        // Поверхности: фон панели, карточки, приподнятые карточки, всплывающие окна.
        // theme.pureBlack: в тёмной теме фон и всплывающие поверхности — чёрные (для OLED).
        property color background: root.pureBlack ? "#000000" : root.token("background")
        property color surface: root.token("surface")
        property color surfaceVariant: root.token("surfaceVariant")
        property color popup: root.pureBlack ? "#0a0a0a" : root.token("popup")

        property color text: root.token("text")
        property color textMuted: root.token("textMuted")
        property color textDisabled: root.token("textDisabled")

        property color primary: root.token("primary")
        property color primaryText: root.token("primaryText")
        property color primaryContainer: root.token("primaryContainer")
        property color primaryContainerText: root.token("primaryContainerText")
        property color secondary: root.token("secondary")
        property color secondaryText: root.token("secondaryText")
        property color tertiary: root.token("tertiary")
        property color tertiaryText: root.token("tertiaryText")

        // border — тонкие разделители и рамки, outline — заметные границы элементов.
        property color border: root.token("border")
        property color outline: root.token("outline")

        // Состояния. hover, pressed, selection и disabled полупрозрачные:
        // кладутся слоем поверх любого фона.
        property color hover: root.token("hover")
        property color pressed: root.token("pressed")
        property color active: root.token("active")
        property color activeText: root.token("activeText")
        property color focus: root.token("focus")
        property color selection: root.token("selection")
        property color disabled: root.token("disabled")

        property color success: root.token("success")
        property color successText: root.token("successText")
        property color warning: root.token("warning")
        property color warningText: root.token("warningText")
        property color error: root.token("error")
        property color errorText: root.token("errorText")

        property color shadow: root.token("shadow")
        property color scrim: root.token("scrim")

        // Полупрозрачные фоны панели и плавающих панелей; под ними оболочка
        // просит у niri размытие (BackgroundEffect.blurRegion), так текст остаётся читаемым.
        readonly property color bar: root.alpha(background, root.surfaceOpacity)
        readonly property color panel: root.alpha(popup, root.surfaceOpacity)

        Behavior on background { enabled: root.animate; ColorTransition {} }
        Behavior on surface { enabled: root.animate; ColorTransition {} }
        Behavior on surfaceVariant { enabled: root.animate; ColorTransition {} }
        Behavior on popup { enabled: root.animate; ColorTransition {} }
        Behavior on text { enabled: root.animate; ColorTransition {} }
        Behavior on textMuted { enabled: root.animate; ColorTransition {} }
        Behavior on textDisabled { enabled: root.animate; ColorTransition {} }
        Behavior on primary { enabled: root.animate; ColorTransition {} }
        Behavior on primaryText { enabled: root.animate; ColorTransition {} }
        Behavior on primaryContainer { enabled: root.animate; ColorTransition {} }
        Behavior on primaryContainerText { enabled: root.animate; ColorTransition {} }
        Behavior on secondary { enabled: root.animate; ColorTransition {} }
        Behavior on secondaryText { enabled: root.animate; ColorTransition {} }
        Behavior on tertiary { enabled: root.animate; ColorTransition {} }
        Behavior on tertiaryText { enabled: root.animate; ColorTransition {} }
        Behavior on border { enabled: root.animate; ColorTransition {} }
        Behavior on outline { enabled: root.animate; ColorTransition {} }
        Behavior on hover { enabled: root.animate; ColorTransition {} }
        Behavior on pressed { enabled: root.animate; ColorTransition {} }
        Behavior on active { enabled: root.animate; ColorTransition {} }
        Behavior on activeText { enabled: root.animate; ColorTransition {} }
        Behavior on focus { enabled: root.animate; ColorTransition {} }
        Behavior on selection { enabled: root.animate; ColorTransition {} }
        Behavior on disabled { enabled: root.animate; ColorTransition {} }
        Behavior on success { enabled: root.animate; ColorTransition {} }
        Behavior on successText { enabled: root.animate; ColorTransition {} }
        Behavior on warning { enabled: root.animate; ColorTransition {} }
        Behavior on warningText { enabled: root.animate; ColorTransition {} }
        Behavior on error { enabled: root.animate; ColorTransition {} }
        Behavior on errorText { enabled: root.animate; ColorTransition {} }
        Behavior on shadow { enabled: root.animate; ColorTransition {} }
        Behavior on scrim { enabled: root.animate; ColorTransition {} }
    }

    // Шрифт тот же, что у GTK-приложений системы (Adwaita Sans, на основе Inter).
    // Шкала с шагом 1.2 (малая терция) от 13 логических пикселей: при масштабе
    // экрана 1.25 это 16 пикселей. Начертания только Regular и Medium.
    // theme.textScale (0.85–1.3) масштабирует шкалу и отступы; иконки — нет.
    readonly property real textScale: Math.max(0.85, Math.min(1.3, Settings.theme.textScale))
    function scaled(value) {
        return Math.round(value * textScale);
    }

    readonly property QtObject font: QtObject {
        readonly property string family: Settings.theme.fontFamily || "Adwaita Sans"
        readonly property string mono: "Adwaita Mono"
        readonly property int caption: root.scaled(11)   // ms(-1): подписи, время, проценты
        readonly property int body: root.scaled(13)      // ms(0): основной текст
        readonly property int title: root.scaled(16)     // ms(1): заголовки панелей
        readonly property int display: root.scaled(19)   // ms(2): крупные значения (заряд, часы в панели)
        readonly property int regular: Font.Normal
        readonly property int medium: Font.Medium
    }

    // Отступы по сетке 4.
    readonly property QtObject spacing: QtObject {
        readonly property int xxs: root.scaled(2)
        readonly property int xs: root.scaled(4)
        readonly property int sm: root.scaled(8)
        readonly property int md: root.scaled(12)
        readonly property int lg: root.scaled(16)
        readonly property int xl: root.scaled(24)
    }

    // Радиус зависит от уровня: панели как окна niri (geometry-corner-radius 12),
    // элементы внутри панелей меньше, полностью круглые — только индикаторы.
    // theme.cornerScale: 0 — прямые углы, 2 — вдвое круглее.
    readonly property real cornerScale: Math.max(0, Math.min(2, Settings.theme.cornerScale))
    readonly property QtObject radius: QtObject {
        readonly property int control: Math.round(8 * root.cornerScale)
        readonly property int panel: Math.round(12 * root.cornerScale)
        readonly property int full: 999
    }

    // Рамки и тени плавающих панелей (theme.borders, theme.shadows).
    readonly property bool borders: Settings.theme.borders
    readonly property bool shadows: Settings.theme.shadows

    // Длительности по шкале из qt-ui-design: мелкие элементы 120, панели 200,
    // смена палитры 300; theme.animationSpeed ускоряет или замедляет их.
    // При theme.reduceMotion все переходы мгновенные.
    readonly property bool reduceMotion: Settings.theme.reduceMotion
    readonly property real animationFactor: reduceMotion ? 0 : 1 / Math.max(0.25, Math.min(4, Settings.theme.animationSpeed))
    readonly property QtObject anim: QtObject {
        readonly property int fast: Math.round(120 * root.animationFactor)
        readonly property int normal: Math.round(200 * root.animationFactor)
        readonly property int slow: Math.round(300 * root.animationFactor)
        // Вход — с замедлением в конце, выход — с ускорением.
        readonly property int enter: Easing.OutCubic
        readonly property int exit: Easing.InCubic
    }

    component ColorTransition: ColorAnimation {
        duration: root.anim.slow
        easing.type: Easing.InOutQuad
    }

    FileView {
        id: paletteFile

        path: root.palettePath
        watchChanges: true
        printErrors: false
        // Синхронно, чтобы первый кадр уже был в сохранённой палитре.
        blockLoading: true
        onFileChanged: reload()
        onLoaded: root.applyPalette(text())
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                console.warn("theme: не удалось прочитать", root.palettePath, "-", FileViewError.toString(error));
            Qt.callLater(() => root.loaded = true);
        }
    }
}
