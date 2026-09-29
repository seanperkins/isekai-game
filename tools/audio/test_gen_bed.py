import http.server
import math
import os
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import gen_bed  # noqa: E402

MUSIC = {"provider": "synth", "dur": 8.0, "notes": [130.81, 196.0], "lfo": 0.1}
AMBIENCE = {"provider": "synth", "dur": 8.0, "lp": 900, "lfo": 0.05}


class GenBedTest(unittest.TestCase):
    def _lufs(self, stereo):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "b.wav")
            a.write_wav(p, stereo)
            return a.measure_lufs(p)

    def test_a_music_bed_lands_on_its_loudness_target(self):
        out = gen_bed.process(gen_bed.raw_samples(MUSIC, "t", "music"), "music")
        self.assertAlmostEqual(self._lufs(out), a.TARGET_LUFS["music"], delta=1.0)

    def test_an_ambience_bed_lands_on_its_loudness_target(self):
        out = gen_bed.process(gen_bed.raw_samples(AMBIENCE, "t", "ambience"), "ambience")
        self.assertAlmostEqual(self._lufs(out), a.TARGET_LUFS["ambience"], delta=1.0)

    def test_a_bed_loops_without_a_click_and_stays_under_the_ceiling(self):
        left, right = gen_bed.process(gen_bed.raw_samples(MUSIC, "t", "music"), "music")
        self.assertLess(a.seam_ratio(left), 3.0)
        self.assertLess(a.seam_ratio(right), 3.0)
        self.assertLessEqual(a.lin_to_db(a.peak(left)), a.PEAK_CEILING_DB - 0.5)

    def test_an_encoded_bed_still_loops_without_a_click(self):
        # Vorbis zero-pads the end of a stream; a bed that ends mid-wave would decode with a
        # jump from its tail back to its head, so the encoded file is what must wrap cleanly.
        spec = {"provider": "synth", "dur": 24.0, "notes": [130.81, 196.0, 261.63, 329.63], "lfo": 0.08}  # the cave bed
        with tempfile.TemporaryDirectory() as d:
            gen_bed.build("cave", "music", spec, d)
            left, right = a.decode_pcm(os.path.join(d, "music", "cave.ogg"))
        self.assertLess(a.seam_ratio(left), 3.0)
        self.assertLess(a.seam_ratio(right), 3.0)

    def test_the_synth_provider_is_reproducible(self):
        one = gen_bed.raw_samples(MUSIC, "t", "music")
        self.assertEqual(one, gen_bed.raw_samples(MUSIC, "t", "music"))

    def test_an_unknown_provider_fails(self):
        with self.assertRaises(a.AudioToolError):
            gen_bed.raw_samples({"provider": "nope"}, "t", "music")

    def test_the_local_provider_names_the_file_it_needs(self):
        with self.assertRaises(a.AudioToolError) as ctx:
            gen_bed.raw_samples({"provider": "local", "file": "art_source/audio/raw/missing.wav"}, "t", "music")
        self.assertIn("art_source/audio/raw/missing.wav", str(ctx.exception))

    def test_build_writes_a_valid_ogg_and_a_failure_leaves_none(self):
        with tempfile.TemporaryDirectory() as d:
            gen_bed.build("t", "music", MUSIC, d)
            info = a.validate_ogg(os.path.join(d, "music", "t.ogg"))
            self.assertGreater(info["duration"], 5.5)
            with self.assertRaises(a.AudioToolError):
                gen_bed.build("u", "music", {"provider": "nope"}, d)
            self.assertFalse(os.path.exists(os.path.join(d, "music", "u.ogg")))

    def test_elevenlabs_needs_the_key_in_the_environment(self):
        old = os.environ.pop("ELEVENLABS_API_KEY", None)
        try:
            with self.assertRaises(a.AudioToolError) as ctx:
                gen_bed.raw_samples({"provider": "elevenlabs", "seconds": 30, "prompt": "x"}, "t", "music")
            self.assertIn("ELEVENLABS_API_KEY", str(ctx.exception))
        finally:
            if old is not None:
                os.environ["ELEVENLABS_API_KEY"] = old

    def test_elevenlabs_rejects_a_length_the_api_would_refuse_before_calling_it(self):
        os.environ["ELEVENLABS_API_KEY"] = "test-key"
        try:
            for kind, seconds in (("music", 1), ("music", 700), ("ambience", 0.1), ("ambience", 31)):
                def boom(url, headers, body):
                    raise AssertionError("must not call the API")
                with self.assertRaises(a.AudioToolError, msg="%s %s" % (kind, seconds)):
                    gen_bed.raw_samples({"provider": "elevenlabs", "seconds": seconds, "prompt": "x"},
                                        "t", kind, fetch=boom)
        finally:
            del os.environ["ELEVENLABS_API_KEY"]

    def test_elevenlabs_saves_the_raw_response_and_decodes_it(self):
        calls = []

        def fake_fetch(url, headers, body):
            calls.append((url, headers, body))
            with tempfile.TemporaryDirectory() as d:
                p = os.path.join(d, "x.wav")
                a.write_wav(p, [0.2 * math.sin(i / 20.0) for i in range(44100)])
                with open(p, "rb") as f:
                    return f.read()

        os.environ["ELEVENLABS_API_KEY"] = "test-key"
        try:
            with tempfile.TemporaryDirectory() as d:
                spec = {"provider": "elevenlabs", "seconds": 5, "prompt": "warm cave pads"}
                samples = gen_bed.raw_samples(spec, "t", "music", raw_dir=d, fetch=fake_fetch)
                self.assertEqual(len(calls), 1)
                self.assertEqual(calls[0][0], "https://api.elevenlabs.io/v1/music")
                self.assertEqual(calls[0][1]["xi-api-key"], "test-key")
                self.assertIn("warm cave pads", calls[0][2])
                self.assertIn('"force_instrumental": true', calls[0][2])
                self.assertTrue(os.path.exists(os.path.join(d, "t_music.mp3")))
                self.assertEqual(len(samples), 2)
                gen_bed.raw_samples(dict(spec, seconds=10), "t", "ambience", raw_dir=d, fetch=fake_fetch)
                self.assertEqual(calls[1][0], "https://api.elevenlabs.io/v1/sound-generation")
                self.assertIn('"loop": true', calls[1][2])
        finally:
            del os.environ["ELEVENLABS_API_KEY"]

    def test_a_refused_request_reports_what_the_server_said(self):
        class Refuse(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                self.send_response(402)
                self.end_headers()
                self.wfile.write(b'{"detail":{"code":"paid_plan_required"}}')

            def log_message(self, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Refuse)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        try:
            with self.assertRaises(a.AudioToolError) as ctx:
                gen_bed._fetch("http://127.0.0.1:%d/x" % server.server_port, {}, "{}")
        finally:
            server.shutdown()
            server.server_close()
        self.assertIn("402", str(ctx.exception))
        self.assertIn("paid_plan_required", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
