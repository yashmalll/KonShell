import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.widgets

// Текущий плеер MPRIS: обложка, трек и управление.
// Берётся играющий плеер, иначе первый из доступных.
Rectangle {
    id: root

    // media.blacklist: плееры (имя или desktop-файл), которые не показывать.
    readonly property var players: Mpris.players.values.filter(p => !Settings.media.blacklist.some(name => {
        const n = name.trim().toLowerCase();
        return n !== "" && (p.identity.toLowerCase() === n || (p.desktopEntry || "").toLowerCase() === n);
    }))
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

    visible: player !== null
    implicitHeight: 72
    radius: Theme.radius.control
    color: Theme.color.surface

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacing.sm
        spacing: Theme.spacing.md

        Rectangle {
            width: parent.height
            height: parent.height
            radius: Theme.radius.control
            color: Theme.color.surfaceVariant
            clip: true

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 112
                sourceSize.height: 112
                visible: status === Image.Ready
            }

            SymbolIcon {
                anchors.centerIn: parent
                implicitSize: 24
                name: "audio-x-generic-symbolic"
                color: Theme.color.textMuted
                visible: !root.player?.trackArtUrl
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - parent.height - controls.width - parent.spacing * 2

            StyledText {
                width: parent.width
                text: root.player?.trackTitle || root.player?.identity || ""
                font.weight: Font.Medium
            }

            StyledText {
                width: parent.width
                text: root.player?.trackArtist || root.player?.identity || ""
                color: Theme.color.textMuted
                font.pixelSize: Theme.font.caption
            }
        }

        Row {
            id: controls

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacing.xxs

            IconButton {
                icon: "media-skip-backward-symbolic"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }

            IconButton {
                icon: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player.togglePlaying()
            }

            IconButton {
                icon: "media-skip-forward-symbolic"
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
        }
    }
}
