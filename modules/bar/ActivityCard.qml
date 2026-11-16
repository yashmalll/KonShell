import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.widgets

Rectangle {
    id: root
    readonly property string kind: IslandActivity.kind
    readonly property var player: Media.player
    readonly property string title: kind === "timer" ? Countdown.phaseName
        : kind === "recording" ? (ScreenRecorder.preparing ? "Подготовка записи…" : "Идёт запись экрана")
        : kind === "privacy" ? "Используются устройства" : kind === "media" ? Media.title
        : kind === "focus" ? "Фокусировка" : "Всё спокойно"
    readonly property string subtitle: kind === "timer" ? Countdown.text + (Countdown.running ? "" : Countdown.attention ? "" : " · пауза")
        : kind === "recording" ? ScreenRecorder.format(ScreenRecorder.elapsed)
        : kind === "privacy" ? Privacy.summary : kind === "media" ? Media.artist || player?.identity || ""
        : kind === "focus" ? FocusMode.summary : "Запустите таймер или выберите действие ниже"
    readonly property string icon: kind === "recording" ? "media-record-symbolic"
        : kind === "privacy" ? "microphone-sensitivity-high-symbolic" : kind === "media" ? "audio-x-generic-symbolic"
        : "preferences-system-time-symbolic"
    implicitHeight: 90
    radius: 16
    color: Theme.color.surface

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Rectangle {
            implicitWidth: 48
            implicitHeight: 48
            radius: 12
            color: Theme.alpha(Theme.color.primary, 0.14)
            clip: true
            Image {
                id: cover
                anchors.fill: parent
                source: root.kind === "media" ? root.player?.trackArtUrl ?? "" : ""
                sourceSize: Qt.size(96, 96)
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
            }
            SymbolIcon {
                anchors.centerIn: parent
                implicitSize: 24
                name: root.icon
                visible: cover.status !== Image.Ready
                color: root.kind === "recording" || Countdown.attention ? Theme.color.error : Theme.color.primary
            }
        }
        Column {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 5
            StyledText { width: parent.width; text: root.title; font.weight: Font.Medium }
            StyledText {
                width: parent.width
                text: root.subtitle
                font.pixelSize: Theme.font.caption
                color: root.kind === "timer" ? Theme.color.primary : Theme.color.textMuted
                font.features: { "tnum": 1 }
            }
            Rectangle {
                width: parent.width
                height: 3
                radius: 2
                visible: root.kind === "timer" && !Countdown.attention
                color: Theme.color.surfaceVariant
                Rectangle { width: parent.width * Countdown.progress; height: parent.height; radius: 2; color: Theme.color.primary }
            }
        }
        Row {
            spacing: 2
            visible: root.kind === "media"
            IconButton { icon: "media-skip-backward-symbolic"; enabled: root.player?.canGoPrevious ?? false; Accessible.name: "Предыдущий трек"; onClicked: root.player.previous() }
            IconButton { icon: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"; enabled: root.player?.canTogglePlaying ?? false; Accessible.name: "Пауза / воспроизведение"; onClicked: root.player.togglePlaying() }
            IconButton { icon: "media-skip-forward-symbolic"; enabled: root.player?.canGoNext ?? false; Accessible.name: "Следующий трек"; onClicked: root.player.next() }
        }
        IconButton {
            visible: root.kind === "timer" && !Countdown.attention
            icon: Countdown.running ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            Accessible.name: Countdown.running ? "Приостановить таймер" : "Продолжить таймер"
            onClicked: Countdown.running ? Countdown.pause() : Countdown.resume()
        }
        IconButton {
            visible: root.kind !== "media"
            icon: root.kind === "recording" ? "media-playback-stop-symbolic" : "go-next-symbolic"
            enabled: root.kind !== "recording" || ScreenRecorder.recording
            Accessible.name: root.kind === "recording" ? "Остановить запись" : "Открыть подробности"
            onClicked: {
                if (root.kind === "recording") ScreenRecorder.stop();
                else if (root.kind === "privacy") Ui.openPrivacy();
                else if (root.kind === "focus") Ui.controlCenterOpen = true;
                else Ui.openTimer();
            }
        }
    }
}
