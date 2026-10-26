pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

// Текущий плеер MPRIS для виджета панели: играющий, иначе первый;
// без плееров из media.blacklist (имя или desktop-файл).
Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(p => !Settings.media.blacklist.some(name => {
        const n = name.trim().toLowerCase();
        return n !== "" && (p.identity.toLowerCase() === n || (p.desktopEntry || "").toLowerCase() === n);
    }))
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property string title: player?.trackTitle || player?.identity || ""
    readonly property string artist: player?.trackArtist ?? ""
}
