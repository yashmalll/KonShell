pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config

// Громкость и выключение звука устройств по умолчанию через PipeWire.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0

    readonly property string icon: muted || volume === 0 ? "audio-volume-muted-symbolic"
        : volume < 0.34 ? "audio-volume-low-symbolic"
        : volume < 0.67 ? "audio-volume-medium-symbolic"
        : "audio-volume-high-symbolic"
    readonly property string micIcon: micMuted ? "microphone-sensitivity-muted-symbolic" : "microphone-sensitivity-high-symbolic"

    // Реальные устройства (не потоки приложений).
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    function deviceName(node) {
        return node?.nickname || node?.description || node?.name || "";
    }

    function setOutput(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setInput(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function setMicVolume(value) {
        if (!source?.audio)
            return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, value));
    }

    function setVolume(value) {
        if (!sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(Settings.audio.maxVolume, value));
    }

    function increaseVolume() {
        setVolume(volume + Settings.audio.step);
    }

    function decreaseVolume() {
        setVolume(volume - Settings.audio.step);
    }

    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Без трекера PipeWire не отдаёт свойства audio у узлов.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
