import QtQuick
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

// Часы остаются по центру: активность занимает симметричные боковые слоты.
Item {
    id: root

    readonly property string kind: IslandActivity.kind
    readonly property bool playing: kind === "media"
    readonly property bool recording: kind === "recording"
    readonly property bool active: kind !== "idle"
    readonly property bool activityHovered: leadingHover.hovered || trailingHover.hovered
    readonly property real sideWidth: active
        ? Math.max(leadingRow.implicitWidth, Math.min(150, trailingLabel.implicitWidth)) + 4 : 0

    implicitWidth: time.implicitWidth + (active ? sideWidth * 2 + 24 : 0)
    implicitHeight: Math.max(28, time.implicitHeight)

    Clock {
        id: time
        compact: true
        anchors.centerIn: parent
    }

    Item {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.sideWidth
        height: root.height
        visible: root.active
        HoverHandler { id: leadingHover }

        Row {
            id: leadingRow
            anchors.centerIn: parent
            spacing: 7

            ClippingRectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 7
                color: Theme.alpha(Theme.color.primary, 0.16)
                visible: root.playing
                Image {
                    id: cover
                    anchors.fill: parent
                    source: Media.player?.trackArtUrl ?? ""
                    sourceSize.width: 44
                    sourceSize.height: 44
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }
                SymbolIcon {
                    anchors.centerIn: parent
                    name: "audio-x-generic-symbolic"
                    implicitSize: 14
                    color: Theme.color.primary
                    visible: cover.status !== Image.Ready
                }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                radius: 4
                visible: root.recording
                color: Theme.color.error
            }
            PrivacyIndicator { visible: root.kind === "privacy" }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.kind === "timer" ? Countdown.phaseName : root.kind === "privacy" ? "Доступ" : root.playing ? "Музыка" : root.recording ? "Запись" : "Фокус"
                font.pixelSize: Theme.font.caption
                color: root.playing ? Theme.color.textMuted : Theme.color.error
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.kind === "timer")
                    Ui.openTimer();
                else if (root.kind === "privacy")
                    Ui.openPrivacy();
                else if (root.playing && Media.player?.canTogglePlaying)
                    Media.player.togglePlaying();
                else if (root.recording)
                    ScreenRecorder.stop();
            }
        }
    }

    Item {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.sideWidth
        height: root.height
        visible: root.active
        HoverHandler { id: trailingHover }
        StyledText {
            id: trailingLabel
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width)
            text: root.kind === "timer" ? Countdown.text : root.recording ? ScreenRecorder.format(ScreenRecorder.elapsed) : root.kind === "privacy" ? Privacy.summary : root.playing ? Media.title : FocusMode.summary
            font.pixelSize: Theme.font.caption
            font.features: { "tnum": 1 }
            color: root.recording ? Theme.color.error : Theme.color.textMuted
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.kind === "timer")
                    Ui.openTimer();
                else if (root.recording)
                    ScreenRecorder.stop();
                else if (root.kind === "privacy")
                    Ui.openPrivacy();
                else if (root.playing && Media.player?.canTogglePlaying)
                    Media.player.togglePlaying();
            }
        }
    }
}
