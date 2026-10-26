import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.widgets

// Плеер MPRIS: обложка, трек, прогресс с перемоткой, управление.
// Несколько плееров — переключатели сверху; по умолчанию играющий.
Rectangle {
    id: root

    // media.blacklist: плееры (имя или desktop-файл), которые не показывать.
    readonly property var players: Mpris.players.values.filter(p => !Settings.media.blacklist.some(name => {
        const n = name.trim().toLowerCase();
        return n !== "" && (p.identity.toLowerCase() === n || (p.desktopEntry || "").toLowerCase() === n);
    }))
    // Выбранный вручную плеер, пока он есть; иначе играющий, иначе первый.
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: players.includes(chosen) ? chosen
        : players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property real length: player?.lengthSupported ? player.length : 0
    property real position: 0

    function time(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        const sec = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
    }

    implicitHeight: content.implicitHeight + Theme.spacing.md * 2
    radius: Theme.radius.panel
    color: Theme.color.surface

    // MPRIS не присылает позицию сама — опрашиваем, пока играет и видно.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: {
            if (root.player?.positionSupported)
                root.position = root.player.position;
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true

        function onPositionChanged() {
            root.position = root.player.position;
        }
        function onTrackTitleChanged() {
            root.position = root.player.position ?? 0;
        }
    }

    onPlayerChanged: position = player?.positionSupported ? player.position : 0

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacing.md
        spacing: Theme.spacing.md

        // Пусто.
        Row {
            spacing: Theme.spacing.sm
            visible: root.player === null

            SymbolIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "audio-x-generic-symbolic"
                color: Theme.color.textMuted
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Ничего не играет"
                color: Theme.color.textMuted
            }
        }

        // Плееры, если их несколько.
        Flow {
            width: parent.width
            spacing: Theme.spacing.xs
            visible: root.players.length > 1

            Repeater {
                model: root.players

                Chip {
                    required property MprisPlayer modelData

                    text: modelData.identity
                    checked: modelData === root.player
                    onClicked: root.chosen = modelData
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacing.md
            visible: root.player !== null

            Rectangle {
                id: art

                width: 72
                height: 72
                radius: Theme.radius.control
                color: Theme.color.surfaceVariant
                clip: true

                Image {
                    id: artImage

                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 144
                    sourceSize.height: 144
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.normal }
                    }
                }

                SymbolIcon {
                    anchors.centerIn: parent
                    implicitSize: 24
                    name: "audio-x-generic-symbolic"
                    color: Theme.color.textMuted
                    visible: artImage.status !== Image.Ready
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - art.width - parent.spacing
                spacing: Theme.spacing.xxs

                StyledText {
                    width: parent.width
                    text: root.player?.trackTitle || root.player?.identity || ""
                    font.pixelSize: Theme.font.title
                    font.weight: Theme.font.medium
                }

                StyledText {
                    width: parent.width
                    text: [root.player?.trackArtist, root.player?.trackAlbum].filter(s => s).join(" · ")
                        || root.player?.identity || ""
                    color: Theme.color.textMuted
                }

                StyledText {
                    width: parent.width
                    text: root.player?.identity ?? ""
                    color: Theme.color.textDisabled
                    font.pixelSize: Theme.font.caption
                    visible: root.players.length <= 1
                        && !!(root.player?.trackArtist || root.player?.trackAlbum)
                }
            }
        }

        // Прогресс: клик — перемотка, если плеер её умеет.
        Column {
            width: parent.width
            spacing: Theme.spacing.xxs
            visible: root.player !== null && root.length > 0

            Item {
                width: parent.width
                height: 12

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekArea.containsMouse && root.player?.canSeek ? 6 : 4
                    radius: Theme.radius.full
                    color: Theme.color.surfaceVariant

                    Behavior on height {
                        NumberAnimation { duration: Theme.anim.fast }
                    }

                    Rectangle {
                        width: parent.width * Math.min(1, root.position / Math.max(1, root.length))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.color.primary

                        Behavior on width {
                            NumberAnimation { duration: Theme.anim.normal }
                        }
                    }
                }

                MouseArea {
                    id: seekArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        const target = root.length * Math.max(0, Math.min(1, mouse.x / width));
                        root.player.position = target;
                        root.position = target;
                    }
                }
            }

            Item {
                width: parent.width
                height: elapsed.implicitHeight

                StyledText {
                    id: elapsed

                    text: root.time(root.position)
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                    font.features: { "tnum": 1 }
                }

                StyledText {
                    anchors.right: parent.right
                    text: root.time(root.length)
                    color: Theme.color.textMuted
                    font.pixelSize: Theme.font.caption
                    font.features: { "tnum": 1 }
                }
            }
        }

        // Управление.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spacing.md
            visible: root.player !== null

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 36
                implicitHeight: 36
                iconSize: 18
                icon: "media-skip-backward-symbolic"
                enabled: root.player?.canGoPrevious ?? false
                Accessible.name: "Предыдущий трек"
                onClicked: root.player.previous()
            }

            // Главная кнопка — акцентная.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: Theme.radius.full
                color: playArea.pressed ? Qt.darker(Theme.color.primary, 1.15)
                    : playArea.containsMouse ? Qt.lighter(Theme.color.primary, 1.08)
                    : Theme.color.primary
                opacity: root.player?.canTogglePlaying ? 1 : 0.38
                scale: playArea.pressed ? 0.94 : 1

                Behavior on scale {
                    NumberAnimation { duration: Theme.anim.fast; easing.type: Easing.OutBack }
                }

                SymbolIcon {
                    anchors.centerIn: parent
                    implicitSize: 20
                    name: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    color: Theme.color.primaryText
                }

                MouseArea {
                    id: playArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.player?.canTogglePlaying ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player.togglePlaying()
                }
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 36
                implicitHeight: 36
                iconSize: 18
                icon: "media-skip-forward-symbolic"
                enabled: root.player?.canGoNext ?? false
                Accessible.name: "Следующий трек"
                onClicked: root.player.next()
            }
        }
    }
}
