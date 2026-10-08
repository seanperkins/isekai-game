"""The review app's server: a real server on a free port, real files, real HTTP."""
import http.client
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import server  # noqa: E402


class ResolveTest(unittest.TestCase):
    def test_resolve_under_refuses_parent_absolute_encoded_and_symlink_escapes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root, outside = Path(tmp, "root"), Path(tmp, "outside")
            root.mkdir()
            outside.mkdir()
            (root / "a.txt").write_text("a")
            (outside / "secret.txt").write_text("secret")
            os.symlink(outside, root / "link")
            self.assertEqual(server.resolve_under(root, "a.txt"), (root / "a.txt").resolve())
            for bad in ("../outside/secret.txt", "a/../../outside/secret.txt", "/etc/passwd", "link/secret.txt", "a.txt\0", "..", "%2e%2e/outside"):
                with self.subTest(rel=bad):
                    found = server.resolve_under(root, bad)
                    self.assertTrue(found is None or not found.exists(), bad)
            self.assertIsNone(server.resolve_under(root, "../outside/secret.txt"))
            self.assertIsNone(server.resolve_under(root, "link/secret.txt"))


class ServerTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        base = Path(self._tmp.name)
        self.content, self.app = base / "content", base / "app"
        self.content.mkdir()
        self.app.mkdir()
        (base / "secret.txt").write_text("secret")
        (self.app / "index.html").write_text("<!doctype html><title>review</title>")
        (self.app / "app.js").write_text("export {};")
        self.server = server.make_server(self.content, self.app, port=0, settle=0.05, interval=0.02)
        self.server.serve_background()
        self.addCleanup(self.server.close)

    def request(self, method, path, body=None, headers=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.port, timeout=5)
        conn.request(method, path, body=body, headers=headers or {})
        resp = conn.getresponse()
        data = resp.read()
        conn.close()
        return resp.status, resp, data

    def page(self, creature, text):
        folder = self.content / "creatures" / creature
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "page.json").write_text(text)

    def test_serves_app_and_content_with_the_right_types(self):
        (self.content / "creatures" / "x").mkdir(parents=True)
        for name, data in (("page.json", b"{}"), ("model.glb", b"glTF"), ("a.png", b"\x89PNG")):
            (self.content / "creatures" / "x" / name).write_bytes(data)
        for path, ctype in (("/", "text/html"), ("/app/app.js", "text/javascript"), ("/content/creatures/x/page.json", "application/json"),
                            ("/content/creatures/x/model.glb", "model/gltf-binary"), ("/content/creatures/x/a.png", "image/png")):
            with self.subTest(path=path):
                status, resp, _ = self.request("GET", path)
                self.assertEqual(status, 200)
                self.assertTrue(resp.getheader("Content-Type").startswith(ctype), resp.getheader("Content-Type"))
                self.assertEqual(resp.getheader("Cache-Control"), "no-store")

    def test_a_missing_file_is_404_and_a_traversal_is_404_not_a_leak(self):
        for path in ("/content/nope.json", "/content/../secret.txt", "/content/%2e%2e/secret.txt", "/content/..%2fsecret.txt", "/app/../secret.txt", "/content//etc/passwd"):
            with self.subTest(path=path):
                status, _, data = self.request("GET", path)
                self.assertEqual(status, 404)
                self.assertNotIn(b"secret", data)

    def test_scan_creatures_lists_pages_and_reports_a_broken_one_by_name(self):
        self.page("goblin_hob", json.dumps({"id": "goblin_hob", "title": "Hob", "species": "goblin", "stage": 2, "parent": "goblin", "updated": "2026-10-08T17:30:00Z", "blocks": []}))
        self.page("broken", '{"id":')
        found = {c["id"]: c for c in server.scan_creatures(self.content)}
        self.assertEqual({k: found["goblin_hob"][k] for k in ("title", "species", "stage", "parent", "updated")},
                         {"title": "Hob", "species": "goblin", "stage": 2, "parent": "goblin", "updated": "2026-10-08T17:30:00Z"})
        self.assertIn("creatures/broken/page.json", found["broken"]["error"])
        status, _, data = self.request("GET", "/api/creatures")
        self.assertEqual((status, sorted(c["id"] for c in json.loads(data))), (200, ["broken", "goblin_hob"]))

    def test_post_feedback_validates_appends_and_returns_the_entry(self):
        good = json.dumps({"creature": "goblin_hob", "clip": "walk", "flag": "wrong", "note": "upper body"})
        status, _, data = self.request("POST", "/api/feedback", good, {"Content-Type": "application/json"})
        self.assertEqual(status, 201)
        self.assertEqual((json.loads(data)["id"], json.loads(data)["flag"]), (1, "wrong"))
        bad_flag = json.dumps({"creature": "goblin_hob", "flag": "meh", "note": ""})
        self.assertEqual(self.request("POST", "/api/feedback", bad_flag, {"Content-Type": "application/json"})[0], 400)
        self.assertEqual(self.request("POST", "/api/feedback", "x" * 5000, {"Content-Type": "application/json"})[0], 413)
        self.assertEqual(self.request("POST", "/api/feedback", good, {"Content-Type": "text/plain"})[0], 415)
        self.assertEqual(self.request("POST", "/api/feedback", "not json", {"Content-Type": "application/json"})[0], 400)

    def test_get_feedback_lists_entries(self):
        for creature in ("a", "b"):
            self.request("POST", "/api/feedback", json.dumps({"creature": creature, "flag": "ok", "note": ""}), {"Content-Type": "application/json"})
        status, _, data = self.request("GET", "/api/feedback")
        self.assertEqual((status, [e["creature"] for e in json.loads(data)]), (200, ["a", "b"]))

    def test_a_touched_content_file_arrives_on_the_event_stream(self):
        conn = http.client.HTTPConnection("127.0.0.1", self.server.port, timeout=5)
        conn.request("GET", "/events")
        resp = conn.getresponse()
        self.assertTrue(resp.getheader("Content-Type").startswith("text/event-stream"))
        self.page("x", "{}")
        line = b""
        while not line.startswith(b"data:"):
            line = resp.readline()
            self.assertNotEqual(line, b"", "the stream closed before an event")
        conn.close()
        self.assertEqual(json.loads(line[5:]), {"type": "content", "path": "creatures/x/page.json"})

    def test_a_feedback_line_missing_its_fields_does_not_take_down_the_index(self):
        (self.content / "feedback.jsonl").write_text('{"id": 3}\n')
        self.page("x", json.dumps({"id": "x", "title": "X", "blocks": []}))
        status, _, data = self.request("GET", "/api/creatures")
        self.assertEqual((status, [c["id"] for c in json.loads(data)]), (200, ["x"]))

    def test_a_request_whose_host_is_not_this_server_is_refused_so_a_rebound_name_cannot_read_it(self):
        self.page("x", "{}")
        for host in ("evil.example", "evil.example:%d" % self.server.port, "127.0.0.1.evil.example:%d" % self.server.port, "127.0.0.1:1", ""):
            for path in ("/api/creatures", "/api/feedback", "/content/creatures/x/page.json", "/events", "/"):
                with self.subTest(host=host, path=path):
                    status, _, data = self.request("GET", path, headers={"Host": host})
                    self.assertEqual(status, 421)
                    self.assertNotIn(b"creatures", data.replace(b'"error"', b""))
        for host in ("127.0.0.1:%d" % self.server.port, "localhost:%d" % self.server.port):
            self.assertEqual(self.request("GET", "/api/creatures", headers={"Host": host})[0], 200, host)

    def test_a_feedback_post_from_another_origin_is_refused(self):
        body = json.dumps({"creature": "goblin_hob", "flag": "ok", "note": ""})
        mine = "http://127.0.0.1:%d" % self.server.port
        for origin, expected in ((mine, 201), ("http://localhost:%d" % self.server.port, 201), ("http://evil.example", 403), ("null", 403), (None, 201)):
            headers = {"Content-Type": "application/json"}
            if origin is not None:
                headers["Origin"] = origin
            with self.subTest(origin=origin):
                self.assertEqual(self.request("POST", "/api/feedback", body, headers)[0], expected)

    def test_the_server_binds_only_to_localhost(self):
        self.assertEqual(self.server.server_address[0], "127.0.0.1")


if __name__ == "__main__":
    unittest.main()
