import QtQuick
import qs.config
import qs.services
import qs.widgets

// Снимок и запись экрана в боковой панели (services/ScreenRecorder.qml).
// Перед стартом панель закрывается и выжидает паузу — в кадр она не попадает.
Column {
    id: root

    spacing: Theme.spacing.sm

    StyledText {
        text: "Экран"
        font.pixelSize: Theme.font.title
        font.weight: Theme.font.medium
    }

    Grid {
        id: tiles

        readonly property real tileWidth: (width - spacing) / 2

        width: parent.width
        columns: 2
        spacing: Theme.spacing.sm

        // Встроенный инструмент снимков niri: область, окно или экран; сохраняет и копирует.
        Tile {
            width: tiles.tileWidth
            icon: "applets-screenshooter-symbolic"
            title: "Скриншот"
            subtitle: "Область или окно"
            onClicked: {
                Ui.sidebarOpen = false;
                ScreenRecorder.screenshot(350);
            }
        }

        // Клик — весь экран, стрелка — выбрать область; во время записи клик — стоп.
        Tile {
            width: tiles.tileWidth
            icon: "media-record-symbolic"
            title: ScreenRecorder.recording ? "Остановить" : "Запись"
            subtitle: ScreenRecorder.recording ? ScreenRecorder.format(ScreenRecorder.elapsed)
                : ScreenRecorder.available ? "Весь экран" : "Нужны wf-recorder и slurp"
            active: ScreenRecorder.recording
            enabled: ScreenRecorder.available
            hasDetails: ScreenRecorder.available && !ScreenRecorder.recording
            onClicked: {
                if (ScreenRecorder.recording) {
                    ScreenRecorder.stop();
                } else {
                    Ui.sidebarOpen = false;
                    ScreenRecorder.start("screen", 400);
                }
            }
            onDetailsClicked: {
                Ui.sidebarOpen = false;
                ScreenRecorder.start("region", 400);
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Стрелка у записи — выбрать область мышью"
        color: Theme.color.textMuted
        font.pixelSize: Theme.font.caption
        visible: ScreenRecorder.available && !ScreenRecorder.recording
    }
}
