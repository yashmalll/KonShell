import QtQuick
import Quickshell

// Обои — один слой на каждом мониторе (konshell-wallpaper), в заднике niri:
// правило place-within-backdrop и прозрачный фон рабочих столов
// (layout { background-color "transparent" }) — niri/konshell.kdl, подключает install.sh.
// Обои видны сквозь столы и стоят на месте: в обзоре и при переходе между столами
// под каждым столом нет своей копии.
Variants {
    model: Quickshell.screens

    WallpaperWindow {
        required property ShellScreen modelData

        screen: modelData
        layerNamespace: "konshell-wallpaper"
    }
}
