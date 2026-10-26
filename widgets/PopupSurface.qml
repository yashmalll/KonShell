import QtQuick
import QtQuick.Effects
import qs.config

// Плавающая панель: лаунчер, центр управления, уведомления, меню, OSD.
// Тень есть только у плавающих поверхностей — это признак высоты, а не украшение.
// Закрытие с анимацией — вместе с widgets/PopupLoader.qml (shown: popup.open).
//
// Появление — разворачиванием от края входа: видимая часть (blurItem) растёт
// по высоте, содержимое проявляется. Не сдвигом и не прозрачностью фона:
// размытие под панелью рисует niri по геометрии blurItem, сдвиг (Translate)
// и прозрачность оно не видит — пустое размытое пятно появлялось бы раньше
// панели. Окно передаёт размытию именно blurItem:
//   BackgroundEffect.blurRegion: Region { item: panel.blurItem; radius: panel.radius }
Item {
    id: root

    // Откуда появляется: -1 — сверху (панели выпадают из бара), 1 — снизу (OSD, меню над доком).
    property int enterFrom: -1
    // Тень только если окну хватает полей под неё; иначе её обрежет край окна.
    property bool elevated: true
    property real radius: Theme.radius.panel
    property color color: Theme.color.panel

    // Видимая сейчас часть панели — для BackgroundEffect.blurRegion окна.
    readonly property Item blurItem: shape

    default property alias contentData: content.data

    // false — свернуться обратно к краю (закрытие через PopupLoader).
    property bool shown: true

    // 0 — свёрнута, 1 — раскрыта.
    property bool started: false
    property real progress: started && shown ? 1 : 0

    // Анимация начинается не при создании, а когда окно уже на экране: пока оно
    // строит содержимое и niri его показывает, проходит заметная часть длительности,
    // и с экрана видны только последние кадры — движение рваное. Новое окно ждёт
    // 5 кадров (догружаются значки, обложки, списки), уже готовое скрытое окно
    // (PopupLoader.keepLoaded) — 3. Замер: все кадры анимации 15–17 мс.
    property bool warm: false
    FrameAnimation {
        running: !root.started && root.shown
        onTriggered: {
            if (currentFrame >= (root.warm ? 3 : 5))
                root.started = true;
        }
    }

    // Запасной путь, если кадры не идут (окно не видно и т. п.).
    Timer {
        interval: 300
        running: !root.started && root.shown
        onTriggered: root.started = true
    }

    // Свернулась до конца — следующее открытие снова дождётся кадров окна
    // (скрытое окно PopupLoader показывает заново).
    onProgressChanged: {
        if (progress === 0 && !shown && started) {
            started = false;
            warm = true;
        }
    }

    // Раскрытие — длиннее, с долгим мягким замедлением (OutQuint);
    // сворачивание — короче и с ускорением к краю.
    Behavior on progress {
        NumberAnimation {
            duration: Theme.reduceMotion ? 0 : root.shown ? Theme.anim.slow + 20 : Theme.anim.normal
            easing.type: root.shown ? Easing.OutQuint : Easing.InCubic
        }
    }

    // Видимая часть: прижата к краю входа, высота растёт вместе с progress.
    // Панель внутри не сжимается, а открывается, как из-под шторки.
    Item {
        id: shape

        x: 0
        width: root.width
        height: Math.round(root.height * root.progress)
        y: root.enterFrom > 0 ? root.height - height : 0
        clip: true

        // Тень под полупрозрачной панелью просвечивала бы неровным пятном,
        // поэтому при прозрачности глубину передают размытие и рамка.
        layer.enabled: root.elevated && Theme.shadows && !Theme.translucent
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.color.shadow
            shadowBlur: 0.8
            shadowVerticalOffset: 4
            // Тень должна поместиться в отрисовку слоя.
            autoPaddingEnabled: true
        }

        // Фон и содержимое — полного размера, на своём месте относительно root.
        Rectangle {
            id: background

            y: -shape.y
            width: root.width
            height: root.height
            radius: root.radius
            color: root.color
            border.width: Theme.borders ? 1 : 0
            border.color: Theme.color.border
        }

        Item {
            id: content

            y: -shape.y
            width: root.width
            height: root.height
            // Содержимое проявляется чуть позже фона: сначала форма, потом текст.
            // Не ниже 1 %: при нулевой прозрачности Qt содержимое не рисует вовсе и
            // создаёт тексты, иконки и эффекты в первый видимый кадр — посреди
            // анимации, провал 40–70 мс. С 1 % всё готовится в кадрах ожидания до старта.
            opacity: Math.max(0.01, (root.progress - 0.35) / 0.65)
        }
    }
}
