import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Панель на каждом мониторе; Variants сам создаёт и удаляет
// окна при подключении и отключении мониторов.
// Сплошная полоса без капсул из трёх зон: слева, по центру, справа.
// Какие виджеты где — bar.left/center/right в настройках (окно «Настройки» → «Панель»);
// изменения применяются сразу.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        // id виджета → компонент; монитору нужны рабочие столы своего экрана.
        readonly property var widgets: ({
            workspaces: workspacesComponent,
            windowTitle: windowTitleComponent,
            tray: trayComponent,
            keyboard: keyboardComponent,
            status: statusComponent,
            notifications: notificationsComponent,
            sysmon: sysmonComponent,
            weather: weatherComponent,
            media: mediaComponent,
            network: networkComponent,
            note: noteComponent,
            date: dateComponent,
            clock: clockComponent
        })

        function ownerOf(id) {
            return [leftZone, centerZone, rightZone].find(z => z.ids.includes(id)) ?? null;
        }

        screen: modelData
        WlrLayershell.namespace: "konshell-bar"
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Settings.bar.height
        color: Theme.color.bar
        // Размытие под всей полосой панели.
        BackgroundEffect.blurRegion: Region {
            item: blurArea
        }

        Item {
            id: blurArea

            anchors.fill: parent
        }

        // «Не засыпать» (services/Caffeine.qml): пока включено, простоя нет.
        IdleInhibitor {
            window: bar
            enabled: Caffeine.active
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacing.md
            anchors.rightMargin: Theme.spacing.md

            // Зона растягивается, только если в ней заголовок окна: тогда он занимает
            // свободное место до соседней зоны и обрезается, а не наезжает на неё.
            // Остальные зоны шириной по своим виджетам; центральная — ровно по центру экрана.
            Zone {
                id: leftZone

                anchors.left: parent.left
                width: !stretches ? implicitWidth
                    : (centerZone.count > 0 ? centerZone.x : rightZone.x) - Theme.spacing.lg
                ids: Settings.bar.left
            }

            Zone {
                id: centerZone

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width / 3)
                ids: Settings.bar.center
            }

            Zone {
                id: rightZone

                anchors.right: parent.right
                width: !stretches ? implicitWidth
                    : parent.width - (centerZone.count > 0 ? centerZone.x + centerZone.width : leftZone.width) - Theme.spacing.lg
                ids: Settings.bar.right
            }
        }

        component Zone: RowLayout {
            id: zone

            property var ids: []
            readonly property int count: repeater.count
            readonly property bool stretches: ids.includes("windowTitle")

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: Theme.spacing.md

            Repeater {
                id: repeater

                // Виджет показывается один раз: в первой зоне, где он указан.
                model: zone.ids.filter(id => bar.widgets[id] !== undefined && bar.ownerOf(id) === zone)

                Loader {
                    required property string modelData

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: modelData === "windowTitle"
                    Layout.minimumWidth: modelData === "windowTitle" ? 0 : implicitWidth
                    sourceComponent: bar.widgets[modelData]
                }
            }
        }

        Component {
            id: workspacesComponent

            Workspaces {
                output: bar.modelData.name
            }
        }

        Component {
            id: windowTitleComponent

            WindowTitle {}
        }

        Component {
            id: trayComponent

            Tray {}
        }

        Component {
            id: keyboardComponent

            KeyboardLayout {}
        }

        Component {
            id: statusComponent

            StatusIcons {}
        }

        Component {
            id: notificationsComponent

            NotificationButton {}
        }

        Component {
            id: mediaComponent

            MediaWidget {}
        }

        Component {
            id: networkComponent

            NetworkWidget {}
        }

        Component {
            id: noteComponent

            NoteWidget {}
        }

        Component {
            id: dateComponent

            DateWidget {}
        }

        Component {
            id: weatherComponent

            WeatherWidget {}
        }

        Component {
            id: sysmonComponent

            SystemMonitor {}
        }

        Component {
            id: clockComponent

            Clock {}
        }
    }
}
