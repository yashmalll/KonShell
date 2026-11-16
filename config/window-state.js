// niri 26.04 exposes window geometry, but has no fullscreen flag in IPC.
// Inspect only the active workspace on the requested output.
function fullscreenOn(windows, workspaces, output, width, height, overview) {
    if (overview || width <= 0 || height <= 0) return false;
    const workspace = workspaces.find(w => w.output === output && w.is_active);
    if (!workspace) return false;
    return windows.some(w => {
        if (w.workspace_id !== workspace.id) return false;
        if (typeof w.is_fullscreen === 'boolean') return w.is_fullscreen;
        const size = w.layout?.window_size;
        return !!size && Math.abs(size[0] - width) <= 2 && Math.abs(size[1] - height) <= 2;
    });
}
