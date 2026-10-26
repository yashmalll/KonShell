import QtQuick
import QtQuick.Effects
import QtQuick.Window
import Quickshell
import qs.config

// Монохромная (symbolic) иконка из темы в цвете темы. Иконка служит
// маской для сплошной заливки, поэтому годится любой цвет, в том числе тёмный.
//
// Чёткость при дробном масштабе экрана (1,25):
//  - маска и заливка рендерятся ровно в физических пикселях (16 → 20), пиксель
//    текстуры ложится в пиксель экрана;
//  - содержимое сдвигается на доли пикселя так, чтобы левый верхний угол попал
//    на сетку экрана. Иначе при раскладке по центру иконка оказывается, например,
//    на y = 2,5 физического пикселя и каждая линия размазывается на два ряда.
//    Текст Qt выравнивает сам, картинки — нет.
//  - порог маски даёт плавный переход прозрачности: полупрозрачные края SVG —
//    сглаживание, его нельзя срезать.
Item {
    id: root

    required property string name
    property color color: Theme.color.text
    property real implicitSize: 16

    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    // Сторона текстур в физических пикселях.
    // От implicitSize, а не только от ширины: при создании ширина ещё 0, маска
    // заказывалась бы 1×1, и после смены размера слой маски мог остаться пустым
    // (первые значки в окне настроек не рисовались).
    readonly property int texture: Math.max(1, Math.round(Math.max(implicitSize, width, height) * dpr))

    // Поправка до сетки физических пикселей (в логических пикселях).
    property real snapX: 0
    property real snapY: 0

    function snap() {
        if (!visible || !Window.window)
            return;
        const p = mapToItem(null, 0, 0);
        snapX = (Math.round(p.x * dpr) - p.x * dpr) / dpr;
        snapY = (Math.round(p.y * dpr) - p.y * dpr) / dpr;
    }

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    // Пересчёт — только когда иконка или её предки сдвинулись (без таймеров:
    // иконок много, периодическая проверка будила бы оболочку в простое).
    // Предки — строка, виджет, зона панели — двигаются без сигналов у самой
    // иконки, поэтому подписка идёт на x/y нескольких уровней вверх.
    readonly property int watchedAncestors: 6
    property var watched: []

    function requestSnap() {
        Qt.callLater(snap);
    }

    function watchAncestors() {
        unwatchAncestors();
        const list = [];
        let item = parent;
        for (let i = 0; item && i < watchedAncestors; i++, item = item.parent) {
            item.xChanged.connect(requestSnap);
            item.yChanged.connect(requestSnap);
            list.push(item);
        }
        watched = list;
    }

    function unwatchAncestors() {
        for (const item of watched) {
            try {
                item.xChanged.disconnect(requestSnap);
                item.yChanged.disconnect(requestSnap);
            } catch (e) {
                // Предок уже удалён вместе с соединениями.
            }
        }
        watched = [];
    }

    onXChanged: requestSnap()
    onYChanged: requestSnap()
    onWidthChanged: requestSnap()
    onHeightChanged: requestSnap()
    onVisibleChanged: requestSnap()
    onParentChanged: watchAncestors()
    Component.onCompleted: {
        watchAncestors();
        requestSnap();
    }
    Component.onDestruction: unwatchAncestors()

    Item {
        id: content

        x: root.snapX
        y: root.snapY
        width: root.width
        height: root.height

        Image {
            id: icon

            anchors.fill: parent
            source: root.name !== "" ? Quickshell.iconPath(root.name, true) : ""
            sourceSize.width: root.texture
            sourceSize.height: root.texture
            fillMode: Image.PreserveAspectFit
            smooth: true
            // Синхронно: маленькая SVG растрируется за доли миллисекунды, а асинхронная
            // загрузка через поставщик значков иногда застревала в Loading — значок не появлялся.
            asynchronous: false
            visible: false
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(root.texture, root.texture)
        }

        Rectangle {
            id: fill

            anchors.fill: parent
            color: root.color
            visible: false
            layer.enabled: true
            layer.textureSize: Qt.size(root.texture, root.texture)
        }

        // Пока иконка не загружена (или её нет в теме), маска пустая и залила бы
        // весь квадрат цветом — поэтому эффект показывается только для готовой иконки.
        MultiEffect {
            id: effect

            anchors.fill: parent
            visible: icon.status === Image.Ready
            source: fill
            maskEnabled: true
            maskSource: icon
            // Альфа маски переходит в альфу результата плавно, от 0 до 1: Qt считает
            // нижний порог как [min·(1+spread) − spread, min·(1+spread)], то есть (0, 1).
            // (min 0 дал бы (−1, 0) — непрозрачный квадрат.)
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
}
