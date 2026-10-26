import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Панель под часами: крупные время и дата, календарь, плеер и быстрая заметка —
// колонками рядом (до четырёх), размер по содержимому.
// Открывается кликом по часам в панели или через IPC:
//   qs -c konshell ipc call dashboard toggle
//   qs -c konshell ipc call dashboard note     # сразу в поле новой заметки
// Esc или клик мимо закрывают.
Scope {
    id: root

    IpcHandler {
        target: "dashboard"

        function toggle(): void {
            Ui.dashboardOpen = !Ui.dashboardOpen;
        }
        function open(): void {
            Ui.openDashboard(false);
        }
        function note(): void {
            Ui.openDashboard(true);
        }
        function close(): void {
            Ui.dashboardOpen = false;
        }
    }

    // Диагностика монитора системы и «Не засыпать».
    IpcHandler {
        target: "system"

        function stats(): string {
            return JSON.stringify({
                cpu: SystemStats.cpu,
                memory: SystemStats.memory,
                memoryUsedGiB: SystemStats.memoryUsedGiB,
                temperature: SystemStats.temperature,
                temperaturePath: SystemStats.temperaturePath,
                disk: SystemStats.disk,
                diskFreeGiB: SystemStats.diskFreeGiB,
                disks: SystemStats.disks,
                swap: SystemStats.swap,
                swapTotalGiB: SystemStats.swapTotalGiB,
                polling: SystemStats.needed
            });
        }
        function caffeine(): string {
            return JSON.stringify({ active: Caffeine.active, minutesLeft: Caffeine.minutesLeft, summary: Caffeine.summary });
        }
        function toggleCaffeine(): void {
            Caffeine.active ? Caffeine.disable() : Caffeine.enable(0);
        }
    }

    PopupLoader {
        id: popup

        open: Ui.dashboardOpen

        PanelWindow {
            id: window

            // Скрытое окно (PopupLoader.keepLoaded) не показывается, но и не удаляется.
            visible: popup.windowVisible

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-dashboard"
            WlrLayershell.layer: WlrLayer.Overlay
            // Заметке нужна клавиатура.
            WlrLayershell.keyboardFocus: popup.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            // Пока сворачивается — клики и клавиатура уже не перехватываются.
            mask: popup.open ? null : closedMask

            Region {
                id: closedMask
            }

            BackgroundEffect.blurRegion: Region {
                item: panel.blurItem
                radius: Theme.radius.panel
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Ui.dashboardOpen = false
            }

            PopupSurface {
                id: panel

                shown: popup.open

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                // Отступ как у окон niri (gaps 6), чтобы панель стояла в той же сетке.
                anchors.topMargin: Settings.bar.height + 6
                width: Math.min(layout.implicitWidth + Theme.spacing.lg * 2, window.width - 12)
                height: Math.min(layout.implicitHeight + Theme.spacing.lg * 2, window.height - Settings.bar.height - 12)

                // Карточка или колонка появилась или скрылась (плеер, погода) — панель
                // плавно подстраивается по размеру.
                Behavior on width {
                    enabled: panel.progress === 1
                    NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.enter }
                }
                Behavior on height {
                    enabled: panel.progress === 1
                    NumberAnimation { duration: Theme.anim.normal; easing.type: Theme.anim.enter }
                }
                clip: true
                focus: true

                Keys.onEscapePressed: Ui.dashboardOpen = false

                // Курсор — в поле новой заметки, если её и просили (IPC dashboard note):
                // при открытии или повторной команде при уже открытой панели.
                function focusNoteIfRequested() {
                    if (Ui.noteRequested && noteItem)
                        Qt.callLater(() => noteItem?.focusInput());
                }

                function onShow() {
                    scroller.contentY = 0;
                    calendarItem?.goToday();
                    Notes.checkDirectory();
                    panel.forceActiveFocus();
                    focusNoteIfRequested();
                }

                Component.onCompleted: onShow()

                Connections {
                    target: window

                    function onVisibleChanged() {
                        if (window.visible)
                            panel.onShow();
                    }
                }

                Connections {
                    target: Ui

                    function onNoteRequestedChanged() {
                        panel.focusNoteIfRequested();
                    }
                }

                // Карточки по id; ширину задаёт колонка. Ссылки на заметку и календарь —
                // для курсора в новой заметке и возврата календаря к текущему месяцу.
                property Item noteItem: null
                property Item calendarItem: null
                readonly property var cardComponents: ({
                    clock: clockCard,
                    weather: weatherCard,
                    calendar: calendarCard,
                    system: systemCard,
                    media: mediaCard,
                    notes: notesCard,
                    network: networkCard
                })
                // До четырёх колонок слева направо — панель широкая, но невысокая. Карточка из нескольких
                // колонок — только в первой; колонка, в которой нечего показать (пустая
                // или только с выключенной погодой), не занимает места.
                readonly property var columns: {
                    const seen = new Set();
                    return [
                        { key: "left", width: 300 },
                        { key: "middle", width: 300 },
                        { key: "right", width: 340 },
                        { key: "extra", width: 320 }
                    ].map(c => ({ key: c.key, width: c.width,
                                  cards: Settings.dashboard[c.key].filter(id => {
                                      if (cardComponents[id] === undefined || seen.has(id))
                                          return false;
                                      seen.add(id);
                                      return true;
                                  }) }))
                     .filter(c => c.cards.some(id => id !== "weather" || Settings.weather.enabled));
                }

                Component {
                    id: clockCard

                    Column {
                        spacing: Theme.spacing.xxs

                        StyledText {
                            text: Qt.formatTime(clock.date, "HH:mm")
                            font.pixelSize: Math.round(Theme.font.display * 2.2)
                            font.weight: Theme.font.medium
                            font.features: { "tnum": 1 }
                        }

                        StyledText {
                            text: {
                                const s = Qt.locale().toString(clock.date, "dddd, d MMMM yyyy");
                                return s.charAt(0).toUpperCase() + s.slice(1);
                            }
                            color: Theme.color.textMuted
                        }

                        SystemClock {
                            id: clock
                            precision: SystemClock.Minutes
                        }
                    }
                }

                Component {
                    id: weatherCard

                    WeatherCard {}
                }

                Component {
                    id: calendarCard

                    Calendar {
                        Component.onCompleted: panel.calendarItem = this
                        Component.onDestruction: if (panel.calendarItem === this) panel.calendarItem = null
                    }
                }

                Component {
                    id: systemCard

                    SystemCard {}
                }

                Component {
                    id: mediaCard

                    MediaPlayer {}
                }

                Component {
                    id: notesCard

                    QuickNote {
                        Component.onCompleted: panel.noteItem = this
                        Component.onDestruction: if (panel.noteItem === this) panel.noteItem = null
                    }
                }

                Component {
                    id: networkCard

                    NetworkCard {}
                }

                // Клики внутри панели не закрывают её.
                MouseArea {
                    anchors.fill: parent
                }

                // Если содержимое выше экрана — прокрутка колесом (над календарём колесо
                // листает месяцы).
                Flickable {
                    id: scroller

                    anchors.fill: parent
                    anchors.margins: Theme.spacing.lg
                    contentWidth: layout.implicitWidth
                    contentHeight: layout.implicitHeight
                    interactive: contentHeight > height || contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // Колонки и карточки — из настроек (dashboard.left, .middle, .right, .extra);
                    // редактор — «Настройки KonShell» → «Часы и календарь». Размер панели
                    // следует за содержимым: ширина — по колонкам, высота — по самой
                    // высокой; скрытые и пустые карточки места не занимают.
                    Row {
                        id: layout

                        spacing: Theme.spacing.xl

                        Repeater {
                            model: panel.columns

                            Row {
                                id: column

                                required property var modelData
                                required property int index

                                spacing: Theme.spacing.xl

                                Rectangle {
                                    width: 1
                                    height: layout.height
                                    color: Theme.color.border
                                    visible: column.index > 0
                                }

                                Column {
                                    width: column.modelData.width
                                    spacing: Theme.spacing.lg

                                    Repeater {
                                        model: column.modelData.cards

                                        Loader {
                                            required property string modelData

                                            width: parent.width
                                            sourceComponent: panel.cardComponents[modelData]
                                            visible: (modelData !== "weather" || Settings.weather.enabled)
                                                     && (item?.implicitHeight ?? 0) > 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Полоса прокрутки — только когда есть что прокручивать.
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 3
                    y: Theme.spacing.lg + scroller.visibleArea.yPosition * scroller.height
                    width: 3
                    height: scroller.visibleArea.heightRatio * scroller.height
                    radius: Theme.radius.full
                    color: Theme.color.outline
                    opacity: scroller.interactive ? (scroller.moving ? 0.8 : 0.35) : 0

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.normal }
                    }
                }
            }
        }
    }
}
