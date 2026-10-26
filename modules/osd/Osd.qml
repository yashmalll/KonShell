import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Индикатор громкости, микрофона и яркости внизу активного монитора.
// Громкость показывается при любом изменении, в том числе из других программ.
// Горячие клавиши niri вызывают IPC:
//   qs -c konshell ipc call audio increase
//   qs -c konshell ipc call brightness increase
Scope {
    id: root

    property string kind: "volume"
    property bool shown: false

    // PipeWire присылает начальные значения после запуска: их не показываем.
    property bool armed: false

    // osd.enabled и osd.show* — какие изменения показывать.
    function wanted(kind) {
        if (!Settings.osd.enabled)
            return false;
        return kind === "volume" ? Settings.osd.showVolume
            : kind === "mic" ? Settings.osd.showMicrophone
            : kind === "brightness" ? Settings.osd.showBrightness
            : true;
    }

    function show(newKind) {
        if (!armed || !wanted(newKind))
            return;
        kind = newKind;
        shown = true;
        hideTimer.restart();
    }

    IpcHandler {
        target: "audio"

        function increase(): void {
            Audio.increaseVolume();
        }
        function decrease(): void {
            Audio.decreaseVolume();
        }
        function toggleMute(): void {
            Audio.toggleMute();
        }
        function toggleMicMute(): void {
            Audio.toggleMicMute();
        }
    }

    IpcHandler {
        target: "brightness"

        function increase(): void {
            Brightness.increase();
        }
        function decrease(): void {
            Brightness.decrease();
        }
    }

    Connections {
        target: Audio

        function onVolumeChanged() {
            root.show("volume");
        }
        function onMutedChanged() {
            root.show("volume");
        }
        function onMicMutedChanged() {
            root.show("mic");
        }
        // Смена устройства по умолчанию тоже меняет громкость, но это не действие пользователя.
        function onSinkChanged() {
            root.armed = false;
            armTimer.restart();
        }
    }

    Connections {
        target: Brightness

        function onAdjusted() {
            root.show("brightness");
        }
    }

    Timer {
        id: armTimer

        interval: 1000
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer

        interval: Settings.osd.timeout
        onTriggered: root.shown = false
    }

    PopupLoader {
        id: popup

        open: root.shown

        PanelWindow {

            // Скрытое окно (PopupLoader.keepLoaded) не показывается, но и не удаляется.

            visible: popup.windowVisible

            id: osd

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-osd"
            // Размытие только под панелью, а не под всем прозрачным окном.
            BackgroundEffect.blurRegion: Region {
                item: box.blurItem
                radius: box.height / 2
            }

            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            // osd.position: bottom | top | center; без вертикальных якорей окно встаёт по центру.
            readonly property string position: Settings.osd.position
            anchors.bottom: position === "bottom"
            anchors.top: position === "top"
            margins.bottom: Settings.osd.bottomMargin
            margins.top: Settings.osd.bottomMargin
            implicitWidth: 260
            implicitHeight: 44
            color: "transparent"
            // Индикатор не перехватывает клики.
            mask: Region {}

            readonly property real value: root.kind === "brightness" ? Brightness.percent
                : root.kind === "mic" ? (Audio.micMuted ? 0 : 1)
                : Audio.muted ? 0 : Audio.volume

            readonly property string icon: root.kind === "brightness" ? "display-brightness-symbolic"
                : root.kind === "mic" ? Audio.micIcon
                : Audio.icon

            readonly property string label: root.kind === "mic"
                ? (Audio.micMuted ? "выкл" : "вкл")
                : `${Math.round(value * 100)}%`

            // Индикатор — капсула: появляется снизу, со своей стороны экрана.
            PopupSurface {
                id: box

                shown: popup.open

                anchors.fill: parent
                radius: Theme.radius.full
                elevated: false
                enterFrom: osd.position === "top" ? -1 : 1

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacing.md + Theme.spacing.xs
                    anchors.rightMargin: Theme.spacing.md + Theme.spacing.xs
                    spacing: Theme.spacing.md

                    SymbolIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 20
                        name: osd.icon
                    }

                    // Полоса прогресса; громкость выше 100% заполняет её целиком.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20 - percentText.width - parent.spacing * 2
                        height: 4
                        radius: Theme.radius.full
                        color: Theme.color.surfaceVariant

                        Rectangle {
                            width: parent.width * Math.min(1, osd.value)
                            height: parent.height
                            radius: parent.radius
                            color: Theme.color.primary

                            Behavior on width {
                                NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    StyledText {
                        id: percentText

                        anchors.verticalCenter: parent.verticalCenter
                        width: 40
                        horizontalAlignment: Text.AlignRight
                        text: osd.label
                        font.pixelSize: Theme.font.caption
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
