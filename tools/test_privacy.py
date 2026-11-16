import importlib.util
from pathlib import Path
import tempfile
import unittest
import os

spec = importlib.util.spec_from_file_location("privacy", Path(__file__).resolve().parents[1] / "scripts/privacy-monitor.py")
privacy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(privacy)


def node(number, media_class, state="running", **props):
    return {"id": number, "type": "PipeWire:Interface:Node", "info": {
        "state": state, "props": {"media.class": media_class, **props}}}


def link(source, target, state="active"):
    return {"type": "PipeWire:Interface:Link", "info": {
        "state": state, "output-node-id": source, "input-node-id": target}}


class PrivacyTests(unittest.TestCase):
    def test_playback_and_speaker_monitor_are_not_microphone(self):
        graph = [node(1, "Audio/Sink"), node(2, "Stream/Output/Audio"),
                 node(3, "Stream/Input/Audio", **{"application.name": "Recorder"}), link(1, 3)]
        self.assertEqual(privacy.classify_graph(graph)["microphone"], [])

    def test_microphone_through_filter_and_duplicate_streams(self):
        graph = [node(1, "Audio/Source"), node(2, "Audio/Filter"),
                 node(3, "Stream/Input/Audio", **{"application.name": "Call"}),
                 node(4, "Stream/Input/Audio", **{"application.name": "Call"}),
                 link(1, 2), link(2, 3), link(2, 4), link(2, 2)]
        self.assertEqual(privacy.classify_graph(graph)["microphone"], ["Call"])

    def test_suspended_capture_and_inactive_links_are_ignored(self):
        graph = [node(1, "Audio/Source"), node(2, "Stream/Input/Audio", "suspended"),
                 node(3, "Stream/Input/Audio"), link(1, 2), link(1, 3, "paused")]
        self.assertEqual(privacy.classify_graph(graph)["microphone"], [])

    def test_monitor_source_is_not_microphone(self):
        graph = [node(1, "Audio/Source", **{"node.name": "speakers.monitor"}),
                 node(2, "Stream/Input/Audio"), link(1, 2)]
        self.assertEqual(privacy.classify_graph(graph)["microphone"], [])

    def test_screen_and_camera_are_distinct(self):
        graph = [node(1, "Video/Source", **{"node.name": "xdg-desktop-portal-niri"}),
                 node(2, "Video/Source", **{"device.api": "v4l2"}),
                 node(3, "Stream/Input/Video", **{"application.name": "Share"}),
                 node(4, "Stream/Input/Video", **{"application.name": "Call"}),
                 link(1, 3), link(2, 4)]
        result = privacy.classify_graph(graph)
        self.assertEqual(result["screen"], ["Share"])
        self.assertEqual(result["camera"], ["Call"])

    def test_unknown_video_source_is_not_claimed_to_be_camera(self):
        graph = [node(1, "Video/Source"), node(2, "Stream/Input/Video"), link(1, 2)]
        self.assertEqual(privacy.classify_graph(graph), {"microphone": [], "camera": [], "screen": []})

    def test_direct_camera_handles_and_idle_backend(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for number, name, target in [(1, "browser", "/dev/video0"),
                                         (2, "pipewire", "/dev/video0"),
                                         (3, "editor", "/dev/null")]:
                process = root / str(number)
                (process / "fd").mkdir(parents=True)
                (process / "comm").write_text(name)
                (process / "fd/5").symlink_to(target)
            self.assertEqual(privacy.camera_holders(root, os.getuid()), ["browser"])


if __name__ == "__main__":
    unittest.main()
