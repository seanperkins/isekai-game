"""The creature review page's server: the page, the content folder, an event stream and the feedback file.

    tools/review/run.sh [--content DIR] [--port N] [--no-open]

Standard library only, listening on 127.0.0.1. Routes:
  GET /                 the page (app/index.html)            GET /app/*      the page's code
  GET /content/*        the content folder                   GET /api/creatures   one entry per creature page
  GET /events           server-sent events: a file under the content folder or the app folder has finished changing
  GET /api/feedback     the reviewer's notes                 POST /api/feedback   leave one (feedback.py validates it)
"""
import argparse
import errno
import json
import mimetypes
import os
import queue
import sys
import threading
import time
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import feedback  # noqa: E402
from watcher import Watcher  # noqa: E402

HERE = Path(__file__).resolve().parent
APP = HERE / "app"
DEFAULT_CONTENT = feedback.DEFAULT_CONTENT
FIRST_PORT = 8765
MAX_BODY = 4096
KEEPALIVE = 15.0   # seconds of quiet before the event stream sends a comment so a proxy or the browser does not drop it
TYPES = {".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".html": "text/html", ".css": "text/css", ".svg": "image/svg+xml",
         ".glb": "model/gltf-binary", ".gltf": "model/gltf+json", ".png": "image/png", ".gif": "image/gif", ".webp": "image/webp", ".jpg": "image/jpeg"}


def resolve_under(root, rel):
    """The file `rel` names under `root`, or None when it would leave it (.., an absolute path, a NUL, a symlink that points out)."""
    if not isinstance(rel, str) or "\0" in rel or rel.startswith(("/", "\\")):
        return None
    root = Path(root).resolve()
    try:
        found = (root / rel).resolve()
    except (OSError, ValueError, RuntimeError):
        return None
    if found != root and root not in found.parents:
        return None
    return found


def scan_creatures(content):
    """One entry per creatures/<id>/page.json for the index; a page that does not parse is reported by name instead of dropped."""
    flags = feedback.latest_flags(content)
    try:
        folders = sorted(p for p in (Path(content) / "creatures").iterdir() if p.is_dir())
    except OSError:
        return []
    out = []
    for folder in folders:
        page = folder / "page.json"
        if not page.is_file():
            continue
        rel = "creatures/%s/page.json" % folder.name
        try:
            data = json.loads(page.read_text())
            if not isinstance(data, dict):
                raise ValueError("a page is a JSON object")
        except (OSError, ValueError) as err:
            out.append({"id": folder.name, "title": folder.name, "error": "%s: %s" % (rel, err)})
            continue
        out.append({"id": folder.name, "title": data.get("title", folder.name), "species": data.get("species"), "stage": data.get("stage"),
                    "parent": data.get("parent"), "updated": data.get("updated"), "flag": flags.get(folder.name)})
    return out


class Handler(BaseHTTPRequestHandler):
    server_version = "review"

    def log_message(self, *args):
        pass

    # ---- replies ----
    def _send(self, status, body, ctype):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, data, status=200):
        self._send(status, json.dumps(data).encode(), "application/json")

    def _error(self, status, message=None):
        self._json({"error": message or {404: "not found"}.get(status, "error")}, status)

    def _file(self, root, rel):
        found = resolve_under(root, rel)
        if found is None or not found.is_file():
            return self._error(404)
        ctype = TYPES.get(found.suffix.lower()) or mimetypes.guess_type(found.name)[0] or "application/octet-stream"
        if ctype.startswith("text/") or ctype in ("application/json", "image/svg+xml"):
            ctype += "; charset=utf-8"
        try:
            body = found.read_bytes()
        except OSError:
            return self._error(404)
        self._send(200, body, ctype)

    # ---- routes ----
    def _from_this_server(self):
        """A page of ours asks for this server by the name it listens on. A rebound hostname (an attacker's site pointed at 127.0.0.1) arrives with its own Host."""
        if (self.headers.get("Host") or "").lower() in self.server.allowed_hosts:
            return True
        self._error(421, "unexpected Host")
        return False

    def do_GET(self):
        if not self._from_this_server():
            return
        path = urlsplit(self.path).path
        if path == "/":
            return self._file(self.server.app, "index.html")
        if path.startswith("/app/"):
            return self._file(self.server.app, unquote(path[len("/app/"):]))
        if path.startswith("/content/"):
            return self._file(self.server.content, unquote(path[len("/content/"):]))
        if path == "/api/creatures":
            return self._json(scan_creatures(self.server.content))
        if path == "/api/feedback":
            return self._json(feedback.entries(self.server.content))
        if path == "/events":
            return self._events()
        self._error(404)

    def do_POST(self):
        self.close_connection = True
        if not self._from_this_server():
            return
        origin = self.headers.get("Origin")
        if origin is not None and origin.lower() not in {"http://" + h for h in self.server.allowed_hosts}:
            return self._error(403, "a note can only be left from this page")
        if urlsplit(self.path).path != "/api/feedback":
            return self._error(404)
        if not (self.headers.get("Content-Type") or "").startswith("application/json"):
            return self._error(415, "send application/json")
        try:
            length = int(self.headers.get("Content-Length") or 0)
        except ValueError:
            return self._error(400, "bad Content-Length")
        if length > MAX_BODY:
            return self._error(413, "at most %d bytes" % MAX_BODY)
        try:
            entry = json.loads(self.rfile.read(length) or b"null")
            if not isinstance(entry, dict):
                raise ValueError("send a JSON object")
            stored = feedback.append(self.server.content, entry)
        except ValueError as err:
            return self._error(400, str(err))
        self._json(stored, 201)

    def _events(self):
        q = self.server.watcher.subscribe()
        try:
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(b": connected\n\n")
            self.wfile.flush()
            last = time.monotonic()
            while not self.server.closing.is_set():
                try:
                    event = q.get(timeout=0.5)
                except queue.Empty:
                    if time.monotonic() - last >= KEEPALIVE:
                        self.wfile.write(b": keepalive\n\n")
                        self.wfile.flush()
                        last = time.monotonic()
                    continue
                self.wfile.write(("data: %s\n\n" % json.dumps(event)).encode())
                self.wfile.flush()
                last = time.monotonic()
        except OSError:
            pass   # the page went away
        finally:
            self.server.watcher.unsubscribe(q)
            self.close_connection = True


class ReviewServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, content, app, port=0, settle=0.15, interval=0.25):
        super().__init__(("127.0.0.1", port), Handler)
        self.content, self.app = Path(content), Path(app)
        self.content.mkdir(parents=True, exist_ok=True)
        self.allowed_hosts = {"127.0.0.1:%d" % self.port, "localhost:%d" % self.port}
        self.closing = threading.Event()
        self.watcher = Watcher({"content": self.content, "app": self.app}, settle=settle, interval=interval)
        self._thread = None

    @property
    def port(self):
        return self.server_address[1]

    def serve_background(self):
        self.watcher.start()
        self._thread = threading.Thread(target=self.serve_forever, name="review-server", daemon=True)
        self._thread.start()

    def close(self):
        self.closing.set()
        if self._thread is not None:
            self.shutdown()
            self._thread.join(timeout=2.0)
        self.server_close()
        self.watcher.stop()


def make_server(content, app, port=0, settle=0.15, interval=0.25):
    return ReviewServer(content, app, port, settle, interval)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--content", type=Path, default=DEFAULT_CONTENT)
    ap.add_argument("--app", type=Path, default=APP)
    ap.add_argument("--port", type=int, help="default: the first free port from %d" % FIRST_PORT)
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args(argv)
    srv = None
    for port in ([args.port] if args.port else range(FIRST_PORT, FIRST_PORT + 100)):
        try:
            srv = make_server(args.content, args.app, port)
            break
        except OSError as err:
            if err.errno != errno.EADDRINUSE:
                raise
    if srv is None:
        sys.exit("no free port")
    url = "http://127.0.0.1:%d/" % srv.port
    (args.content / "server.json").write_text(json.dumps({"port": srv.port, "url": url, "pid": os.getpid()}))
    print("review page: %s  (content: %s)" % (url, args.content), flush=True)
    if not args.no_open:
        webbrowser.open(url)
    srv.watcher.start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.close()


if __name__ == "__main__":
    main()
