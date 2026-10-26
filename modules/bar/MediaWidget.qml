import QtQuick
import qs.config
import qs.services
import qs.widgets

// Виджет панели «media»: что играет. Клик — пауза/воспроизведение, колесо —
// следующий или предыдущий трек, правый клик — панель под часами с плеером.
// Пока плееров нет — скрыт.
Rectangle {
    id: root

    readonly property var player: Media.player

    visible: player !== null
    implicitWidth: visible ? row.implicitWidth + Theme.spacing.sm * 2 : 0
    implicitHeight: Math.max(row.implicitHeight + Theme.spacing.xs * 2, Settings.bar.height - 8)
    radius: Theme.radius.control
    color: area.containsMouse ? Theme.color.hover : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.anim.fast }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.spacing.xs

        SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            color: root.player?.isPlaying ? Theme.color.primary : Theme.color.text
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 220)
            text: Media.artist !== "" ? `${Media.title} — ${Media.artist}` : Media.title
            font.pixelSize: Theme.font.caption
        }
    }

    MouseArea {
        id: area

        property real accumulated: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                if (root.player?.canTogglePlaying)
                    root.player.togglePlaying();
            } else {
                Ui.dashboardOpen = !Ui.dashboardOpen;
            }
        }
        // Трек на щелчок колеса; тачпад копит мелкие события до того же порога.
        onWheel: wheel => {
            accumulated += wheel.angleDelta.y;
            if (Math.abs(accumulated) < 120)
                return;
            if (accumulated < 0 && root.player?.canGoNext)
                root.player.next();
            else if (accumulated > 0 && root.player?.canGoPrevious)
                root.player.previous();
            accumulated = 0;
        }
    }
}
