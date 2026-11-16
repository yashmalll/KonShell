#!/usr/bin/env python3
"""Report device users, never audio/video content; no elevated permissions."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time


def classify_graph(objects):
    nodes = {obj["id"]: obj.get("info", {}) for obj in objects
             if obj.get("type", "").endswith(":Node") and "id" in obj}
    upstream = {}
    for obj in objects:
        if not obj.get("type", "").endswith(":Link"):
            continue
        info = obj.get("info", {})
        if info.get("state") != "active":
            continue
        props = info.get("props", {})
        source = info.get("output-node-id", props.get("link.output.node"))
        target = info.get("input-node-id", props.get("link.input.node"))
        try:
            upstream.setdefault(int(target), []).append(int(source))
        except (TypeError, ValueError):
            pass

    def sources(node_id):
        seen, pending, result = set(), list(upstream.get(node_id, [])), []
        while pending:
            current = pending.pop()
            if current in seen:
                continue
            seen.add(current)
            props = nodes.get(current, {}).get("props", {})
            if props.get("media.class") in ("Audio/Source", "Audio/Sink", "Video/Source"):
                result.append(props)
            else:
                pending.extend(upstream.get(current, []))
        return result

    result = {"microphone": [], "camera": [], "screen": []}
    for node_id, info in nodes.items():
        props = info.get("props", {})
        media_class = props.get("media.class", "")
        if info.get("state") != "running" or media_class not in ("Stream/Input/Audio", "Stream/Input/Video"):
            continue
        name = props.get("application.name") or props.get("application.process.binary") or props.get("node.description") or "Приложение"
        connected = sources(node_id)
        if media_class == "Stream/Input/Audio":
            # A speaker-monitor recording is not microphone access.
            if any(p.get("media.class") == "Audio/Source"
                   and not str(p.get("node.name", "")).endswith(".monitor")
                   and str(p.get("stream.capture.sink", "false")).lower() != "true"
                   for p in connected):
                result["microphone"].append(name)
        else:
            for source in connected:
                if source.get("media.class") != "Video/Source":
                    continue
                identity = " ".join(str(source.get(key, "")) for key in
                                    ("node.name", "node.description", "application.name", "media.role"))
                if re.search(r"portal|screencast|screen.?cast|screen.?share|niri|hyprland", identity, re.I):
                    result["screen"].append(name)
                elif source.get("api.v4l2.path") or source.get("device.api") in ("v4l2", "libcamera") or re.search(r"camera|webcam|v4l2", identity, re.I):
                    result["camera"].append(name)
    return {key: sorted(set(names)) for key, names in result.items()}


def camera_holders(proc_root=Path("/proc"), uid=None):
    uid = os.getuid() if uid is None else uid
    holders = set()
    for process in proc_root.iterdir():
        if not process.name.isdigit():
            continue
        try:
            if process.stat().st_uid != uid:
                continue
            name = (process / "comm").read_text().strip()
            # Backends may retain an idle camera; graph state covers these.
            if name in ("pipewire", "wireplumber"):
                continue
            for fd in (process / "fd").iterdir():
                try:
                    target = os.readlink(fd)
                except OSError:
                    continue
                if re.fullmatch(r"/dev/video\d+", target):
                    holders.add(name)
                    break
        except (OSError, ValueError):
            continue
    return sorted(holders)


def snapshot():
    result = {"microphone": [], "camera": [], "screen": [], "available": False}
    try:
        completed = subprocess.run(["pw-dump"], capture_output=True, text=True, timeout=2, check=True)
        result.update(classify_graph(json.loads(completed.stdout)))
        result["available"] = True
    except (OSError, subprocess.SubprocessError, ValueError, TypeError):
        pass
    result["camera"] = sorted(set(result["camera"] + camera_holders()))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    previous = None
    while True:
        data = snapshot()
        serialized = json.dumps(data, ensure_ascii=False, sort_keys=True)
        if serialized != previous:
            print(serialized, flush=True)
            previous = serialized
        if args.once:
            break
        time.sleep(3)


if __name__ == "__main__":
    main()
