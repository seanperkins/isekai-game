"""The review app's file watcher: real threads and real files, short timings."""
import os
import queue
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import watcher  # noqa: E402

SETTLE, INTERVAL = 0.05, 0.02


class WatcherTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.content, self.app = Path(self._tmp.name, "content"), Path(self._tmp.name, "app")
        self.content.mkdir()
        self.app.mkdir()

    def watch(self):
        w = watcher.Watcher({"content": self.content, "app": self.app}, settle=SETTLE, interval=INTERVAL)
        w.start()
        self.addCleanup(w.stop)
        q = w.subscribe()
        time.sleep(INTERVAL * 3)   # let the first scan take its baseline
        return w, q

    def assertQuiet(self, q, seconds=0.3):
        with self.assertRaises(queue.Empty):
            q.get(timeout=seconds)

    def test_a_new_file_produces_one_content_event(self):
        _, q = self.watch()
        (self.content / "creatures" / "x").mkdir(parents=True)
        (self.content / "creatures" / "x" / "page.json").write_text("{}")
        self.assertEqual(q.get(timeout=1), {"type": "content", "path": "creatures/x/page.json"})
        self.assertQuiet(q)

    def test_a_burst_of_writes_to_one_file_is_one_event_after_the_settle(self):
        _, q = self.watch()
        target = self.content / "page.json"
        for i in range(20):
            target.write_text("{" + " " * i + "}")
            time.sleep(0.005)
        self.assertEqual(q.get(timeout=1)["path"], "page.json")
        self.assertQuiet(q)

    def test_three_files_written_together_give_three_events_one_each(self):
        _, q = self.watch()
        for name in ("a.png", "b.png", "page.json"):
            (self.content / name).write_text(name)
        got = sorted(q.get(timeout=1)["path"] for _ in range(3))
        self.assertEqual(got, ["a.png", "b.png", "page.json"])
        self.assertQuiet(q)

    def test_a_change_under_the_app_root_is_type_app(self):
        _, q = self.watch()
        (self.app / "app.js").write_text("// changed")
        self.assertEqual(q.get(timeout=1), {"type": "app", "path": "app.js"})

    def test_a_deleted_file_is_reported(self):
        (self.content / "old.json").write_text("{}")
        _, q = self.watch()
        (self.content / "old.json").unlink()
        self.assertEqual(q.get(timeout=1), {"type": "content", "path": "old.json"})

    def test_a_file_still_being_written_is_not_announced_before_it_settles(self):
        _, q = self.watch()
        target = self.content / "slow.json"
        last_write = 0.0
        for i in range(8):
            target.write_text("x" * (i + 1))
            last_write = time.monotonic()
            time.sleep(0.02)
        q.get(timeout=1)
        self.assertGreaterEqual(time.monotonic() - last_write, SETTLE - 0.001)

    def test_editor_and_temp_files_are_ignored(self):
        _, q = self.watch()
        for name in (".DS_Store", "page.json~", "page.json.tmp"):
            (self.content / name).write_text("x")
        self.assertQuiet(q)

    def test_stop_ends_the_thread(self):
        w, _ = self.watch()
        self.assertTrue(w.thread.is_alive())
        w.stop()
        self.assertFalse(w.thread.is_alive())


if __name__ == "__main__":
    unittest.main()
