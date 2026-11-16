pragma Singleton
import QtQuick
import Quickshell
import qs.config

Singleton {
    readonly property string current: ["custom", "work", "rest"].includes(Settings.profiles.active) ? Settings.profiles.active : "custom"
    readonly property bool quiet: current === "work"
    readonly property string name: ({ custom: "Мой", work: "Работа", rest: "Отдых" })[current]
    function select(id) {
        if (!["custom", "work", "rest"].includes(id)) return false;
        Settings.profiles.active = id;
        return true;
    }
    function idsForZone(zone) {
        if (current === "custom") return Settings.bar[zone];
        const ids = Array.from(current === "work" ? Settings.profiles.workWidgets : Settings.profiles.restWidgets);
        return ids.filter((id, index) => ids.indexOf(id) === index
            && (zone === "left" ? ["workspaces", "windowTitle"].includes(id)
                : zone === "center" ? id === "clock" : !["workspaces", "windowTitle", "clock"].includes(id)));
    }
    function cardVisible(id) {
        return current === "custom" || (current === "work" ? Settings.profiles.workCards : Settings.profiles.restCards).includes(id);
    }
}
