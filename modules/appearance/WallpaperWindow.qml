import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Окно с обоями на фоновом слое одного монитора. Новая картинка загружается
// во второй Image и проявляется поверх старой, без мигания.
PanelWindow {
    id: window

    required property string layerNamespace
    // Доля разрешения экрана, в которой декодируется картинка. Слою для обзора
    // хватает половины: там обои видны уменьшенными, а пикселей вчетверо меньше.
    property real resolution: 1

    WlrLayershell.namespace: layerNamespace
    WlrLayershell.layer: WlrLayer.Background
    exclusionMode: ExclusionMode.Ignore
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    // Виден, пока картинка грузится, если обоев нет, и полями в режимах fit/center.
    color: Settings.wallpaper.fillColor || Theme.color.background

    Item {
        id: frame

        readonly property string source: Wallpaper.path
            ? `file://${Wallpaper.path}?${Wallpaper.revision}` : ""
        readonly property int fillMode: Settings.wallpaper.fillMode === "fit" ? Image.PreserveAspectFit
            : Settings.wallpaper.fillMode === "center" ? Image.Pad
            : Image.PreserveAspectCrop

        // Какой из двух слоёв сейчас показан.
        property Image shown: null

        function load() {
            if (source === "") {
                shown = null;
                return;
            }
            if (shown && shown.source.toString() === source)
                return;
            const target = shown === first ? second : first;
            // Тот же адрес Qt не перезагружает и Ready повторно не сообщает:
            // если картинка уже загружена в скрытый слой, просто показываем её.
            if (target.source.toString() === source && target.status === Image.Ready)
                reveal(target);
            else
                target.source = source;
        }

        function reveal(image) {
            if (image.source.toString() !== source || shown === image)
                return;
            const previous = shown;
            shown = image;
            image.z = 1;
            if (previous)
                previous.z = 0;
        }

        anchors.fill: parent
        onSourceChanged: load()
        Component.onCompleted: load()

        WallpaperImage {
            id: first
        }

        WallpaperImage {
            id: second
        }
    }

    component WallpaperImage: Image {
        id: image

        anchors.fill: parent
        fillMode: frame.fillMode
        // Декодируем под размер экрана, а не в исходном разрешении картинки.
        sourceSize: Qt.size(window.width * window.devicePixelRatio * window.resolution,
            window.height * window.devicePixelRatio * window.resolution)
        asynchronous: true
        cache: false
        smooth: true
        opacity: frame.shown === image ? 1 : 0

        onStatusChanged: {
            if (status === Image.Ready)
                frame.reveal(image);
            else if (status === Image.Error)
                console.warn("wallpaper: не удалось загрузить", source);
        }

        Behavior on opacity {
            NumberAnimation {
                // wallpaper.transitionDuration; «меньше движения» отключает переход.
                duration: Theme.reduceMotion ? 0 : Settings.wallpaper.transitionDuration
                easing.type: Easing.InOutQuad
            }
        }

        // Скрытый слой освобождаем после перехода, чтобы не держать в памяти две картинки.
        onOpacityChanged: {
            if (opacity === 0 && frame.shown !== image)
                source = "";
        }
    }
}
