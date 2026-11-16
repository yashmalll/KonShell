.pragma library

function choose(state) {
    if (state.timerAttention) return "timer";
    if (state.recording) return "recording";
    if (state.privacy) return "privacy";
    if (state.timer) return "timer";
    if (state.media && !state.focus && state.mediaAllowed) return "media";
    return state.focus ? "focus" : "idle";
}
