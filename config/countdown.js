.pragma library

function idle() {
    return { version: 1, mode: "timer", phase: "idle", running: false,
        deadline: 0, remaining: 0, total: 0, completed: 0, autoAdvance: true,
        durations: { work: 1500000, rest: 300000, longRest: 900000 } };
}

function validSeconds(seconds) {
    return Number.isFinite(seconds) && seconds >= 1 && seconds <= 86400;
}

function remaining(state, now) {
    return Math.max(0, state.running ? state.deadline - now : state.remaining);
}

function start(seconds, now) {
    if (!validSeconds(seconds)) return null;
    return Object.assign(idle(), { phase: "timer", running: true,
        total: seconds * 1000, remaining: seconds * 1000, deadline: now + seconds * 1000 });
}

function pomodoro(work, rest, longRest, autoAdvance, now) {
    if (![work, rest, longRest].every(validSeconds)) return null;
    return Object.assign(idle(), { mode: "pomodoro", phase: "work", running: true,
        total: work * 1000, remaining: work * 1000, deadline: now + work * 1000,
        autoAdvance: !!autoAdvance,
        durations: { work: work * 1000, rest: rest * 1000, longRest: longRest * 1000 } });
}

function advance(state, now) {
    if (!state.running || now < state.deadline) return { state, event: "" };
    if (state.mode === "timer")
        return { state: Object.assign({}, state, { phase: "finished", running: false, deadline: 0, remaining: 0 }), event: "finished" };
    const completed = state.completed + (state.phase === "work" ? 1 : 0);
    const phase = state.phase === "work" ? (completed % 4 === 0 ? "longRest" : "rest") : "work";
    const duration = state.durations[phase];
    // On wake, start one next phase, rather than count sleeping hours as work.
    return { state: Object.assign({}, state, { phase, completed, total: duration,
        remaining: duration, running: state.autoAdvance,
        deadline: state.autoAdvance ? now + duration : 0 }), event: phase };
}

function pause(state, now) {
    return state.running ? Object.assign({}, state, { remaining: remaining(state, now), running: false, deadline: 0 }) : state;
}

function resume(state, now) {
    return !state.running && state.remaining > 0 && !["idle", "finished"].includes(state.phase)
        ? Object.assign({}, state, { running: true, deadline: now + state.remaining }) : state;
}

function restore(data) {
    if (!data || data.version !== 1 || !["timer", "pomodoro"].includes(data.mode)
        || !["idle", "timer", "work", "rest", "longRest", "finished"].includes(data.phase)
        || ![data.deadline, data.remaining, data.total, data.completed].every(Number.isFinite)
        || data.remaining < 0 || data.remaining > 86400000 || data.total < 0 || data.total > 86400000
        || data.completed < 0 || !data.durations
        || ![data.durations.work, data.durations.rest, data.durations.longRest].every(v => Number.isFinite(v) && v >= 1000 && v <= 86400000)
        || (data.running && data.deadline <= 0)
        || (data.running && ["idle", "finished"].includes(data.phase))
        || (data.mode === "timer" && !["idle", "timer", "finished"].includes(data.phase))
        || (data.mode === "pomodoro" && !["work", "rest", "longRest"].includes(data.phase))) return idle();
    return Object.assign(idle(), data, { running: data.running === true, autoAdvance: data.autoAdvance === true });
}

function format(milliseconds) {
    const seconds = Math.max(0, Math.ceil(milliseconds / 1000));
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor(seconds % 3600 / 60);
    return (hours ? hours + ":" + String(minutes).padStart(2, "0") : String(minutes))
        + ":" + String(seconds % 60).padStart(2, "0");
}
