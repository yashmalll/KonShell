import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Боковая панель у края экрана: заметки (список, поиск, новая) и снимок или
// запись экрана. Открывается, когда мышь упирается в край (sidebar.edge: правый,
// левый или оба; sidebar.hotEdge, задержка sidebar.delay), или через IPC:
//   qs -c konshell ipc call sidebar toggle | open | close
//   qs -c konshell ipc call sidebar note      # окно новой заметки
//   qs -c konshell ipc call sidebar openNote ~/Документы/Notes/Идея.md | closeNote
//   qs -c konshell ipc call sidebar notesDirectory   # папка заметок
// Закрывается кликом мимо, Esc или когда мышь ушла с панели.
Scope {
    id: root

    readonly property var edges: Settings.sidebar.edge === "both" ? ["left", "right"] : [Settings.sidebar.edge]

    IpcHandler {
        target: "sidebar"

        function toggle(): void {
            if (Ui.sidebarOpen)
                Ui.sidebarOpen = false;
            else
                Ui.openSidebar(Niri.focusedWorkspace?.output ?? "", root.edges[root.edges.length - 1]);
        }
        function open(): void {
            Ui.openSidebar(Niri.focusedWorkspace?.output ?? "", root.edges[root.edges.length - 1]);
        }
        function close(): void {
            Ui.sidebarOpen = false;
        }
        function note(): void {
            Ui.openNote("");
        }
        function openNote(path: string): void {
            Ui.openNote(path);
        }
        function closeNote(): void {
            Ui.noteOpen = false;
        }
        // Куда сохраняются заметки — для проверки.
        function notesDirectory(): string {
            return Notes.directory;
        }
    }

    // Полоски в 1 пиксель у краёв каждого монитора: мышь упёрлась и задержалась —
    // панель выезжает. Углы свободны (горячий угол niri, кнопки окон у панели).
    Variants {
        model: Settings.sidebar.enabled && Settings.sidebar.hotEdge
            ? Quickshell.screens.reduce((all, s) => all.concat(root.edges.map(e => ({ screen: s, edge: e }))), [])
            : []

        PanelWindow {
            id: trigger

            required property var modelData

            screen: modelData.screen
            WlrLayershell.namespace: "konshell-sidebar-edge"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: modelData.edge === "left"
                right: modelData.edge === "right"
            }
            margins {
                top: Settings.bar.height + 48
                bottom: 48
            }
            implicitWidth: 1
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: dwell.restart()
                onExited: dwell.stop()
            }

            Timer {
                id: dwell

                interval: Math.max(1, Settings.sidebar.delay)
                onTriggered: {
                    if (!Ui.sidebarOpen && !Ui.noteOpen && !Niri.overviewOpen)
                        Ui.openSidebar(trigger.modelData.screen.name, trigger.modelData.edge);
                }
            }
        }
    }

    PopupLoader {
        id: popup

        open: Ui.sidebarOpen && Settings.sidebar.enabled

        PanelWindow {
            id: window

            readonly property bool left: Ui.sidebarEdge === "left"

            visible: popup.windowVisible
            screen: Quickshell.screens.find(s => s.name === Ui.sidebarScreen)
                ?? Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-sidebar"
            WlrLayershell.layer: WlrLayer.Overlay
            // Поиску нужна клавиатура, но только когда в него кликнули.
            WlrLayershell.keyboardFocus: popup.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
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
                onClicked: Ui.sidebarOpen = false
            }

            PopupSurface {
                id: panel

                shown: popup.open

                // Отступы как у окон niri (gaps 6).
                x: window.left ? 6 : window.width - width - 6
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: Settings.bar.height + 6
                anchors.bottomMargin: 6
                width: Math.max(300, Math.min(520, Settings.sidebar.width))
                clip: true
                focus: true

                Keys.onEscapePressed: Ui.sidebarOpen = false

                function onShow() {
                    notes.query = "";
                    Notes.checkDirectory();
                    panel.forceActiveFocus();
                    entered = false;
                }

                // Мышь побывала на панели и ушла — панель закрывается (если не печатают в поиске).
                property bool entered: false

                Component.onCompleted: onShow()

                Connections {
                    target: window

                    function onVisibleChanged() {
                        if (window.visible)
                            panel.onShow();
                    }
                }

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            panel.entered = true;
                            leaveTimer.stop();
                        } else if (panel.entered && notes.query === "") {
                            leaveTimer.restart();
                        }
                    }
                }

                Timer {
                    id: leaveTimer

                    interval: 600
                    onTriggered: Ui.sidebarOpen = false
                }

                // Клики внутри панели не закрывают её.
                MouseArea {
                    anchors.fill: parent
                }

                NotesList {
                    id: notes

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: divider.top
                    anchors.margins: Theme.spacing.lg
                    anchors.bottomMargin: Theme.spacing.md
                }

                Rectangle {
                    id: divider

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: capture.top
                    anchors.leftMargin: Theme.spacing.lg
                    anchors.rightMargin: Theme.spacing.lg
                    anchors.bottomMargin: Theme.spacing.md
                    height: 1
                    color: Theme.color.border
                }

                CaptureTiles {
                    id: capture

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Theme.spacing.lg
                }
            }
        }
    }
}
