import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

// Центр управления: быстрые переключатели, звук, яркость, батарея, музыка.
// Wi-Fi, Bluetooth и выбор аудиоустройств открываются отдельными страницами.
// Открывается кликом по значкам в панели или через IPC:
//   qs -c konshell ipc call controlCenter toggle
//   qs -c konshell ipc call controlCenter open wifi
Scope {
    id: root

    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            Ui.controlCenterOpen = !Ui.controlCenterOpen;
        }
        // page: main | wifi | bluetooth | audio (appearance — окно настроек)
        function open(page: string): void {
            if (page === "appearance") {
                Ui.openSettings("appearance");
                return;
            }
            Ui.controlCenterPage = page || "main";
            Ui.controlCenterOpen = true;
        }
    }

    // Запись экрана и снимки:
    //   qs -c konshell ipc call recorder toggle          # весь экран; повторно — стоп
    //   qs -c konshell ipc call recorder region          # выбрать область
    //   qs -c konshell ipc call recorder stop | status
    //   qs -c konshell ipc call recorder screenshot      # инструмент снимков niri
    IpcHandler {
        target: "recorder"

        function toggle(): void {
            ScreenRecorder.toggle("screen");
        }
        function region(): void {
            if (ScreenRecorder.recording)
                ScreenRecorder.stop();
            else
                ScreenRecorder.start("region", 0);
        }
        function stop(): void {
            ScreenRecorder.stop();
        }
        function status(): string {
            return JSON.stringify({
                available: ScreenRecorder.available,
                recording: ScreenRecorder.recording,
                elapsed: ScreenRecorder.elapsed,
                file: ScreenRecorder.file,
                directory: ScreenRecorder.directory,
                lastError: ScreenRecorder.lastError
            });
        }
        function screenshot(): void {
            ScreenRecorder.screenshot(0);
        }
    }

    PopupLoader {
        id: popup

        open: Ui.controlCenterOpen

        PanelWindow {

            // Скрытое окно (PopupLoader.keepLoaded) не показывается, но и не удаляется.

            visible: popup.windowVisible

            // Показ скрытого окна: прокрутка вверх, фокус — для Esc.
            onVisibleChanged: {
                if (visible) {
                    scroller.contentY = 0;
                    panel.forceActiveFocus();
                }
            }

            id: window

            screen: Quickshell.screens.find(s => s.name === Niri.focusedWorkspace?.output) ?? null
            WlrLayershell.namespace: "konshell-control-center"
            // Размытие только под панелью, а не под всем прозрачным окном.
            BackgroundEffect.blurRegion: Region {
                item: panel.blurItem
                radius: Theme.radius.panel
            }

            WlrLayershell.layer: WlrLayer.Overlay
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

            MouseArea {
                anchors.fill: parent
                onClicked: Ui.controlCenterOpen = false
            }

            PopupSurface {
                id: panel

                shown: popup.open

                anchors.top: parent.top
                anchors.right: parent.right
                // Отступы как у окон niri (gaps 6), чтобы панель стояла в той же сетке.
                anchors.topMargin: Settings.bar.height + 6
                anchors.rightMargin: 6
                width: Settings.controlCenter.width
                height: Math.min(pages.implicitHeight + Theme.spacing.lg * 2, window.height * 0.85)
                clip: true
                focus: true

                Keys.onEscapePressed: {
                    if (Ui.controlCenterPage !== "main")
                        Ui.controlCenterPage = "main";
                    else
                        Ui.controlCenterOpen = false;
                }

                MouseArea {
                    anchors.fill: parent
                }

                Item {
                    id: pages

                    readonly property real maxListHeight: window.height * 0.85 - 120

                    anchors.fill: parent
                    anchors.margins: Theme.spacing.lg
                    implicitHeight: loader.item?.implicitHeight ?? 0

                    // Страница длиннее панели прокручивается; списки внутри страниц
                    // (Wi-Fi, обои) прокручиваются сами.
                    Flickable {
                        id: scroller

                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: loader.item?.implicitHeight ?? 0
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Loader {
                            id: loader

                            width: scroller.width
                            onLoaded: scroller.contentY = 0
                            sourceComponent: Ui.controlCenterPage === "wifi" ? wifiPage
                                : Ui.controlCenterPage === "bluetooth" ? bluetoothPage
                                : Ui.controlCenterPage === "audio" ? audioPage
                                : mainPage
                        }
                    }

                    Component {
                        id: mainPage

                        MainPage {
                            onOpenPage: name => Ui.controlCenterPage = name
                        }
                    }

                    Component {
                        id: wifiPage

                        WifiPage {
                            maxListHeight: pages.maxListHeight
                            onBack: Ui.controlCenterPage = "main"
                        }
                    }

                    Component {
                        id: bluetoothPage

                        BluetoothPage {
                            maxListHeight: pages.maxListHeight
                            onBack: Ui.controlCenterPage = "main"
                        }
                    }

                    Component {
                        id: audioPage

                        AudioPage {
                            maxListHeight: pages.maxListHeight
                            onBack: Ui.controlCenterPage = "main"
                        }
                    }
                }
            }
        }
    }
}
