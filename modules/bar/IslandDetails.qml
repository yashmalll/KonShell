import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.config
import qs.services
import qs.widgets
import qs.modules.notifications

// Единая поверхность для событий и быстрого управления, без отдельных окон.
Column {
    id: root

    property var notification: null
    property bool levelShown: false
    property string levelKind: "volume"
    property bool glance: false
    readonly property bool hasContent: notification !== null || levelShown || glance
    readonly property real level: levelKind === "brightness" ? Brightness.percent
        : levelKind === "mic" ? (Audio.micMuted ? 0 : Audio.micVolume)
        : Audio.muted ? 0 : Audio.volume
    readonly property string levelIcon: levelKind === "brightness" ? "display-brightness-symbolic"
        : levelKind === "mic" ? Audio.micIcon : Audio.icon
    readonly property real maximum: levelKind === "volume" ? Math.max(0.01, Settings.audio.maxVolume) : 1

    spacing: 10

    Repeater {
        model: ScriptModel { values: root.notification ? [root.notification] : [] }

        NotificationCard {
            id: card
            required property Notification modelData
            notification: modelData
            width: root.width
            color: "transparent"

            Timer {
                interval: Math.max(1, card.modelData.expireTimeout > 0
                    ? card.modelData.expireTimeout * 1000 : Settings.notifications.timeout)
                running: card.modelData.urgency !== NotificationUrgency.Critical && !card.hovered
                onTriggered: {
                    if (card.modelData.transient)
                        card.modelData.expire();
                    else
                        Notifications.hidePopup(card.modelData);
                }
            }
        }
    }

    RowLayout {
        width: root.width
        height: 44
        visible: root.levelShown && !root.notification
        spacing: 12

        SymbolIcon { name: root.levelIcon; implicitSize: 20 }
        Slider {
            Layout.fillWidth: true
            value: root.level / root.maximum
            onMoved: value => {
                if (root.levelKind === "brightness")
                    Brightness.setPercent(value);
                else if (root.levelKind === "mic")
                    Audio.setMicVolume(value);
                else
                    Audio.setVolume(value * root.maximum);
            }
        }
        StyledText {
            Layout.preferredWidth: 44
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(root.level * 100)}%`
            font.features: { "tnum": 1 }
        }
    }

    Column {
        width: root.width
        spacing: 10
        visible: root.glance && !root.notification && !root.levelShown
        Grid {
            id: destinations
            width: parent.width
            columns: 3
            spacing: 8
            IslandDestination { icon: "view-grid-symbolic"; label: "Обзор"; onTriggered: Ui.openDashboard(false) }
            IslandDestination { icon: "preferences-system-symbolic"; label: "Управление"; onTriggered: Ui.controlCenterOpen = true }
            IslandDestination { icon: "preferences-system-notifications-symbolic"; label: Notifications.count ? `Уведомления · ${Notifications.count}` : "Уведомления"; onTriggered: Notifications.centerOpen = true }
        }
        ActivityCard { width: parent.width }
        RowLayout {
            width: parent.width
            spacing: 8
            visible: IslandActions.quick.length > 0
            Repeater {
                model: IslandActions.quick
                QuickAction {
                    required property var modelData
                    icon: modelData.id === "mic" ? Audio.micIcon : modelData.id === "volume" ? Audio.icon : modelData.icon
                    label: modelData.label
                    selected: IslandActions.selected(modelData.id)
                    enabled: IslandActions.enabled(modelData.id)
                    onTriggered: IslandActions.run(modelData.id)
                }
            }
        }
        Loader { width: parent.width; source: "IslandSummary.qml"; height: item?.implicitHeight ?? 0 }
    }

    component QuickAction: Rectangle {
        id: action
        property string icon
        property string label
        property bool selected: false
        signal triggered
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitWidth: 76
        implicitHeight: 58
        radius: 14
        color: selected ? Theme.alpha(Theme.color.primary, 0.18)
            : hover.hovered ? Theme.color.hover : Theme.alpha(Theme.color.text, 0.045)
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Keys.onReturnPressed: triggered()
        Keys.onEnterPressed: triggered()
        Keys.onSpacePressed: triggered()
        Column {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 5
            SymbolIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: action.icon
                color: action.selected ? Theme.color.primary : Theme.color.text
            }
            StyledText {
                width: parent.width
                text: action.label
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.font.caption
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }
        HoverHandler { id: hover }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: action.triggered()
        }
        FocusRing {}
    }
}
