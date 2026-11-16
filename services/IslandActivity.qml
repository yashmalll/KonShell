pragma Singleton
import QtQuick
import Quickshell
import "../config/island-activity.js" as Activity

Singleton {
    readonly property string kind: Activity.choose({ timerAttention: Countdown.attention,
        recording: ScreenRecorder.recording || ScreenRecorder.preparing,
        privacy: Privacy.active, timer: Countdown.active, media: Media.player !== null,
        focus: FocusMode.active, mediaAllowed: Profiles.cardVisible("media") })
}
