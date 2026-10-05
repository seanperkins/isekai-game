import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import gen_bed  # noqa: E402
import score  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BATTLE = os.path.join(ROOT, "art_source", "audio", "scores", "opening_battle.json")

LEAD = {"wave": "pulse", "duty": 0.5, "attack": 0.001, "decay": 2.0, "sustain": 1.0, "release": 0.5, "gain": 0.5, "pan": 0.0}
TINY = {
    "bpm": 120, "beats_per_bar": 4, "steps_per_bar": 16, "bars": 2,
    "chords": {"Am": ["A", "C", "E"]},
    "progression": ["Am", "Am"],
    "voices": {"lead": LEAD},
    "tracks": {"lead": {"voice": "lead", "bars": [". . . . . . . . . . . . . . . .", ". . . . . . . . . . . . . . . A4"]}},
}


class NotesTest(unittest.TestCase):
    def test_note_names_give_their_pitch(self):
        self.assertEqual(score.note_to_midi("A4"), 69)
        self.assertEqual(score.note_to_midi("C5"), 72)
        self.assertEqual(score.note_to_midi("G#5"), 80)
        self.assertEqual(score.note_to_midi("Bb3"), 58)
        self.assertAlmostEqual(score.midi_to_hz(69), 440.0)
        self.assertAlmostEqual(score.midi_to_hz(81), 880.0)

    def test_a_bad_note_name_is_an_error(self):
        for bad in ["H4", "A", "4A", "A#", ""]:
            with self.assertRaises(a.AudioToolError, msg=bad):
                score.note_to_midi(bad)

    def test_a_ladder_climbs_through_the_chord(self):
        am = score.ladder(["A", "C", "E"], 3)
        self.assertEqual(am[:4], [score.note_to_midi(n) for n in ["A3", "C4", "E4", "A4"]])
        self.assertEqual(sorted(am), am)
        f = score.ladder(["F", "A", "C"], 3)
        self.assertEqual(f[:4], [score.note_to_midi(n) for n in ["F3", "A3", "C4", "F4"]])


class RenderTest(unittest.TestCase):
    def test_the_loop_is_exactly_the_bars_long(self):
        left, right = score.render(TINY)
        self.assertEqual(len(left), len(right))
        self.assertEqual(len(left), round(2 * 16 * (60.0 / 120 / 4) * a.RATE))

    def test_it_is_reproducible(self):
        self.assertEqual(score.render(TINY), score.render(TINY))

    def test_a_note_that_rings_past_the_end_wraps_onto_the_start(self):
        left, _ = score.render(TINY)
        self.assertGreater(max(abs(s) for s in left[:2000]), 0.01, "the loop is seamless: the tail is on the head")

    def test_a_note_that_wraps_adds_nothing_past_the_loop_length(self):
        left, _ = score.render(TINY)
        self.assertEqual(len(left), round(2 * 16 * 0.125 * a.RATE))

    def test_pan_puts_a_voice_left_or_right(self):
        hard_left = json.loads(json.dumps(TINY))
        hard_left["voices"]["lead"]["pan"] = -1.0
        left, right = score.render(hard_left)
        self.assertGreater(max(map(abs, left)), 5 * max(map(abs, right)))

    def test_the_output_never_exceeds_full_scale(self):
        loud = json.loads(json.dumps(TINY))
        loud["voices"]["lead"]["gain"] = 20.0
        left, right = score.render(loud)
        self.assertLessEqual(max(max(map(abs, left)), max(map(abs, right))), 1.0)

    def test_a_malformed_bar_is_an_error_not_a_crash(self):
        bad = json.loads(json.dumps(TINY))
        bad["tracks"]["lead"]["bars"][0] = "A4 - -"
        with self.assertRaises(a.AudioToolError):
            score.render(bad)
        bad = json.loads(json.dumps(TINY))
        bad["progression"] = ["Am", "Zz"]
        with self.assertRaises(a.AudioToolError):
            score.render(bad)
        bad = json.loads(json.dumps(TINY))
        bad["tracks"]["lead"]["bars"].pop()
        with self.assertRaises(a.AudioToolError):
            score.render(bad)

    def test_a_drum_pattern_renders_hits(self):
        drums = json.loads(json.dumps(TINY))
        drums["tracks"] = {"drums": {"kind": "drums", "patterns": {"beat": {"kick": "k...............", "snare": "....s...........", "hat": "h.h.h.h.h.h.h.h."}},
                                     "bars": ["beat", "beat"]}}
        left, right = score.render(drums)
        self.assertGreater(a.peak(left), 0.05)
        self.assertGreater(a.peak(right), 0.05)


class BattleScoreTest(unittest.TestCase):
    """The shipped battle theme: musically sane, checked by rule since nobody can hear it in a test."""

    @classmethod
    def setUpClass(cls):
        with open(BATTLE) as f:
            cls.spec = json.load(f)

    def test_it_is_thirty_two_bars_with_a_chord_for_each(self):
        s = self.spec
        self.assertEqual(s["bars"], 32)
        self.assertEqual(len(s["progression"]), 32)
        for chord in s["progression"]:
            self.assertIn(chord, s["chords"])
        self.assertEqual(len(s["tracks"]["lead"]["bars"]), 32)
        self.assertEqual(len(s["tracks"]["drums"]["bars"]), 32)

    def test_every_lead_bar_is_sixteen_steps(self):
        for i, bar in enumerate(self.spec["tracks"]["lead"]["bars"]):
            self.assertEqual(len(bar.split()), self.spec["steps_per_bar"], "bar %d: %r" % (i + 1, bar))

    def test_the_lead_stays_in_a_minor_with_the_leading_tone(self):
        allowed = {"A", "B", "C", "D", "E", "F", "G", "G#"}
        for i, bar in enumerate(self.spec["tracks"]["lead"]["bars"]):
            for token in bar.split():
                if token not in ("-", "."):
                    self.assertIn(token[:-1], allowed, "bar %d: %s" % (i + 1, token))

    def test_the_lead_lands_on_chord_tones_on_the_beat(self):
        s = self.spec
        for i, bar in enumerate(s["tracks"]["lead"]["bars"]):
            tones = set(s["chords"][s["progression"][i]])
            for step, token in enumerate(bar.split()):
                if step % 4 == 0 and token not in ("-", "."):
                    self.assertIn(token[:-1], tones, "bar %d step %d: %s over %s" % (i + 1, step, token, s["progression"][i]))

    def test_the_lead_stays_in_a_singable_range(self):
        low, high = score.note_to_midi("A3"), score.note_to_midi("E6")
        for bar in self.spec["tracks"]["lead"]["bars"]:
            for token in bar.split():
                if token not in ("-", "."):
                    self.assertTrue(low <= score.note_to_midi(token) <= high, token)

    def test_every_drum_pattern_is_sixteen_steps_and_every_named_one_exists(self):
        drums = self.spec["tracks"]["drums"]
        for name, pattern in drums["patterns"].items():
            for lane, steps in pattern.items():
                self.assertEqual(len(steps), self.spec["steps_per_bar"], "%s/%s" % (name, lane))
        for name in drums["bars"]:
            self.assertIn(name, drums["patterns"])

    def test_the_theme_is_about_forty_five_seconds(self):
        s = self.spec
        seconds = s["bars"] * s["beats_per_bar"] * 60.0 / s["bpm"]
        self.assertTrue(30.0 <= seconds <= 60.0, seconds)

    def test_it_renders_to_a_loop_that_gen_bed_can_use(self):
        raw = gen_bed.raw_samples({"provider": "score", "file": BATTLE}, "opening_battle", "music")
        left, right = raw
        s = self.spec
        self.assertEqual(len(left), round(s["bars"] * s["steps_per_bar"] * 60.0 / s["bpm"] / (s["steps_per_bar"] / s["beats_per_bar"]) * a.RATE))
        out = gen_bed.process(raw, "music", seamless=True)
        self.assertEqual(len(out[0]), len(left), "a seamless score is not shortened by a crossfade")
        with tempfile.TemporaryDirectory() as d:
            gen_bed.build("opening_battle", "music", {"provider": "score", "file": BATTLE}, d)
            path = os.path.join(d, "music", "opening_battle.ogg")
            self.assertAlmostEqual(a.measure_lufs(path), a.TARGET_LUFS["music"], delta=a.LUFS_TOLERANCE)
            dl, dr = a.decode_pcm(path)
            self.assertLess(a.seam_ratio(dl), 3.0)
            self.assertLess(a.seam_ratio(dr), 3.0)
            self.assertLessEqual(a.lin_to_db(max(a.peak(dl), a.peak(dr))), a.PEAK_CEILING_DB)


if __name__ == "__main__":
    unittest.main()
