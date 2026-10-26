pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// Сервер уведомлений. Все уведомления остаются в истории, пока их не закроют;
// всплывающие окна показываются отдельно и скрываются по таймеру.
Singleton {
    id: root

    // Новые в начале.
    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property int count: history.length

    // Уведомления, которые сейчас показаны всплывающими окнами.
    property var popups: []

    // Время прихода по id: в самом Notification его нет.
    property var receivedAt: ({})

    property bool centerOpen: false

    readonly property bool dnd: Settings.notifications.dnd

    function setDnd(value) {
        Settings.notifications.dnd = value;
        if (value)
            popups = popups.filter(n => n.urgency === NotificationUrgency.Critical);
    }

    function hidePopup(notification) {
        popups = popups.filter(n => n !== notification);
    }

    function clearAll() {
        for (const n of history)
            n.dismiss();
    }

    // notifications.historyLimit: лишние, начиная с самых старых, закрываются.
    function trimHistory() {
        const limit = Settings.notifications.historyLimit;
        const all = server.trackedNotifications.values;
        if (limit <= 0 || all.length <= limit)
            return;
        for (const n of all.slice(0, all.length - limit))
            n.dismiss();
    }

    NotificationServer {
        id: server

        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            // Приложения из notifications.blockedApps не показываются и не попадают
            // в историю. Срочные пропускаются всегда: их не должен прятать фильтр.
            const app = (notification.appName || "").toLowerCase();
            const blocked = Settings.notifications.blockedApps.some(name => name.trim().toLowerCase() === app);
            if (blocked && notification.urgency !== NotificationUrgency.Critical)
                return;

            notification.tracked = true;
            Qt.callLater(root.trimHistory);

            // После перезагрузки конфига старые уведомления приходят заново
            // с lastGeneration: возвращаем их в историю без всплывающего окна.
            if (!notification.lastGeneration)
                root.receivedAt = Object.assign({}, root.receivedAt, { [notification.id]: new Date() });

            const critical = notification.urgency === NotificationUrgency.Critical;
            if (!notification.lastGeneration && (!root.dnd || critical))
                root.popups = [notification].concat(root.popups.filter(n => n.id !== notification.id));

            notification.closed.connect(() => {
                root.hidePopup(notification);
                const times = Object.assign({}, root.receivedAt);
                delete times[notification.id];
                root.receivedAt = times;
            });
        }
    }
}
