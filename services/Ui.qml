pragma Singleton

import QtQuick
import Quickshell

// Общее состояние интерфейса: какие панели открыты.
Singleton {
    id: root

    property bool controlCenterOpen: false

    // История буфера обмена (modules/clipboard).
    property bool clipboardOpen: false

    // Меню сеанса (modules/session): поверх всего, закрывает остальные панели.
    property bool sessionOpen: false

    onSessionOpenChanged: {
        if (sessionOpen) {
            controlCenterOpen = false;
            dashboardOpen = false;
            Notifications.centerOpen = false;
        }
    }

    // Панель под часами: календарь, плеер, заметки. noteRequested — открыть
    // сразу с курсором в поле новой заметки (IPC dashboard note).
    property bool dashboardOpen: false
    property bool noteRequested: false

    function openDashboard(withNote) {
        // Сброс, чтобы повторная просьба о заметке снова вызвала сигнал изменения.
        noteRequested = false;
        noteRequested = withNote === true;
        dashboardOpen = true;
    }

    // Одновременно открыта одна панель с клавиатурным фокусом.
    onDashboardOpenChanged: {
        if (dashboardOpen) {
            controlCenterOpen = false;
            Notifications.centerOpen = false;
        } else {
            noteRequested = false;
        }
    }
    // main | wifi | bluetooth | audio; при закрытии сбрасывается на main.
    property string controlCenterPage: "main"

    // Окно «Настройки KonShell» и открытый в нём раздел — id из config/settings-schema.js.
    property bool settingsOpen: false
    property string settingsSection: "appearance"

    // Окно уже открыто (возможно, на другом рабочем столе) — окно настроек
    // по этому сигналу переводит на себя фокус.
    signal settingsRaiseRequested

    function openSettings(section) {
        settingsSection = section || settingsSection;
        controlCenterOpen = false;
        if (settingsOpen)
            settingsRaiseRequested();
        else
            settingsOpen = true;
    }

    // Обзор niri: панели с клавиатурным фокусом мешали бы управлять им — закрываем.
    // Лаунчер закрывается сам по этому же сигналу (modules/launcher/Launcher.qml).
    Connections {
        target: Niri

        function onOverviewOpenChanged() {
            if (!Niri.overviewOpen)
                return;
            root.controlCenterOpen = false;
            root.dashboardOpen = false;
            Notifications.centerOpen = false;
        }
    }

    Connections {
        target: Notifications

        function onCenterOpenChanged() {
            if (Notifications.centerOpen)
                root.dashboardOpen = false;
        }
    }

    onControlCenterOpenChanged: {
        if (controlCenterOpen)
            dashboardOpen = false;
        else
            controlCenterPage = "main";
    }
}
