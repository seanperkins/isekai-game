"""Watch folders for changes and say, once a file has stopped changing, which one it was.

A poll rather than the OS's file events: nothing to install, the same on every machine, and a few hundred small files cost almost nothing to stat.
An event is {"type": <the root's key>, "path": <relative to that root, with / separators>}; it comes once per file after the file has been quiet for `settle`
seconds, so a render that writes twenty frames and then a listing is announced as twenty-one finished files, not as a hundred half-written ones.
"""
import os
import queue
import threading
import time
from pathlib import Path


def _ignored(name):
    return name == ".DS_Store" or name.endswith("~") or name.endswith(".tmp")


class Watcher:
    def __init__(self, roots, settle=0.15, interval=0.25):
        self.roots = {key: Path(path) for key, path in roots.items()}
        self.settle, self.interval = settle, interval
        self.thread = None
        self._known, self._pending, self._subs = {}, {}, []
        self._lock, self._stop = threading.Lock(), threading.Event()

    def subscribe(self):
        """A queue that gets every event from now on."""
        q = queue.Queue()
        with self._lock:
            self._subs.append(q)
        return q

    def unsubscribe(self, q):
        with self._lock:
            if q in self._subs:
                self._subs.remove(q)

    def start(self):
        self._known = self._scan()
        self._stop.clear()
        self.thread = threading.Thread(target=self._run, name="review-watcher", daemon=True)
        self.thread.start()

    def stop(self):
        self._stop.set()
        if self.thread is not None:
            self.thread.join(timeout=2.0)

    def _scan(self):
        """{(root key, relative path): (mtime_ns, size)} for every file under the roots."""
        found = {}
        for key, root in self.roots.items():
            stack = [root]
            while stack:
                folder = stack.pop()
                try:
                    with os.scandir(folder) as it:
                        for entry in it:
                            if _ignored(entry.name):
                                continue
                            try:
                                if entry.is_dir(follow_symlinks=False):
                                    stack.append(entry.path)
                                elif entry.is_file():
                                    st = entry.stat()
                                    found[(key, Path(entry.path).relative_to(root).as_posix())] = (st.st_mtime_ns, st.st_size)
                            except OSError:
                                continue   # gone between the listing and the stat
                except OSError:
                    continue
        return found

    def _run(self):
        while not self._stop.wait(self.interval):
            now = time.monotonic()
            snap = self._scan()
            for item in set(snap) | set(self._known):
                if snap.get(item) != self._known.get(item):
                    self._pending[item] = now
            self._known = snap
            for item in sorted(i for i, t in self._pending.items() if now - t >= self.settle):
                del self._pending[item]
                self._emit({"type": item[0], "path": item[1]})

    def _emit(self, event):
        with self._lock:
            subs = list(self._subs)
        for q in subs:
            q.put(dict(event))
