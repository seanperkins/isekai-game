# Polished Sound Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the game a cohesive soundscape: a cue for every player, enemy, world and UI moment, a music loop and an ambience bed per biome, and a per-bus mix with settings sliders.

**Architecture:** A single `Audio` autoload is the only place events become sound. Gameplay emits semantic events (`EventBus.game_event`, a new non-counted `EventBus.world_event`) and never names a cue; `data/audio/cues.json` maps events to cues and holds per-biome beds. The logic (catalog, voice pool, combo pitch, one-shot scheduler, settings) is pure `RefCounted` code with injected clock and RNG so it tests headless. Assets come from a stdlib-only Python pipeline: procedural SFX synthesis plus a loop-safe bed generator, both encoding Ogg Vorbis through ffmpeg.

**Tech Stack:** Godot 4.7 (GDScript, GUT), Python 3 standard library, ffmpeg/ffprobe (native `vorbis` encoder, `ebur128` filter).

**Spec:** `docs/superpowers/specs/2026-09-28-polished-sound-design.md`. Read it with this plan. Where the plan differs from it, the difference is listed under "Deviations" and written back into the spec in Task 13.

## Global Constraints

Copied from the spec unless marked (plan).

- Godot 4.7, GDScript, 640×360 viewport. New `.gd` files get a sibling `.gd.uid` from the next `godot --headless --import`; commit both.
- Buses: `Master` → `Music`, `Ambience`, `SFX_Player`, `SFX_Enemy`, `SFX_World` (reverb), `UI`. Limiter on Master. Music bus carries an `AudioEffectAmplify` used as the duck.
- Voice pool: 16 voices. Crossfade between biomes: 2 s, equal power. Duck: −4 dB, 0.15 s attack, 0.6 s release, while a stinger plays or the skill screen is open.
- Loops are seamless. Music targets about −20 LUFS, ambience about −24 LUFS (±2 LU). Nothing peaks above −1 dBTP (measured as sample peak after encoding).
- Gameplay code never contains a cue id, a bus name or a file path, and never calls `Audio.play*`. Gameplay emits `EventBus.world_event.emit("name", {tags})`. All event-to-cue routing lives in the `events` section of `data/audio/cues.json`.
- `EventBus.world_event` is never counted by `SkillRules` or the `Compendium`; only `Audio` listens.
- Every event name in `Events.ALL`, every emitted `world_event` name and the three `SkillRules` signals (`skill_unlocked`, `skill_leveled`, `evolution_ready`) has an `events` entry: a cue, or `null` with a `"_why:<event>"` comment.
- Settings: Master, Music, Ambience, SFX sliders, 0–100, default 80, stored as linear 0–1 in the `Profile` under `audio`. A malformed section resets to defaults.
- Skill screen tabs: five tabs at `x = 28 + i * 102`, width 96 (`skill_screen.gd:216`), last tab's right edge under 612.
- Asset tools exit non-zero on failure, write to a temp file, validate (`ffprobe` reads Ogg Vorbis, duration above zero), then rename. A failed run leaves no partial file.
- `art_source/audio/raw/` is gitignored (provider output). Built `.ogg` files, recipes and bed specs are committed.
- (plan) Run Python tools from the project root with a project-local temp dir: `TMPDIR="$PWD/.tmp/audio-work"` (create it first). Tools use only the Python standard library.
- (plan) Godot commands, verbatim from the repo's conventions: import with `mkdir -p .tmp/test-logs .tmp/gdhome && gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1`; run tests with `tools/run_tests.sh <file-substring>`; full suite with `tools/run_tests.sh`. Judge results by the runner's `PASS`/`FAIL` line, never by exit code alone.
- (plan) Python tests: `python3 -m unittest discover -s tools/audio -p "test_*.py" -v` from the project root.
- (plan) Commit messages use the repo's `feat:` / `test:` / `docs:` style and carry no attribution lines.

## Deviations from the spec (written back into the spec in Task 13)

1. **SFX loudness.** SFX are peak-normalised to −2 dBFS and balanced by each cue's `volume_db`, not targeted at −16 LUFS: LUFS is meaningless for 100 ms clips and clicky sounds cannot reach −16 LUFS under a −1 dBTP ceiling. Music and ambience keep their LUFS targets.
2. **Loudness and loop-seam tests are Python.** They need PCM samples, which headless Godot cannot give. They live in `tools/audio/test_*.py`, not `tests/`. The GDScript tests cover the catalog, events, pool, settings and routing.
3. **Stereo Ogg.** The only Vorbis encoder here is ffmpeg's native experimental one, which supports two channels. Mono sources are duplicated to stereo. Godot imports and plays the result (verified with a probe).
4. **Placeholder beds.** Music and ambience beds are first rendered by a built-in synth "provider" so the game and tests work without an API key. Task 14 adds the ElevenLabs provider and is blocked on Sean's key.
5. **Water enter/exit.** No swim mechanic or water zone exists yet. `water_entered` / `water_exited` are catalogued (cues and events exist and are tested) but nothing emits them until Swim lands.
6. **Crystal chime.** Replaced by the ambience one-shots `amb_crystal_ping` and `amb_hum`. There is no separate "near glow" cue.
7. **Enemy families.** `enemy_died` carries the creature `id`; the catalog maps ids to four death cues (flyer: bat, crawler: spider, beast: toad and lizard, boss: serpent).

## Review Focus

Failure modes the spec implies but its tests do not exercise, most likely first. Each has a test in the task that owns the code.

1. **A run restart or death reload leaves loops running or restarts the music.** The `Audio` autoload survives `reload_current_scene`. Heartbeat, run and wall-slide loops must stop on death and on run start; re-entering the same biome must not restart the bed. Tests in Tasks 8, 9 and 12.
2. **An absorb burst machine-guns.** `absorbed` fires once per essence unit, like `mana_spent` per MP point. The cue needs a cooldown and combo pitch across bursts. Test in Tasks 6 and 8.
3. **A slider at 0 must mute, not `-inf` dB.** `linear_to_db(0)` is `-inf`. Test in Task 7.
4. **A missing or unloadable audio file must not crash the game.** It warns once and skips. Test in Task 8.
5. **The pause.** UI voices and the duck tween must run while the tree is paused; gameplay voices must pause with it. Test in Task 8.

## File Structure

| File | Responsibility |
|---|---|
| `tools/audio/audiolib.py` | PCM helpers, WAV and Ogg IO, loudness, seam metric, safe writes |
| `tools/audio/dsp.py` | Oscillators, noise, filters, envelopes, `render`, `make_loop`, pads |
| `tools/audio/synth_sfx.py` | Recipes → `assets/audio/sfx/*.ogg` |
| `tools/audio/gen_bed.py` | Bed specs → looped, loudness-set `assets/audio/{music,ambience}/<biome>.ogg` |
| `tools/audio/build_cues.py` | Recipes → the `cues` section of `data/audio/cues.json` |
| `tools/audio/build_bus_layout.gd` | Builds `default_bus_layout.tres` |
| `tools/audio/preview.gd`, `preview.tscn` | Audition every cue and biome |
| `tools/audio/test_*.py` | Python tests for the tools and the built assets |
| `art_source/audio/recipes/*.json` | SFX recipes and per-cue playback rules |
| `art_source/audio/beds/<biome>.json` | Bed specs and provider prompts |
| `data/audio/cues.json` | `cues` (generated), `events` and `biomes` (authored) |
| `assets/audio/{sfx,music,ambience}/*.ogg` | Built audio |
| `default_bus_layout.tres` | The bus layout |
| `scripts/audio/cue_catalog.gd` | Load, validate, route events, pick variants |
| `scripts/audio/voice_pool.gd` | Which voice plays next: cap, cooldown, steal quietest |
| `scripts/audio/combo_pitch.gd` | Pitch steps for rapid retriggers |
| `scripts/audio/oneshot_scheduler.gd` | Random ambience one-shots |
| `scripts/audio/audio_settings.gd` | Volume settings, bus application, persistence |
| `scripts/audio/music_director.gd` | Music and ambience crossfade |
| `autoload/audio.gd` | Event → cue, voices, duck, reverb, biome |
| `scripts/player/player_audio_events.gd` | Player physics state → landed / run / wall-slide events |
| `tests/test_audio_*.gd` | GUT tests |

Modified: `autoload/event_bus.gd`, `project.godot`, `.gitignore`, `scripts/persistence/profile.gd`, `scripts/player/player.gd`, `scripts/enemies/enemy.gd`, `scripts/world/{tablet,shortcut_switch,glow_pool}.gd`, `scripts/ui/{skill_screen,skill_screen_model,hud}.gd`, `scripts/game.gd`, `tests/test_skill_screen.gd`, `tests/test_autoloads.gd`, `docs/playtest-checklist.md`, the spec.

---

### Task 1: Python audio library and DSP

**Files:**
- Create: `tools/audio/audiolib.py`, `tools/audio/dsp.py`
- Test: `tools/audio/test_audiolib.py`, `tools/audio/test_dsp.py`

**Interfaces:**
- Produces (`audiolib`): `RATE`, `TARGET_LUFS`, `LUFS_TOLERANCE`, `SFX_PEAK_DB`, `PEAK_CEILING_DB`, `AudioToolError`, `db_to_lin`, `lin_to_db`, `to_stereo`, `peak`, `gain`, `normalize_peak(samples, db)`, `write_wav(path, samples)`, `probe(path)`, `validate_ogg(path)`, `encode_ogg(wav_path, out_path)`, `write_ogg(samples, out_path)`, `decode_pcm(path) -> (left, right)`, `measure_lufs(path)`, `seam_ratio(samples)`.
- Produces (`dsp`): `envelope(n, attack, decay)`, `osc(kind, n, f0, f1)`, `noise(kind, n, rng)`, `lowpass(x, cutoff)`, `highpass(x, cutoff)`, `tremolo(x, rate, depth)`, `render(recipe, seconds, seed, fade_edges=True)`, `make_loop(samples, seconds)`, `pad(notes, seconds, lfo_rate, rng)`, `wash(seconds, cutoff, lfo_rate, rng)`, `trim_silence(stereo, threshold_db=-50.0)`.
- Samples are lists of floats in [−1, 1]; a stereo value is a `(left, right)` tuple.

- [ ] **Step 1: Write the failing library tests**

Create `tools/audio/test_audiolib.py`:

```python
import math
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402


def sine(freq, seconds, amp=0.5):
    n = int(seconds * a.RATE)
    return [amp * math.sin(2 * math.pi * freq * i / a.RATE) for i in range(n)]


class AudioLibTest(unittest.TestCase):
    def test_normalize_peak_hits_the_target(self):
        out = a.normalize_peak(sine(440, 0.1, 0.25), -2.0)
        self.assertAlmostEqual(a.lin_to_db(a.peak(out)), -2.0, places=3)

    def test_normalize_peak_refuses_silence(self):
        with self.assertRaises(a.AudioToolError):
            a.normalize_peak([0.0] * 100, -2.0)

    def test_an_ogg_round_trips_as_stereo_vorbis(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "t.ogg")
            a.write_ogg(sine(440, 0.5), out)
            info = a.validate_ogg(out)
            self.assertEqual(info["channels"], 2)
            self.assertAlmostEqual(info["duration"], 0.5, delta=0.05)
            left, right = a.decode_pcm(out)
            self.assertEqual(len(left), len(right))
            self.assertGreater(a.peak(left), 0.3)

    def test_a_failed_encode_leaves_nothing_behind(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "sub", "t.ogg")
            with self.assertRaises(a.AudioToolError):
                a.encode_ogg(os.path.join(d, "missing.wav"), out)
            self.assertFalse(os.path.exists(out))
            self.assertFalse(os.path.exists(out + ".tmp.ogg"))

    def test_garbage_is_not_a_valid_ogg(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "bad.ogg")
            with open(p, "wb") as f:
                f.write(b"not audio")
            with self.assertRaises(a.AudioToolError):
                a.validate_ogg(p)

    def test_loudness_of_a_dual_mono_sine_matches_its_level(self):
        # EBU R128: a 1 kHz sine at -20 dBFS on both channels reads -20 LUFS.
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "s.wav")
            a.write_wav(p, sine(1000, 3.0, 0.1))
            self.assertAlmostEqual(a.measure_lufs(p), -20.0, delta=1.0)

    def test_seam_ratio_is_small_for_a_continuous_wrap_and_large_for_a_jump(self):
        self.assertLess(a.seam_ratio(sine(200, 1.0)), 1.5)  # exactly 200 cycles
        self.assertGreater(a.seam_ratio(sine(200, 1.00125)), 5.0)  # ends a quarter cycle in


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mkdir -p .tmp/audio-work && TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_audiolib.py" -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'audiolib'`.

- [ ] **Step 3: Write `audiolib.py`**

Create `tools/audio/audiolib.py`:

```python
"""Shared helpers for the audio tools: PCM math, WAV and Ogg IO, loudness and safe writes.

Everything works on float samples in [-1, 1]. A "stereo" value is a (left, right) tuple of lists;
a plain list is mono. ffmpeg's native Vorbis encoder is experimental and takes two channels only,
so mono is duplicated on the way out. Standard library only: run from the project root.
"""
import array
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import wave

RATE = 44100
TARGET_LUFS = {"music": -20.0, "ambience": -24.0}
LUFS_TOLERANCE = 2.0
SFX_PEAK_DB = -2.0       # SFX are peak-normalised; the catalog's volume_db balances them
PEAK_CEILING_DB = -1.0   # nothing built may peak above this once encoded


class AudioToolError(Exception):
    pass


def db_to_lin(db):
    return 10.0 ** (db / 20.0)


def lin_to_db(x):
    return 20.0 * math.log10(max(x, 1e-9))


def to_stereo(samples):
    return (samples, samples) if isinstance(samples, list) else samples


def peak(samples):
    return max((abs(s) for s in samples), default=0.0)


def gain(samples, db):
    g = db_to_lin(db)
    return [s * g for s in samples]


def normalize_peak(samples, target_db):
    p = peak(samples)
    if p <= 0.0:
        raise AudioToolError("cannot normalise silence")
    return gain(samples, target_db - lin_to_db(p))


def write_wav(path, samples, rate=RATE):
    left, right = to_stereo(samples)
    frames = array.array("h")
    for l, r in zip(left, right):
        frames.append(max(-32768, min(32767, int(round(l * 32767.0)))))
        frames.append(max(-32768, min(32767, int(round(r * 32767.0)))))
    if sys.byteorder == "big":
        frames.byteswap()
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(frames.tobytes())


def _run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, check=False)
    except FileNotFoundError as e:
        raise AudioToolError("%s is not installed" % cmd[0]) from e


def _text(b):
    return b.decode(errors="replace").strip()


def probe(path):
    r = _run(["ffprobe", "-v", "error", "-show_entries",
              "stream=codec_name,channels,sample_rate:format=duration", "-of", "json", path])
    if r.returncode != 0:
        raise AudioToolError("ffprobe failed for %s: %s" % (path, _text(r.stderr)))
    data = json.loads(r.stdout or b"{}")
    streams = data.get("streams") or []
    if not streams:
        raise AudioToolError("%s has no audio stream" % path)
    duration = float(data.get("format", {}).get("duration", 0.0) or 0.0)
    return {"codec": streams[0]["codec_name"], "channels": int(streams[0]["channels"]),
            "rate": int(streams[0]["sample_rate"]), "duration": duration}


def validate_ogg(path):
    info = probe(path)
    if info["codec"] != "vorbis" or info["duration"] <= 0.0:
        raise AudioToolError("%s is not a usable Ogg Vorbis file: %s" % (path, info))
    return info


def encode_ogg(wav_path, out_path):
    """Encode to Ogg Vorbis through a temp file, validate it, then rename into place.
    A failure leaves nothing at out_path."""
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    tmp = out_path + ".tmp.ogg"
    try:
        r = _run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", wav_path, "-ac", "2",
                  "-c:a", "vorbis", "-strict", "-2", "-q:a", "5", "-f", "ogg", tmp])
        if r.returncode != 0:
            raise AudioToolError("ffmpeg failed for %s: %s" % (out_path, _text(r.stderr)))
        validate_ogg(tmp)
        os.replace(tmp, out_path)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


def write_ogg(samples, out_path):
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "in.wav")
        write_wav(wav, samples)
        encode_ogg(wav, out_path)


def decode_pcm(path):
    """Any audio file to (left, right) float lists at RATE."""
    r = _run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-f", "s16le",
              "-ac", "2", "-ar", str(RATE), "-"])
    if r.returncode != 0:
        raise AudioToolError("ffmpeg could not decode %s: %s" % (path, _text(r.stderr)))
    pcm = array.array("h")
    pcm.frombytes(r.stdout)
    if sys.byteorder == "big":
        pcm.byteswap()
    left = [pcm[i] / 32768.0 for i in range(0, len(pcm), 2)]
    right = [pcm[i] / 32768.0 for i in range(1, len(pcm), 2)]
    return left, right


_LUFS = re.compile(r"I:\s+(-?\d+(?:\.\d+)?)\s+LUFS")


def measure_lufs(path):
    """Integrated loudness in LUFS (the summary line ebur128 prints last)."""
    r = _run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-filter_complex", "ebur128",
              "-f", "null", "-"])
    if r.returncode != 0:
        raise AudioToolError("ffmpeg could not measure %s: %s" % (path, _text(r.stderr)))
    found = _LUFS.findall(r.stderr.decode(errors="replace"))
    if not found:
        raise AudioToolError("no loudness reading for %s" % path)
    return float(found[-1])


def seam_ratio(samples):
    """How big the jump from the last sample back to the first is, against the loudest normal
    sample-to-sample step (the 99th percentile). Near or below 1 means the loop is seamless."""
    steps = sorted(abs(samples[i + 1] - samples[i]) for i in range(len(samples) - 1))
    typical = steps[int(len(steps) * 0.99)]
    return abs(samples[0] - samples[-1]) / max(typical, 1e-6)
```

- [ ] **Step 4: Run the library tests to verify they pass**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_audiolib.py" -v`
Expected: 7 tests OK. If the loudness test is off by more than 1 LU, print `a.measure_lufs(p)` and read the ffmpeg summary before changing the expected value; do not loosen the tolerance without understanding it.

- [ ] **Step 5: Write the failing DSP tests**

Create `tools/audio/test_dsp.py`:

```python
import math
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import dsp  # noqa: E402


def rms(x):
    return math.sqrt(sum(s * s for s in x) / len(x))


class DspTest(unittest.TestCase):
    def test_render_is_deterministic_for_a_seed(self):
        r = {"layers": [{"noise": "pink", "amp": 1.0, "env": [0.001, 0.05]}]}
        self.assertEqual(dsp.render(r, 0.1, 7), dsp.render(r, 0.1, 7))
        self.assertNotEqual(dsp.render(r, 0.1, 7), dsp.render(r, 0.1, 8))

    def test_envelope_rises_over_the_attack_then_decays(self):
        env = dsp.envelope(4410, 0.01, 0.05)
        self.assertEqual(env[0], 0.0)
        self.assertAlmostEqual(env[441], 1.0, places=6)
        self.assertLess(env[-1], env[441])

    def test_a_sine_oscillator_has_the_right_period(self):
        s = dsp.osc("sine", 200, 441.0, 441.0)  # 100 samples per period
        self.assertAlmostEqual(s[24], 1.0, places=3)
        self.assertAlmostEqual(s[99], 0.0, places=3)

    def test_lowpass_removes_high_frequency_energy(self):
        noise = dsp.noise("white", 20000, random.Random(1))
        self.assertLess(rms(dsp.lowpass(noise, 200.0)), 0.2 * rms(noise))

    def test_make_loop_wraps_without_a_jump_and_shortens_the_clip(self):
        x = [0.5 * math.sin(2 * math.pi * 220 * i / a.RATE) for i in range(a.RATE)]
        out = dsp.make_loop(x, 0.2)
        self.assertEqual(len(out), len(x) - int(0.2 * a.RATE))
        self.assertLess(a.seam_ratio(out), 2.0)

    def test_make_loop_rejects_a_clip_that_is_too_short(self):
        with self.assertRaises(ValueError):
            dsp.make_loop([0.0] * 1000, 0.2)

    def test_trim_silence_cuts_the_quiet_ends(self):
        quiet = [0.0] * 1000
        loud = [0.5] * 500
        left, right = dsp.trim_silence((quiet + loud + quiet, quiet + loud + quiet))
        self.assertEqual(len(left), 500)
        self.assertEqual(len(right), 500)

    def test_trim_silence_refuses_pure_silence(self):
        with self.assertRaises(a.AudioToolError):
            dsp.trim_silence(([0.0] * 100, [0.0] * 100))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 6: Run the DSP tests to verify they fail**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_dsp.py" -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'dsp'`.

- [ ] **Step 7: Write `dsp.py`**

Create `tools/audio/dsp.py`:

```python
"""Small synthesis kit: oscillators, noise, one-pole filters, envelopes, recipes and loops.

A recipe is {"dur": seconds, "detune": 0..1 (optional), "layers": [...]}. A layer is one of
  {"osc": sine|tri|square|saw, "f0": Hz, "f1": Hz (optional, exponential sweep)}
  {"noise": white|pink}
plus optional "lp"/"hp" (one-pole cutoff in Hz), "trem": [rate Hz, depth 0..1], "amp",
"delay" (seconds) and "env": [attack seconds, decay seconds to -60 dB].
"""
import math
import random

from audiolib import RATE, AudioToolError, lin_to_db, db_to_lin

DEFAULT_DETUNE = 0.03
EDGE_FADE = 0.005


def envelope(n, attack, decay, rate=RATE):
    a = max(1, int(attack * rate))
    k = math.log(1000.0) / max(decay * rate, 1.0)
    return [i / a if i < a else math.exp(-k * (i - a)) for i in range(n)]


def osc(kind, n, f0, f1, rate=RATE):
    out = []
    phase = 0.0
    for i in range(n):
        t = i / max(n - 1, 1)
        f = f0 * (f1 / f0) ** t if f0 > 0 and f1 > 0 else f0
        phase += f / rate
        p = phase % 1.0
        if kind == "sine":
            v = math.sin(2.0 * math.pi * p)
        elif kind == "tri":
            v = 4.0 * abs(p - 0.5) - 1.0
        elif kind == "square":
            v = 1.0 if p < 0.5 else -1.0
        elif kind == "saw":
            v = 2.0 * p - 1.0
        else:
            raise ValueError("unknown oscillator %r" % kind)
        out.append(v)
    return out


def noise(kind, n, rng):
    if kind == "white":
        return [rng.uniform(-1.0, 1.0) for _ in range(n)]
    if kind == "pink":  # Paul Kellet's economy filter
        b0 = b1 = b2 = 0.0
        out = []
        for _ in range(n):
            w = rng.uniform(-1.0, 1.0)
            b0 = 0.99765 * b0 + w * 0.0990460
            b1 = 0.96300 * b1 + w * 0.2965164
            b2 = 0.57000 * b2 + w * 1.0526913
            out.append((b0 + b1 + b2 + w * 0.1848) * 0.25)
        return out
    raise ValueError("unknown noise %r" % kind)


def lowpass(x, cutoff, rate=RATE):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / rate)
    y = 0.0
    out = []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff, rate=RATE):
    return [s - l for s, l in zip(x, lowpass(x, cutoff, rate))]


def tremolo(x, rate_hz, depth, rate=RATE):
    return [s * (1.0 - depth + depth * 0.5 * (1.0 + math.sin(2.0 * math.pi * rate_hz * i / rate)))
            for i, s in enumerate(x)]


def _fade_edges(x, seconds=EDGE_FADE, rate=RATE):
    n = min(int(seconds * rate), len(x) // 2)
    for i in range(n):
        f = i / n
        x[i] *= f
        x[-1 - i] *= f
    return x


def render(recipe, seconds, seed, fade_edges=True, rate=RATE):
    rng = random.Random(seed)
    n = int(seconds * rate)
    mix = [0.0] * n
    detune = 1.0 + rng.uniform(-1.0, 1.0) * recipe.get("detune", DEFAULT_DETUNE)
    for layer in recipe["layers"]:
        start = int(layer.get("delay", 0.0) * rate)
        length = n - start
        if length <= 0:
            continue
        if "osc" in layer:
            f0 = layer["f0"] * detune
            f1 = layer.get("f1", layer["f0"]) * detune
            sig = osc(layer["osc"], length, f0, f1, rate)
        else:
            sig = noise(layer["noise"], length, rng)
        if "lp" in layer:
            sig = lowpass(sig, layer["lp"], rate)
        if "hp" in layer:
            sig = highpass(sig, layer["hp"], rate)
        if "trem" in layer:
            sig = tremolo(sig, layer["trem"][0], layer["trem"][1], rate)
        env = envelope(length, layer["env"][0], layer["env"][1], rate)
        amp = layer.get("amp", 1.0)
        for i in range(length):
            mix[start + i] += sig[i] * env[i] * amp
    return _fade_edges(mix, rate=rate) if fade_edges else mix


def make_loop(samples, seconds, rate=RATE):
    """Blend the tail into the head so the end runs straight into the start. The clip gets
    `seconds` shorter. Equal-power fades keep the level steady through the blend."""
    x = int(seconds * rate)
    if x <= 0 or len(samples) < 3 * x:
        raise ValueError("clip too short for a %.2fs crossfade" % seconds)
    n = len(samples) - x
    out = samples[:n]
    for i in range(x):
        t = i / x
        out[i] = samples[i] * math.sin(t * math.pi / 2.0) + samples[n + i] * math.cos(t * math.pi / 2.0)
    return out


def pad(notes, seconds, lfo_rate, rng, rate=RATE):
    """A slow chord: each note is two slightly detuned sines, gentler for higher notes, breathing."""
    n = int(seconds * rate)
    out = [0.0] * n
    for k, f in enumerate(notes):
        for detune in (0.9985, 1.0015):
            w = 2.0 * math.pi * f * detune / rate
            phase = rng.uniform(0.0, 2.0 * math.pi)
            amp = 1.0 / (k + 1)
            for i in range(n):
                out[i] += math.sin(w * i + phase) * amp
    return [s * (0.75 + 0.25 * math.sin(2.0 * math.pi * lfo_rate * i / rate)) for i, s in enumerate(out)]


def wash(seconds, cutoff, lfo_rate, rng, rate=RATE):
    """Filtered pink noise that swells slowly: wind, water, distant air."""
    n = int(seconds * rate)
    base = lowpass(noise("pink", n, rng), cutoff, rate)
    return [s * (0.7 + 0.3 * math.sin(2.0 * math.pi * lfo_rate * i / rate)) for i, s in enumerate(base)]


def trim_silence(stereo, threshold_db=-50.0):
    left, right = stereo
    limit = db_to_lin(threshold_db)
    loud = [i for i in range(len(left)) if max(abs(left[i]), abs(right[i])) > limit]
    if not loud:
        raise AudioToolError("clip is silent")
    return left[loud[0]:loud[-1] + 1], right[loud[0]:loud[-1] + 1]
```

- [ ] **Step 8: Run all Python tests to verify they pass**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_*.py" -v`
Expected: 15 tests OK.

- [ ] **Step 9: Commit**

```bash
git add tools/audio/audiolib.py tools/audio/dsp.py tools/audio/test_audiolib.py tools/audio/test_dsp.py
git commit -m "feat: audio tool library and DSP kit (Ogg encode, loudness, seam metric, loops)"
```

---

### Task 2: SFX synthesizer, recipes and built SFX

**Files:**
- Create: `tools/audio/synth_sfx.py`, `art_source/audio/recipes/{player,eating,skills,enemies,world,ui,ambience}.json`, `assets/audio/sfx/*.ogg` (generated)
- Modify: `.gitignore`
- Test: `tools/audio/test_synth_sfx.py`

**Interfaces:**
- Consumes: `audiolib.write_ogg`, `audiolib.normalize_peak`, `dsp.render`, `dsp.make_loop`.
- Produces: `synth_sfx.load_recipes(directory=RECIPES) -> dict`, `synth_sfx.variant_files(name, recipe) -> list[str]` (paths relative to `assets/audio`, like `sfx/slime_launch_1.ogg`), `synth_sfx.render_variant(name, recipe, k) -> list[float]`, `synth_sfx.build_cue(name, recipe, out_root="assets/audio", write=audiolib.write_ogg)`, `synth_sfx.main(argv) -> int`. A recipe also carries `"variants"` (default 1), optional `"loop": true` and a `"cue"` object of playback rules (`bus`, `volume_db`, `pitch_jitter`, `cooldown`, `positional`, `duck`, `combo`).

- [ ] **Step 1: Write the failing synth tests**

Create `tools/audio/test_synth_sfx.py`:

```python
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import synth_sfx as s  # noqa: E402

RECIPE = {"dur": 0.2, "variants": 3, "cue": {"bus": "SFX_Player"},
          "layers": [{"osc": "sine", "f0": 300, "f1": 200, "amp": 1.0, "env": [0.005, 0.1]}]}


class SynthSfxTest(unittest.TestCase):
    def test_variant_file_names_are_numbered_from_one(self):
        self.assertEqual(s.variant_files("x", RECIPE), ["sfx/x_1.ogg", "sfx/x_2.ogg", "sfx/x_3.ogg"])

    def test_variants_differ_and_each_repeats_exactly(self):
        one = s.render_variant("x", RECIPE, 1)
        self.assertEqual(one, s.render_variant("x", RECIPE, 1))
        self.assertNotEqual(one, s.render_variant("x", RECIPE, 2))

    def test_peak_is_normalised(self):
        out = s.render_variant("x", RECIPE, 1)
        self.assertAlmostEqual(a.lin_to_db(a.peak(out)), a.SFX_PEAK_DB, places=2)

    def test_a_loop_cue_wraps_without_a_click_and_keeps_its_length(self):
        rec = {"dur": 0.8, "loop": True, "cue": {"bus": "SFX_Player"},
               "layers": [{"noise": "pink", "lp": 500, "amp": 1.0, "env": [0.02, 600]}]}
        out = s.render_variant("l", rec, 1)
        self.assertLess(a.seam_ratio(out), 3.0)
        self.assertAlmostEqual(len(out) / a.RATE, 0.8, delta=0.01)

    def test_a_failed_write_leaves_no_files(self):
        def boom(samples, path):
            raise a.AudioToolError("boom")
        with tempfile.TemporaryDirectory() as d:
            with self.assertRaises(a.AudioToolError):
                s.build_cue("x", RECIPE, d, boom)
            found = [f for _, _, fs in os.walk(d) for f in fs]
            self.assertEqual(found, [])

    def test_build_cue_writes_every_variant(self):
        with tempfile.TemporaryDirectory() as d:
            s.build_cue("x", RECIPE, d)
            for rel in s.variant_files("x", RECIPE):
                a.validate_ogg(os.path.join(d, rel))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify it fails**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_synth_sfx.py" -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'synth_sfx'`.

- [ ] **Step 3: Write `synth_sfx.py`**

Create `tools/audio/synth_sfx.py`:

```python
"""Render every SFX recipe to Ogg Vorbis.

Recipes live in art_source/audio/recipes/*.json: {cue_name: {"dur", "variants", "loop", "layers",
"cue": {playback rules}}}. Each variant is rendered from a fixed seed, so a rebuild is byte-stable
in content. Output: assets/audio/sfx/<cue>_<n>.ogg. Run from the project root:
  TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/synth_sfx.py [cue ...]
"""
import glob
import json
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402
import dsp  # noqa: E402

RECIPES = "art_source/audio/recipes"
OUT = "assets/audio"
LOOP_XFADE = 0.15


def load_recipes(directory=RECIPES):
    recipes = {}
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        with open(path) as f:
            for name, recipe in json.load(f).items():
                if name in recipes:
                    raise audiolib.AudioToolError("duplicate cue %s (in %s)" % (name, path))
                recipes[name] = recipe
    return recipes


def variant_files(name, recipe):
    return ["sfx/%s_%d.ogg" % (name, k) for k in range(1, int(recipe.get("variants", 1)) + 1)]


def render_variant(name, recipe, k):
    seed = zlib.crc32(name.encode()) * 31 + k
    loop = bool(recipe.get("loop"))
    samples = dsp.render(recipe, recipe["dur"] + (LOOP_XFADE if loop else 0.0), seed, fade_edges=not loop)
    if loop:
        samples = dsp.make_loop(samples, LOOP_XFADE)
    return audiolib.normalize_peak(samples, audiolib.SFX_PEAK_DB)


def build_cue(name, recipe, out_root=OUT, write=audiolib.write_ogg):
    for k, rel in enumerate(variant_files(name, recipe), start=1):
        write(render_variant(name, recipe, k), os.path.join(out_root, rel))


def main(argv):
    try:
        recipes = load_recipes()
        wanted = argv or sorted(recipes)
        unknown = [n for n in wanted if n not in recipes]
        if unknown:
            print("unknown cue(s): %s" % ", ".join(unknown), file=sys.stderr)
            return 2
        for name in wanted:
            build_cue(name, recipes[name])
            print("built", name)
    except audiolib.AudioToolError as e:
        print("error:", e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Run to verify the synth tests pass**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_synth_sfx.py" -v`
Expected: 6 tests OK.

- [ ] **Step 5: Write the recipes**

Create the seven recipe files. Every value below is a starting point Sean tunes by ear with the preview tool (Task 13); the structure is what the tests and tools rely on.

`art_source/audio/recipes/player.json`:

```json
{
  "slime_launch": {"dur": 0.30, "variants": 3,
    "layers": [{"osc": "sine", "f0": 180, "f1": 480, "amp": 0.8, "env": [0.004, 0.2]},
               {"noise": "pink", "lp": 1600, "amp": 0.25, "env": [0.002, 0.09]}],
    "cue": {"bus": "SFX_Player", "volume_db": -6, "pitch_jitter": 0.06, "cooldown": 0.05}},
  "slime_land_soft": {"dur": 0.22, "variants": 3,
    "layers": [{"noise": "pink", "lp": 700, "amp": 0.8, "env": [0.002, 0.10]},
               {"osc": "sine", "f0": 120, "f1": 70, "amp": 0.6, "env": [0.003, 0.14]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "pitch_jitter": 0.08, "cooldown": 0.08}},
  "slime_land_hard": {"dur": 0.38, "variants": 2,
    "layers": [{"noise": "pink", "lp": 500, "amp": 0.9, "env": [0.002, 0.2]},
               {"osc": "sine", "f0": 90, "f1": 45, "amp": 1.0, "env": [0.003, 0.28]},
               {"noise": "white", "hp": 2500, "amp": 0.2, "env": [0.001, 0.05]}],
    "cue": {"bus": "SFX_Player", "volume_db": -3, "pitch_jitter": 0.05, "cooldown": 0.10}},
  "slime_run": {"dur": 0.9, "loop": true,
    "layers": [{"noise": "pink", "lp": 500, "amp": 0.7, "trem": [5.5, 0.85], "env": [0.02, 600]},
               {"osc": "sine", "f0": 140, "amp": 0.2, "trem": [5.5, 0.9], "env": [0.02, 600]}],
    "cue": {"bus": "SFX_Player", "volume_db": -16}},
  "slime_wall_cling": {"dur": 0.20, "variants": 2,
    "layers": [{"noise": "white", "hp": 1800, "lp": 5000, "amp": 0.5, "env": [0.001, 0.06]},
               {"osc": "sine", "f0": 900, "f1": 600, "amp": 0.35, "env": [0.001, 0.05]}],
    "cue": {"bus": "SFX_Player", "volume_db": -10, "pitch_jitter": 0.06, "cooldown": 0.15}},
  "slime_wall_slide": {"dur": 0.8, "loop": true,
    "layers": [{"noise": "pink", "hp": 300, "lp": 1200, "amp": 0.6, "trem": [9, 0.5], "env": [0.05, 600]}],
    "cue": {"bus": "SFX_Player", "volume_db": -18}},
  "slime_spread": {"dur": 0.35,
    "layers": [{"osc": "sine", "f0": 300, "f1": 110, "amp": 0.7, "env": [0.01, 0.25]},
               {"noise": "pink", "lp": 900, "amp": 0.35, "env": [0.01, 0.2]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.10}},
  "slime_unspread": {"dur": 0.30,
    "layers": [{"osc": "sine", "f0": 110, "f1": 330, "amp": 0.7, "env": [0.01, 0.2]},
               {"noise": "pink", "lp": 1100, "amp": 0.3, "env": [0.01, 0.15]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.10}},
  "slime_tackle": {"dur": 0.25, "variants": 2,
    "layers": [{"noise": "white", "hp": 600, "lp": 3000, "amp": 0.6, "env": [0.01, 0.12]},
               {"osc": "sine", "f0": 200, "f1": 90, "amp": 0.6, "env": [0.005, 0.15]}],
    "cue": {"bus": "SFX_Player", "volume_db": -7, "pitch_jitter": 0.06, "cooldown": 0.10}},
  "slime_hurt": {"dur": 0.40, "variants": 2,
    "layers": [{"osc": "sine", "f0": 520, "f1": 180, "amp": 0.8, "env": [0.003, 0.28]},
               {"osc": "saw", "f0": 260, "f1": 90, "amp": 0.3, "lp": 1500, "env": [0.003, 0.22]},
               {"noise": "white", "lp": 2500, "amp": 0.15, "env": [0.001, 0.05]}],
    "cue": {"bus": "SFX_Player", "volume_db": -4, "pitch_jitter": 0.05, "cooldown": 0.20}},
  "slime_heartbeat": {"dur": 1.0, "loop": true,
    "layers": [{"osc": "sine", "f0": 55, "f1": 40, "amp": 1.0, "env": [0.01, 0.12]},
               {"osc": "sine", "f0": 50, "f1": 38, "amp": 0.7, "delay": 0.22, "env": [0.01, 0.12]}],
    "cue": {"bus": "SFX_Player", "volume_db": -12}},
  "slime_death": {"dur": 1.2,
    "layers": [{"osc": "sine", "f0": 400, "f1": 60, "amp": 0.8, "env": [0.01, 0.9]},
               {"noise": "pink", "lp": 800, "amp": 0.4, "env": [0.01, 0.7]}],
    "cue": {"bus": "SFX_Player", "volume_db": -3}},
  "slime_levelup": {"dur": 1.0,
    "layers": [{"osc": "sine", "f0": 523.25, "amp": 0.5, "env": [0.005, 0.5]},
               {"osc": "sine", "f0": 659.25, "amp": 0.5, "delay": 0.08, "env": [0.005, 0.5]},
               {"osc": "sine", "f0": 783.99, "amp": 0.5, "delay": 0.16, "env": [0.005, 0.5]},
               {"osc": "sine", "f0": 1046.5, "amp": 0.5, "delay": 0.24, "env": [0.005, 0.6]}],
    "cue": {"bus": "SFX_Player", "volume_db": -6, "duck": true}},
  "slime_evolve": {"dur": 1.6,
    "layers": [{"osc": "sine", "f0": 220, "f1": 880, "amp": 0.6, "env": [0.05, 1.2]},
               {"osc": "sine", "f0": 330, "f1": 1320, "amp": 0.4, "delay": 0.1, "env": [0.05, 1.2]},
               {"noise": "white", "hp": 4000, "amp": 0.15, "env": [0.2, 1.0]}],
    "cue": {"bus": "SFX_Player", "volume_db": -4, "duck": true}}
}
```

`art_source/audio/recipes/eating.json`:

```json
{
  "eat_cover": {"dur": 0.55,
    "layers": [{"noise": "pink", "lp": 700, "amp": 0.7, "trem": [14, 0.6], "env": [0.02, 0.4]},
               {"osc": "sine", "f0": 160, "f1": 90, "amp": 0.5, "env": [0.01, 0.4]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.30}},
  "eat_absorb": {"dur": 0.35, "variants": 2,
    "layers": [{"osc": "sine", "f0": 700, "f1": 900, "amp": 0.6, "env": [0.003, 0.22]},
               {"osc": "sine", "f0": 1400, "f1": 1800, "amp": 0.25, "env": [0.003, 0.15]}],
    "cue": {"bus": "SFX_Player", "volume_db": -10, "cooldown": 0.06,
            "combo": {"step": 1.0, "window": 0.8, "max_steps": 7}}},
  "eat_predated": {"dur": 0.6,
    "layers": [{"osc": "sine", "f0": 300, "f1": 600, "amp": 0.5, "env": [0.01, 0.3]},
               {"osc": "sine", "f0": 450, "f1": 900, "amp": 0.5, "delay": 0.1, "env": [0.01, 0.3]}],
    "cue": {"bus": "SFX_Player", "volume_db": -6}}
}
```

`art_source/audio/recipes/skills.json`:

```json
{
  "skill_generic": {"dur": 0.30,
    "layers": [{"osc": "sine", "f0": 500, "f1": 350, "amp": 0.6, "env": [0.004, 0.2]},
               {"noise": "pink", "lp": 2000, "amp": 0.2, "env": [0.003, 0.1]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.05}},
  "skill_sticky_thread": {"dur": 0.30,
    "layers": [{"noise": "white", "hp": 3000, "amp": 0.3, "env": [0.001, 0.08]},
               {"osc": "sine", "f0": 1200, "f1": 300, "amp": 0.4, "env": [0.003, 0.2]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.05}},
  "skill_swing_thread": {"dur": 0.30,
    "layers": [{"osc": "sine", "f0": 300, "f1": 1400, "amp": 0.4, "env": [0.005, 0.15]},
               {"noise": "pink", "hp": 1500, "amp": 0.3, "env": [0.005, 0.2]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.05}},
  "skill_poison_spit": {"dur": 0.25,
    "layers": [{"osc": "sine", "f0": 250, "f1": 120, "amp": 0.7, "env": [0.003, 0.12]},
               {"noise": "pink", "lp": 1200, "amp": 0.3, "env": [0.002, 0.1]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.05}},
  "skill_poison_breath": {"dur": 0.8,
    "layers": [{"noise": "white", "hp": 800, "lp": 4000, "amp": 0.7, "env": [0.08, 0.5]},
               {"osc": "sine", "f0": 100, "f1": 90, "amp": 0.3, "trem": [12, 0.5], "env": [0.05, 0.5]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.10}},
  "skill_water_blade": {"dur": 0.35,
    "layers": [{"noise": "white", "hp": 2500, "amp": 0.5, "env": [0.002, 0.15]},
               {"osc": "sine", "f0": 1800, "f1": 600, "amp": 0.35, "env": [0.002, 0.2]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.05}},
  "skill_jet_dash": {"dur": 0.50,
    "layers": [{"noise": "white", "hp": 500, "lp": 6000, "amp": 0.7, "env": [0.01, 0.3]},
               {"osc": "sine", "f0": 150, "f1": 400, "amp": 0.3, "env": [0.01, 0.3]}],
    "cue": {"bus": "SFX_Player", "volume_db": -7, "cooldown": 0.10}},
  "skill_hydraulic": {"dur": 0.60,
    "layers": [{"noise": "pink", "lp": 900, "amp": 0.6, "env": [0.05, 0.4]},
               {"osc": "sine", "f0": 80, "f1": 200, "amp": 0.5, "env": [0.05, 0.4]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.10}},
  "skill_tail_swipe": {"dur": 0.30,
    "layers": [{"noise": "pink", "hp": 800, "lp": 3500, "amp": 0.6, "env": [0.01, 0.15]},
               {"osc": "sine", "f0": 500, "f1": 200, "amp": 0.3, "env": [0.005, 0.15]}],
    "cue": {"bus": "SFX_Player", "volume_db": -8, "cooldown": 0.05}},
  "skill_constrict": {"dur": 0.70,
    "layers": [{"noise": "pink", "lp": 500, "amp": 0.6, "trem": [6, 0.7], "env": [0.05, 0.5]},
               {"osc": "saw", "f0": 90, "f1": 70, "amp": 0.25, "lp": 400, "env": [0.05, 0.5]}],
    "cue": {"bus": "SFX_Player", "volume_db": -9, "cooldown": 0.10}},
  "skill_unlock": {"dur": 1.2,
    "layers": [{"osc": "sine", "f0": 659.25, "amp": 0.5, "env": [0.005, 0.7]},
               {"osc": "sine", "f0": 880, "amp": 0.5, "delay": 0.12, "env": [0.005, 0.7]},
               {"osc": "sine", "f0": 1318.5, "amp": 0.5, "delay": 0.24, "env": [0.005, 0.8]}],
    "cue": {"bus": "UI", "volume_db": -6, "duck": true}},
  "skill_rank_up": {"dur": 0.8,
    "layers": [{"osc": "sine", "f0": 784, "amp": 0.5, "env": [0.005, 0.4]},
               {"osc": "sine", "f0": 1175, "amp": 0.5, "delay": 0.1, "env": [0.005, 0.4]}],
    "cue": {"bus": "UI", "volume_db": -8}}
}
```

`art_source/audio/recipes/enemies.json`:

```json
{
  "enemy_impact": {"dur": 0.20, "variants": 3,
    "layers": [{"noise": "white", "hp": 1200, "lp": 5000, "amp": 0.6, "env": [0.001, 0.06]},
               {"osc": "sine", "f0": 260, "f1": 140, "amp": 0.6, "env": [0.002, 0.10]}],
    "cue": {"bus": "SFX_Enemy", "volume_db": -6, "pitch_jitter": 0.08, "cooldown": 0.04, "positional": true}},
  "enemy_stun": {"dur": 0.50,
    "layers": [{"osc": "sine", "f0": 900, "f1": 300, "amp": 0.5, "trem": [18, 0.7], "env": [0.003, 0.4]}],
    "cue": {"bus": "SFX_Enemy", "volume_db": -7, "cooldown": 0.20}},
  "enemy_death_flyer": {"dur": 0.70,
    "layers": [{"osc": "sine", "f0": 1400, "f1": 200, "amp": 0.6, "env": [0.003, 0.5]},
               {"noise": "white", "hp": 3000, "amp": 0.3, "env": [0.003, 0.3]}],
    "cue": {"bus": "SFX_Enemy", "volume_db": -5, "positional": true}},
  "enemy_death_crawler": {"dur": 0.60,
    "layers": [{"osc": "sine", "f0": 300, "f1": 80, "amp": 0.6, "env": [0.003, 0.4]},
               {"noise": "pink", "lp": 2500, "amp": 0.4, "trem": [25, 0.6], "env": [0.003, 0.4]}],
    "cue": {"bus": "SFX_Enemy", "volume_db": -5, "positional": true}},
  "enemy_death_beast": {"dur": 0.70,
    "layers": [{"osc": "sine", "f0": 180, "f1": 50, "amp": 0.8, "env": [0.005, 0.6]},
               {"noise": "pink", "lp": 900, "amp": 0.5, "env": [0.005, 0.4]}],
    "cue": {"bus": "SFX_Enemy", "volume_db": -4, "positional": true}},
  "enemy_death_boss": {"dur": 2.0,
    "layers": [{"osc": "sine", "f0": 90, "f1": 30, "amp": 1.0, "env": [0.02, 1.6]},
               {"noise": "pink", "lp": 600, "amp": 0.6, "env": [0.02, 1.5]},
               {"osc": "saw", "f0": 60, "f1": 25, "amp": 0.4, "lp": 300, "env": [0.02, 1.6]}],
    "cue": {"bus": "SFX_Enemy", "volume_db": -2}}
}
```

`art_source/audio/recipes/world.json`:

```json
{
  "tablet_chime": {"dur": 0.9,
    "layers": [{"osc": "sine", "f0": 392, "amp": 0.4, "env": [0.005, 0.7]},
               {"osc": "sine", "f0": 587.33, "amp": 0.4, "delay": 0.12, "env": [0.005, 0.7]}],
    "cue": {"bus": "SFX_World", "volume_db": -8, "positional": true}},
  "switch_open": {"dur": 0.60,
    "layers": [{"noise": "pink", "lp": 700, "amp": 0.8, "env": [0.005, 0.3]},
               {"osc": "sine", "f0": 70, "f1": 40, "amp": 0.8, "env": [0.005, 0.4]}],
    "cue": {"bus": "SFX_World", "volume_db": -4, "positional": true}},
  "pool_rest": {"dur": 1.4,
    "layers": [{"osc": "sine", "f0": 523.25, "amp": 0.3, "env": [0.15, 1.0]},
               {"osc": "sine", "f0": 659.25, "amp": 0.3, "delay": 0.1, "env": [0.15, 1.0]},
               {"osc": "sine", "f0": 783.99, "amp": 0.3, "delay": 0.2, "env": [0.15, 1.0]},
               {"noise": "pink", "lp": 1500, "amp": 0.2, "env": [0.2, 1.0]}],
    "cue": {"bus": "SFX_World", "volume_db": -8, "positional": true}},
  "water_in": {"dur": 0.50, "variants": 2,
    "layers": [{"noise": "pink", "lp": 3000, "amp": 0.7, "env": [0.003, 0.25]},
               {"osc": "sine", "f0": 200, "f1": 500, "amp": 0.3, "env": [0.003, 0.15]}],
    "cue": {"bus": "SFX_World", "volume_db": -8, "pitch_jitter": 0.08, "positional": true}},
  "water_out": {"dur": 0.45, "variants": 2,
    "layers": [{"noise": "pink", "lp": 2500, "amp": 0.6, "env": [0.003, 0.2]},
               {"osc": "sine", "f0": 500, "f1": 250, "amp": 0.3, "env": [0.003, 0.15]}],
    "cue": {"bus": "SFX_World", "volume_db": -9, "pitch_jitter": 0.08, "positional": true}}
}
```

`art_source/audio/recipes/ui.json`:

```json
{
  "ui_open": {"dur": 0.18,
    "layers": [{"osc": "sine", "f0": 400, "f1": 800, "amp": 0.5, "env": [0.005, 0.12]}],
    "cue": {"bus": "UI", "volume_db": -10}},
  "ui_close": {"dur": 0.18,
    "layers": [{"osc": "sine", "f0": 800, "f1": 400, "amp": 0.5, "env": [0.005, 0.12]}],
    "cue": {"bus": "UI", "volume_db": -10}},
  "ui_move": {"dur": 0.08,
    "layers": [{"osc": "sine", "f0": 1000, "amp": 0.4, "env": [0.002, 0.04]}],
    "cue": {"bus": "UI", "volume_db": -14, "cooldown": 0.03}},
  "ui_confirm": {"dur": 0.20,
    "layers": [{"osc": "sine", "f0": 800, "amp": 0.5, "env": [0.002, 0.09]},
               {"osc": "sine", "f0": 1200, "amp": 0.5, "delay": 0.04, "env": [0.002, 0.09]}],
    "cue": {"bus": "UI", "volume_db": -10}},
  "ui_denied": {"dur": 0.25,
    "layers": [{"osc": "saw", "f0": 180, "f1": 140, "amp": 0.5, "lp": 900, "env": [0.003, 0.14]}],
    "cue": {"bus": "UI", "volume_db": -10, "cooldown": 0.15}},
  "ui_popup": {"dur": 0.50,
    "layers": [{"osc": "sine", "f0": 880, "amp": 0.5, "env": [0.003, 0.25]},
               {"osc": "sine", "f0": 1320, "amp": 0.5, "delay": 0.06, "env": [0.003, 0.25]}],
    "cue": {"bus": "UI", "volume_db": -10}}
}
```

`art_source/audio/recipes/ambience.json`:

```json
{
  "amb_drip": {"dur": 0.5, "variants": 4,
    "layers": [{"osc": "sine", "f0": 1800, "f1": 900, "amp": 0.6, "env": [0.001, 0.08]},
               {"osc": "sine", "f0": 3600, "f1": 1800, "amp": 0.15, "env": [0.001, 0.05]}],
    "cue": {"bus": "Ambience", "volume_db": -14, "pitch_jitter": 0.15, "positional": true}},
  "amb_crystal_ping": {"dur": 1.6, "variants": 3,
    "layers": [{"osc": "sine", "f0": 2093, "amp": 0.5, "env": [0.002, 1.2]},
               {"osc": "sine", "f0": 3136, "amp": 0.25, "delay": 0.01, "env": [0.002, 0.9]}],
    "cue": {"bus": "Ambience", "volume_db": -16, "pitch_jitter": 0.10, "positional": true}},
  "amb_hum": {"dur": 3.0, "variants": 2,
    "layers": [{"osc": "sine", "f0": 110, "amp": 0.5, "trem": [0.4, 0.5], "env": [0.8, 2.0]},
               {"osc": "sine", "f0": 165, "amp": 0.25, "env": [0.8, 2.0]}],
    "cue": {"bus": "Ambience", "volume_db": -18, "positional": true}},
  "amb_bubble": {"dur": 0.4, "variants": 4,
    "layers": [{"osc": "sine", "f0": 300, "f1": 900, "amp": 0.6, "env": [0.002, 0.15]}],
    "cue": {"bus": "Ambience", "volume_db": -14, "pitch_jitter": 0.20, "positional": true}},
  "amb_spore": {"dur": 1.0, "variants": 3,
    "layers": [{"noise": "pink", "hp": 2000, "lp": 6000, "amp": 0.3, "env": [0.2, 0.5]},
               {"osc": "sine", "f0": 1200, "f1": 1500, "amp": 0.15, "env": [0.2, 0.5]}],
    "cue": {"bus": "Ambience", "volume_db": -16, "pitch_jitter": 0.10, "positional": true}}
}
```

- [ ] **Step 6: Add a test that the real recipes are well formed**

Append to `tools/audio/test_synth_sfx.py`, inside `SynthSfxTest`:

```python
    def test_the_real_recipes_are_well_formed(self):
        recipes = s.load_recipes()
        self.assertGreater(len(recipes), 45)
        for name, r in recipes.items():
            self.assertIn("bus", r.get("cue", {}), name)
            self.assertGreater(r["dur"], 0.0, name)
            self.assertTrue(r["layers"], name)
            for layer in r["layers"]:
                self.assertTrue("osc" in layer or "noise" in layer, name)
                self.assertEqual(len(layer["env"]), 2, name)
            if r.get("loop"):
                self.assertGreaterEqual(r["dur"], 0.5, name)
```

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_synth_sfx.py" -v`
Expected: 7 tests OK.

- [ ] **Step 7: Ignore raw provider output**

Append to `.gitignore`:

```
# Raw provider output behind the music and ambience beds (regenerable with tools/audio/gen_bed.py). The built assets in assets/audio are committed.
art_source/audio/raw/
```

Run: `git check-ignore art_source/audio/raw/x.mp3`
Expected: prints `art_source/audio/raw/x.mp3`.

- [ ] **Step 8: Build every SFX**

Run: `mkdir -p .tmp/audio-work && TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/synth_sfx.py`
Expected: one `built <cue>` line per recipe (51), exit 0. Then `ls assets/audio/sfx/*.ogg | wc -l` prints 75 (the recipes' variants add up to 75), and `ls assets/audio/sfx/*.tmp.ogg` finds nothing.

- [ ] **Step 9: Commit**

```bash
git add .gitignore tools/audio/synth_sfx.py tools/audio/test_synth_sfx.py art_source/audio/recipes assets/audio/sfx
git commit -m "feat: procedural SFX synthesizer, 51 recipes and the built sound effects"
```

---

### Task 3: Bed generator and placeholder beds

**Files:**
- Create: `tools/audio/gen_bed.py`, `art_source/audio/beds/{cave,grotto,flooded,deep}.json`, `assets/audio/music/*.ogg`, `assets/audio/ambience/*.ogg` (generated)
- Test: `tools/audio/test_gen_bed.py`

**Interfaces:**
- Consumes: `audiolib.*`, `dsp.pad`, `dsp.wash`, `dsp.make_loop`, `dsp.trim_silence`.
- Produces: `gen_bed.raw_samples(spec, biome, kind)`, `gen_bed.process(raw, kind) -> (left, right)`, `gen_bed.build(biome, kind, spec, out_root="assets/audio")`, `gen_bed.main(argv) -> int`. A bed spec file is `{"prompt": str, "music": {...}, "ambience": {...}}`; each kind's object has `"provider"` (`synth` or `local`) plus provider fields. Output: `assets/audio/<kind>/<biome>.ogg`.

- [ ] **Step 1: Write the failing bed tests**

Create `tools/audio/test_gen_bed.py`:

```python
import os
import sys
import tempfile
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


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify it fails**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_gen_bed.py" -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'gen_bed'`.

- [ ] **Step 3: Write `gen_bed.py`**

Create `tools/audio/gen_bed.py`:

```python
"""Build the looping music and ambience beds, one Ogg per biome and kind.

A bed spec (art_source/audio/beds/<biome>.json) holds the provider prompt and, per kind, which
provider makes the raw audio:
  "synth": a built-in pad (music) or noise wash (ambience). Placeholder that works offline.
  "local": decode a file Sean or a provider dropped at art_source/audio/raw/ (gitignored).
Every bed is trimmed, made loop-safe with a crossfade, set to its LUFS target and encoded.
Run from the project root:
  TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/gen_bed.py [biome ...]
"""
import glob
import json
import os
import random
import sys
import tempfile
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402
import dsp  # noqa: E402

BEDS = "art_source/audio/beds"
OUT = "assets/audio"
KINDS = ("music", "ambience")
XFADE = 2.0
HEADROOM_DB = -1.5  # a bed's peak may never rise above this while it is being made loud enough


def raw_samples(spec, biome, kind):
    provider = spec.get("provider")
    if provider == "synth":
        rng = random.Random(zlib.crc32(("%s/%s" % (biome, kind)).encode()))
        if kind == "music":
            return dsp.pad(spec["notes"], spec["dur"], spec["lfo"], rng)
        return dsp.wash(spec["dur"], spec["lp"], spec["lfo"], rng)
    if provider == "local":
        if not os.path.exists(spec["file"]):
            raise audiolib.AudioToolError("%s/%s: put the generated file at %s" % (biome, kind, spec["file"]))
        return audiolib.decode_pcm(spec["file"])
    raise audiolib.AudioToolError("%s/%s: unknown provider %r" % (biome, kind, provider))


def _measure(stereo):
    with tempfile.TemporaryDirectory() as d:
        path = os.path.join(d, "m.wav")
        audiolib.write_wav(path, stereo)
        return audiolib.measure_lufs(path)


def process(raw, kind):
    left, right = dsp.trim_silence(audiolib.to_stereo(raw))
    left = dsp.make_loop(left, XFADE)
    right = dsp.make_loop(right, XFADE)
    wanted = audiolib.TARGET_LUFS[kind] - _measure((left, right))
    top = audiolib.lin_to_db(max(audiolib.peak(left), audiolib.peak(right)))
    wanted = min(wanted, HEADROOM_DB - top)  # loud enough, but never past the ceiling
    return audiolib.gain(left, wanted), audiolib.gain(right, wanted)


def build(biome, kind, spec, out_root=OUT):
    audiolib.write_ogg(process(raw_samples(spec, biome, kind), kind), os.path.join(out_root, kind, biome + ".ogg"))


def main(argv):
    try:
        for path in sorted(glob.glob(os.path.join(BEDS, "*.json"))):
            biome = os.path.splitext(os.path.basename(path))[0]
            if argv and biome not in argv:
                continue
            with open(path) as f:
                spec = json.load(f)
            for kind in KINDS:
                if kind in spec:
                    build(biome, kind, spec[kind])
                    print("built", kind, biome)
    except audiolib.AudioToolError as e:
        print("error:", e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Run to verify the bed tests pass**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_gen_bed.py" -v`
Expected: 7 tests OK. The music-bed test takes several seconds because the pad is rendered in pure Python.

- [ ] **Step 5: Write the bed specs**

Create the four spec files. The prompts are for the real provider in Task 14 and follow the terrain art tone (bright, luminous, alive; no dread; no torches or human-made sounds in the wilderness).

`art_source/audio/beds/cave.json`:

```json
{
  "prompt": "Bright, warm, prismatic underground cavern. Slow airy pads, soft glassy crystal chimes, gentle sustained strings, hopeful and curious, unhurried. Instrumental, no drums, no vocals, no dread.",
  "music": {"provider": "synth", "dur": 24.0, "notes": [130.81, 196.0, 261.63, 329.63], "lfo": 0.08},
  "ambience": {"provider": "synth", "dur": 20.0, "lp": 900, "lfo": 0.05}
}
```

`art_source/audio/beds/grotto.json`:

```json
{
  "prompt": "Lush bioluminescent fungal grotto. Soft breathy pads, plucked marimba-like notes, faint rustling spores, gently mysterious and alive, warm greens. Instrumental, no drums, no vocals, no dread.",
  "music": {"provider": "synth", "dur": 24.0, "notes": [146.83, 220.0, 293.66, 369.99], "lfo": 0.07},
  "ambience": {"provider": "synth", "dur": 20.0, "lp": 1300, "lfo": 0.06}
}
```

`art_source/audio/beds/flooded.json`:

```json
{
  "prompt": "Luminous flooded tunnels. Rippling harp-like arpeggios, deep watery pads, distant dripping and soft echo, calm and expansive, cool blues. Instrumental, no drums, no vocals, no dread.",
  "music": {"provider": "synth", "dur": 24.0, "notes": [123.47, 185.0, 246.94, 311.13], "lfo": 0.06},
  "ambience": {"provider": "synth", "dur": 20.0, "lp": 700, "lfo": 0.15}
}
```

`art_source/audio/beds/deep.json`:

```json
{
  "prompt": "Reserved deep cavern: sparse and dark but not hopeless. Low drones, very slow sub pulses, occasional single distant bell, wide silence. Instrumental, no drums, no vocals.",
  "music": {"provider": "synth", "dur": 24.0, "notes": [98.0, 146.83, 196.0], "lfo": 0.05},
  "ambience": {"provider": "synth", "dur": 20.0, "lp": 400, "lfo": 0.04}
}
```

- [ ] **Step 6: Build the beds**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/gen_bed.py`
Expected: eight `built ...` lines (music and ambience for four biomes), exit 0, no `.tmp.ogg` left in `assets/audio`. This takes about a minute.

- [ ] **Step 7: Commit**

```bash
git add tools/audio/gen_bed.py tools/audio/test_gen_bed.py art_source/audio/beds assets/audio/music assets/audio/ambience
git commit -m "feat: loop-safe bed generator and placeholder music and ambience for the four biomes"
```

---

### Task 4: Catalog data, cue builder and asset checks

**Files:**
- Create: `data/audio/cues.json`, `tools/audio/build_cues.py`
- Test: `tools/audio/test_build_cues.py`, `tools/audio/test_assets.py`

**Interfaces:**
- Consumes: `synth_sfx.load_recipes`, `synth_sfx.variant_files`, `audiolib.validate_ogg`.
- Produces: `build_cues.cues_from_recipes(recipes) -> dict`, `build_cues.build(catalog_path=CATALOG, recipes=None, root="assets/audio")`, `build_cues.main(argv) -> int`. The catalog file `data/audio/cues.json` has keys `cues` (generated), `events` and `biomes` (authored). An `events` value is a cue id string, `null` (silent, with a sibling `"_why:<event>"` string), `{"by": tag, "<value>": cue, ..., "default": cue}` or `{"stop": cue_id}` for a looping cue.

- [ ] **Step 1: Write the failing builder tests**

Create `tools/audio/test_build_cues.py`:

```python
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import build_cues  # noqa: E402
import synth_sfx  # noqa: E402

RECIPES = {
    "tone": {"dur": 0.2, "variants": 2, "cue": {"bus": "UI", "volume_db": -8},
             "layers": [{"osc": "sine", "f0": 440, "amp": 1.0, "env": [0.005, 0.1]}]},
    "hum": {"dur": 0.8, "loop": True, "cue": {"bus": "SFX_Player"},
            "layers": [{"noise": "pink", "lp": 500, "amp": 1.0, "env": [0.02, 600]}]},
}
AUTHORED = {"events": {"jumped": "tone", "mana_spent": None, "_why:mana_spent": "one per MP point"},
            "biomes": {"cave": {"reverb_wet": 0.15}}}


def write_catalog(path):
    with open(path, "w") as f:
        json.dump(dict(AUTHORED, cues={}), f)


class BuildCuesTest(unittest.TestCase):
    def test_cues_list_their_variant_files_and_mark_loops(self):
        cues = build_cues.cues_from_recipes(RECIPES)
        self.assertEqual(cues["tone"]["files"], ["sfx/tone_1.ogg", "sfx/tone_2.ogg"])
        self.assertEqual(cues["tone"]["bus"], "UI")
        self.assertNotIn("loop", cues["tone"])
        self.assertTrue(cues["hum"]["loop"])

    def test_build_keeps_the_authored_sections_and_fills_cues(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            path = os.path.join(d, "cues.json")
            write_catalog(path)
            build_cues.build(path, RECIPES, d)
            with open(path) as f:
                got = json.load(f)
            self.assertEqual(got["events"], AUTHORED["events"])
            self.assertEqual(got["biomes"], AUTHORED["biomes"])
            self.assertEqual(sorted(got["cues"]), ["hum", "tone"])

    def test_a_missing_file_fails_and_leaves_the_catalog_unchanged(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "cues.json")
            write_catalog(path)
            before = open(path, "rb").read()
            with self.assertRaises(a.AudioToolError):
                build_cues.build(path, RECIPES, d)
            self.assertEqual(open(path, "rb").read(), before)

    def test_a_corrupt_file_fails(self):
        with tempfile.TemporaryDirectory() as d:
            for name, r in RECIPES.items():
                synth_sfx.build_cue(name, r, d)
            with open(os.path.join(d, "sfx", "tone_2.ogg"), "wb") as f:
                f.write(b"junk")
            path = os.path.join(d, "cues.json")
            write_catalog(path)
            with self.assertRaises(a.AudioToolError):
                build_cues.build(path, RECIPES, d)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run to verify it fails**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_build_cues.py" -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'build_cues'`.

- [ ] **Step 3: Write `build_cues.py`**

Create `tools/audio/build_cues.py`:

```python
"""Regenerate the `cues` section of data/audio/cues.json from the SFX recipes.

The `events` and `biomes` sections are authored by hand and kept as they are. Every file a cue
lists must already exist and read as Ogg Vorbis, or nothing is written and the exit code is 1.
Run from the project root:
  python3 tools/audio/build_cues.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402
import synth_sfx  # noqa: E402

CATALOG = "data/audio/cues.json"


def cues_from_recipes(recipes):
    cues = {}
    for name in sorted(recipes):
        recipe = recipes[name]
        rule = dict(recipe["cue"])
        rule["files"] = synth_sfx.variant_files(name, recipe)
        if recipe.get("loop"):
            rule["loop"] = True
        cues[name] = rule
    return cues


def build(catalog_path=CATALOG, recipes=None, root=synth_sfx.OUT):
    recipes = recipes if recipes is not None else synth_sfx.load_recipes()
    with open(catalog_path) as f:
        catalog = json.load(f)
    cues = cues_from_recipes(recipes)
    for rule in cues.values():
        for rel in rule["files"]:
            audiolib.validate_ogg(os.path.join(root, rel))
    body = {"cues": cues, "events": catalog.get("events", {}), "biomes": catalog.get("biomes", {})}
    tmp = catalog_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(body, f, indent=2)
        f.write("\n")
    os.replace(tmp, catalog_path)


def main(argv):
    try:
        build()
    except (audiolib.AudioToolError, OSError, ValueError) as e:
        print("error:", e, file=sys.stderr)
        return 1
    print("wrote", CATALOG)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 4: Run to verify the builder tests pass**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_build_cues.py" -v`
Expected: 4 tests OK.

- [ ] **Step 5: Author the events and biomes**

Create `data/audio/cues.json` (the `cues` section stays empty until step 6 fills it):

```json
{
  "cues": {},
  "events": {
    "jumped": "slime_launch",
    "wall_touched": "slime_wall_cling",
    "damaged": "slime_hurt",
    "hp_low_entered": "slime_heartbeat",
    "hp_low_exited": {"stop": "slime_heartbeat"},
    "stunned_enemy": "enemy_stun",
    "predated": "eat_predated",
    "absorbed": "eat_absorb",
    "inspected": null,
    "_why:inspected": "the result has its own sound (tablet_read, pool_rested); a click here would double it",
    "skill_used": {"by": "id",
      "sticky_thread": "skill_sticky_thread", "swing_thread": "skill_swing_thread",
      "poison_spit": "skill_poison_spit", "poison_breath": "skill_poison_breath",
      "water_blade": "skill_water_blade", "jet_dash": "skill_jet_dash",
      "hydraulic_propulsion": "skill_hydraulic", "tail_swipe": "skill_tail_swipe",
      "constrict": "skill_constrict", "default": "skill_generic"},
    "mana_spent": null,
    "_why:mana_spent": "one event per MP point spent; it would machine-gun and skill_used already has the sound",
    "skill_unlocked": "skill_unlock",
    "skill_leveled": "skill_rank_up",
    "evolution_ready": null,
    "_why:evolution_ready": "the ready state shows in the menu; the sound plays when the evolution happens (evolved)",

    "landed": {"by": "hard", "true": "slime_land_hard", "false": "slime_land_soft"},
    "run_started": "slime_run",
    "run_stopped": {"stop": "slime_run"},
    "wall_slide_started": "slime_wall_slide",
    "wall_slide_stopped": {"stop": "slime_wall_slide"},
    "spread": {"by": "on", "true": "slime_spread", "false": "slime_unspread"},
    "tackled": "slime_tackle",
    "player_died": "slime_death",
    "leveled_up": "slime_levelup",
    "evolved": "slime_evolve",
    "eat_started": "eat_cover",
    "enemy_hit": "enemy_impact",
    "enemy_died": {"by": "id", "bat": "enemy_death_flyer", "spider": "enemy_death_crawler",
      "toad": "enemy_death_beast", "lizard": "enemy_death_beast", "serpent": "enemy_death_boss",
      "default": "enemy_death_beast"},
    "tablet_read": "tablet_chime",
    "switch_opened": "switch_open",
    "pool_rested": "pool_rest",
    "water_entered": "water_in",
    "water_exited": "water_out",
    "menu_opened": "ui_open",
    "menu_closed": "ui_close",
    "menu_move": "ui_move",
    "menu_confirm": "ui_confirm",
    "denied": "ui_denied",
    "ticker_shown": {"by": "kind", "slot_replaced": "ui_popup"},
    "_why:ticker_shown": "unlock and level-up already have their own stingers; only the slot-replaced line gets ui_popup"
  },
  "biomes": {
    "cave": {"music": "music/cave.ogg", "ambience": "ambience/cave.ogg", "reverb_wet": 0.15,
      "oneshots": {"cues": ["amb_drip", "amb_crystal_ping"], "interval": [4.0, 12.0], "radius": 220}},
    "grotto": {"music": "music/grotto.ogg", "ambience": "ambience/grotto.ogg", "reverb_wet": 0.30,
      "oneshots": {"cues": ["amb_spore", "amb_crystal_ping"], "interval": [4.0, 12.0], "radius": 220}},
    "flooded": {"music": "music/flooded.ogg", "ambience": "ambience/flooded.ogg", "reverb_wet": 0.45,
      "oneshots": {"cues": ["amb_bubble", "amb_drip"], "interval": [4.0, 12.0], "radius": 220}},
    "deep": {"music": "music/deep.ogg", "ambience": "ambience/deep.ogg", "reverb_wet": 0.20,
      "oneshots": {"cues": ["amb_hum", "amb_drip"], "interval": [8.0, 20.0], "radius": 260}}
  }
}
```

- [ ] **Step 6: Generate the cues section**

Run: `python3 tools/audio/build_cues.py`
Expected: `wrote data/audio/cues.json`, exit 0. Then run `python3 -c "import json; d=json.load(open('data/audio/cues.json')); print(len(d['cues']), len(d['events']))"`; expected `51 ...` with the first number 51.

- [ ] **Step 7: Write the built-asset tests**

Create `tools/audio/test_assets.py`:

```python
import glob
import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib as a  # noqa: E402
import synth_sfx  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "assets", "audio")


def oggs(kind):
    return sorted(glob.glob(os.path.join(AUDIO, kind, "*.ogg")))


class BuiltAssetsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with open(os.path.join(ROOT, "data", "audio", "cues.json")) as f:
            cls.catalog = json.load(f)
        cls.pcm = {p: a.decode_pcm(p) for kind in ("sfx", "music", "ambience") for p in oggs(kind)}

    def test_every_file_is_stereo_vorbis(self):
        expected = 2 * len(("cave", "grotto", "flooded", "deep")) + sum(
            int(r.get("variants", 1)) for r in synth_sfx.load_recipes().values())
        self.assertEqual(len(self.pcm), expected)  # every SFX variant plus the eight beds
        for path in self.pcm:
            info = a.validate_ogg(path)
            self.assertEqual(info["channels"], 2, path)

    def test_nothing_peaks_above_the_ceiling(self):
        for path, (left, right) in self.pcm.items():
            top = a.lin_to_db(max(a.peak(left), a.peak(right)))
            self.assertLessEqual(top, a.PEAK_CEILING_DB, path)

    def test_sfx_are_not_silent(self):
        for path in oggs("sfx"):
            left, right = self.pcm[path]
            self.assertGreater(a.lin_to_db(a.peak(left)), -6.0, path)

    def test_music_and_ambience_hit_their_loudness_targets(self):
        for kind in ("music", "ambience"):
            for path in oggs(kind):
                self.assertAlmostEqual(a.measure_lufs(path), a.TARGET_LUFS[kind], delta=a.LUFS_TOLERANCE, msg=path)

    def test_loops_wrap_without_a_click(self):
        loops = [os.path.join(AUDIO, f) for rule in self.catalog["cues"].values() if rule.get("loop")
                 for f in rule["files"]]
        self.assertGreaterEqual(len(loops), 3)
        for path in oggs("music") + oggs("ambience") + loops:
            left, right = self.pcm[path]
            self.assertLess(a.seam_ratio(left), 3.0, path)
            self.assertLess(a.seam_ratio(right), 3.0, path)

    def test_every_recipe_has_its_files_and_no_sfx_is_orphaned(self):
        wanted = set()
        for name, recipe in synth_sfx.load_recipes().items():
            wanted.update(os.path.join(AUDIO, rel) for rel in synth_sfx.variant_files(name, recipe))
        self.assertEqual(wanted, set(oggs("sfx")))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 8: Run the whole Python suite**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_*.py" -v`
Expected: all tests OK. If a loop seam or loudness test fails, apply the stop-and-diagnose rule: print the measured value for that file, decide whether the tool (crossfade length, gain) or the recipe (for example a loop recipe whose envelope decays) is wrong, fix that, and rebuild only the affected assets with `synth_sfx.py <cue>` or `gen_bed.py <biome>`. Do not raise a threshold to get green.

- [ ] **Step 9: Commit**

```bash
git add data/audio/cues.json tools/audio/build_cues.py tools/audio/test_build_cues.py tools/audio/test_assets.py
git commit -m "feat: audio cue catalog with events and biomes, cue builder and built-asset checks"
```

---

### Task 5: CueCatalog

**Files:**
- Create: `scripts/audio/cue_catalog.gd`
- Test: `tests/test_audio_catalog.gd`

**Interfaces:**
- Produces: `class_name CueCatalog extends RefCounted` with consts `BUSES`, `BIOMES`, `ASSET_DIR`; vars `cues`, `events`, `biomes` (Dictionaries); `static load_file(path: String) -> CueCatalog`; `static from_dict(data: Dictionary) -> CueCatalog`; `route(event_name: String, tags: Dictionary) -> Dictionary` (`{"cue": id}`, `{"stop": id}` or `{}`); `pick_file(cue_id: String, rng: RandomNumberGenerator) -> String` (a `res://assets/audio/...` path, never the same variant twice in a row, `""` for an unknown cue); `validate(file_exists: Callable) -> Array` of error strings (`file_exists` takes a `res://` path and returns bool).

- [ ] **Step 1: Write the failing catalog tests**

Create `tests/test_audio_catalog.gd`:

```gdscript
extends GutTest
## The cue catalog: routing an event to a cue, picking variants and validating data/audio/cues.json.

func _exists(_p: String) -> bool:
	return true

func _biomes() -> Dictionary:
	var out := {}
	for area in CueCatalog.BIOMES:
		out[area] = {"music": "music/%s.ogg" % area, "ambience": "ambience/%s.ogg" % area, "reverb_wet": 0.2,
			"oneshots": {"cues": ["a"], "interval": [4.0, 8.0], "radius": 200}}
	return out

func _catalog(events := {}) -> CueCatalog:
	return CueCatalog.from_dict({
		"cues": {
			"a": {"files": ["sfx/a_1.ogg", "sfx/a_2.ogg"], "bus": "SFX_Player", "volume_db": -6},
			"b": {"files": ["sfx/b_1.ogg"], "bus": "UI"},
			"lp": {"files": ["sfx/lp_1.ogg"], "bus": "SFX_Player", "loop": true},
		},
		"events": events,
		"biomes": _biomes(),
	})

func test_a_plain_event_routes_to_its_cue() -> void:
	var c := _catalog({"jumped": "a"})
	assert_eq(c.route("jumped", {}), {"cue": "a"})

func test_a_bool_tag_selects_by_its_string_form() -> void:
	var c := _catalog({"landed": {"by": "hard", "true": "a", "false": "b"}})
	assert_eq(c.route("landed", {"hard": true}), {"cue": "a"})
	assert_eq(c.route("landed", {"hard": false}), {"cue": "b"})

func test_a_by_id_entry_falls_back_to_default() -> void:
	var c := _catalog({"skill_used": {"by": "id", "x": "a", "default": "b"}})
	assert_eq(c.route("skill_used", {"id": "x"}), {"cue": "a"})
	assert_eq(c.route("skill_used", {"id": "zzz"}), {"cue": "b"})
	assert_eq(c.route("skill_used", {}), {"cue": "b"})

func test_a_by_entry_without_a_default_is_silent_for_an_unknown_tag() -> void:
	var c := _catalog({"e": {"by": "id", "x": "a"}})
	assert_eq(c.route("e", {"id": "nope"}), {})

func test_stop_silent_and_unknown_events() -> void:
	var c := _catalog({"off": {"stop": "lp"}, "quiet": null, "_why:quiet": "because"})
	assert_eq(c.route("off", {}), {"stop": "lp"})
	assert_eq(c.route("quiet", {}), {})
	assert_eq(c.route("never_heard_of_it", {}), {})

func test_pick_file_never_repeats_a_variant_back_to_back() -> void:
	var c := _catalog()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := ""
	for i in 200:
		var f := c.pick_file("a", rng)
		assert_ne(f, last)
		assert_true(f.begins_with("res://assets/audio/sfx/a_"))
		last = f

func test_pick_file_with_one_variant_and_an_unknown_cue() -> void:
	var c := _catalog()
	var rng := RandomNumberGenerator.new()
	assert_eq(c.pick_file("b", rng), "res://assets/audio/sfx/b_1.ogg")
	assert_eq(c.pick_file("b", rng), "res://assets/audio/sfx/b_1.ogg")
	assert_eq(c.pick_file("nope", rng), "")

func test_a_valid_catalog_has_no_errors() -> void:
	var c := _catalog({"jumped": "a", "off": {"stop": "lp"}, "quiet": null, "_why:quiet": "x"})
	assert_eq(c.validate(_exists), [])

func test_validate_reports_each_kind_of_mistake() -> void:
	var missing := func(p: String) -> bool: return not p.ends_with("a_2.ogg")
	assert_true(_errors(_catalog(), missing, "missing file"))
	var c := _catalog({"quiet": null})
	assert_true(_errors(c, _exists, "silent without a _why"))
	c = _catalog({"e": "ghost"})
	assert_true(_errors(c, _exists, "unknown cue"))
	c = _catalog({"e": {"stop": "a"}})
	assert_true(_errors(c, _exists, "not a loop"))
	c = _catalog()
	c.cues["a"]["bus"] = "Nope"
	assert_true(_errors(c, _exists, "unknown bus"))
	c = _catalog()
	c.biomes.erase("deep")
	assert_true(_errors(c, _exists, "biome deep"))
	c = _catalog()
	c.biomes["cave"]["oneshots"]["interval"] = [8.0, 4.0]
	assert_true(_errors(c, _exists, "bad interval"))

func _errors(c: CueCatalog, exists: Callable, what: String) -> bool:
	var errs := c.validate(exists)
	if errs.is_empty():
		fail_test("expected an error for: " + what)
		return false
	return true

# --- the committed catalog ------------------------------------------------------

func test_the_committed_catalog_validates_against_the_real_files() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	assert_gt(c.cues.size(), 45)
	var errs := c.validate(func(p: String) -> bool: return FileAccess.file_exists(p))
	assert_eq(errs, [], "\n".join(errs))

func test_every_gameplay_event_has_an_entry() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	for name in Events.ALL:
		assert_true(c.events.has(name), "events.%s" % name)
	for name in ["skill_unlocked", "skill_leveled", "evolution_ready"]:
		assert_true(c.events.has(name), "events.%s" % name)

func test_every_active_skill_has_its_own_cue() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	var by_id: Dictionary = c.events["skill_used"]
	for d in SkillRules.skill_defs:
		if SkillEffects.active_scene(d) != "":
			assert_true(by_id.has(d.id), "skill_used.%s" % d.id)

func test_no_audio_file_is_orphaned() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	var used := {}
	for id in c.cues:
		for f in c.cues[id]["files"]:
			used[f] = true
	for area in c.biomes:
		used[c.biomes[area]["music"]] = true
		used[c.biomes[area]["ambience"]] = true
	for sub in ["sfx", "music", "ambience"]:
		for f in DirAccess.get_files_at("res://assets/audio/" + sub):
			if f.ends_with(".ogg"):
				assert_true(used.has(sub + "/" + f), "orphan %s/%s" % [sub, f])
```

- [ ] **Step 2: Import the audio assets and run the test to verify it fails**

Run: `mkdir -p .tmp/test-logs .tmp/gdhome && gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh audio_catalog`
Expected: FAIL with an engine error (`Parse Error` or `Identifier "CueCatalog" not declared`), since the class does not exist yet.

- [ ] **Step 3: Write `cue_catalog.gd`**

Create `scripts/audio/cue_catalog.gd`:

```gdscript
class_name CueCatalog
extends RefCounted
## data/audio/cues.json: playback rules per cue, which event plays which cue, and each biome's beds.
## Pure data logic; Audio owns the players.

const ASSET_DIR := "res://assets/audio/"
const BUSES := ["Music", "Ambience", "SFX_Player", "SFX_Enemy", "SFX_World", "UI"]
const BIOMES := ["cave", "grotto", "flooded", "deep"]

var cues := {}
var events := {}
var biomes := {}
var _last := {}  # cue id -> index of the variant played last

static func load_file(path: String) -> CueCatalog:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return from_dict(data if typeof(data) == TYPE_DICTIONARY else {})

static func from_dict(data: Dictionary) -> CueCatalog:
	var c := CueCatalog.new()
	c.cues = data.get("cues", {})
	c.events = data.get("events", {})
	c.biomes = data.get("biomes", {})
	return c

## What an event does: {"cue": id} to play, {"stop": id} to end a looping cue, {} for silence
## or an event the catalog does not know.
func route(event_name: String, tags: Dictionary) -> Dictionary:
	var entry = events.get(event_name)
	if entry == null:
		return {}
	if typeof(entry) == TYPE_STRING:
		return {"cue": entry}
	if typeof(entry) != TYPE_DICTIONARY:
		return {}
	if entry.has("stop"):
		return {"stop": entry["stop"]}
	# JSON keys are strings, so a bool tag selects through its string form ("true" / "false").
	var picked = entry.get(str(tags.get(str(entry.get("by", "")), "")), entry.get("default"))
	return {"cue": picked} if typeof(picked) == TYPE_STRING else {}

## A res:// path for one of the cue's variants, never the same one twice in a row.
func pick_file(cue_id: String, rng: RandomNumberGenerator) -> String:
	var files: Array = cues.get(cue_id, {}).get("files", [])
	if files.is_empty():
		return ""
	var i := 0
	if files.size() > 1:
		i = rng.randi_range(0, files.size() - 1)
		if i == int(_last.get(cue_id, -1)):
			i = (i + 1 + rng.randi_range(0, files.size() - 2)) % files.size()
	_last[cue_id] = i
	return ASSET_DIR + str(files[i])

## Every mistake in the data, as readable strings. file_exists takes a res:// path.
func validate(file_exists: Callable) -> Array:
	var errors: Array = []
	for id in cues:
		var rule: Dictionary = cues[id]
		var files = rule.get("files")
		if typeof(files) != TYPE_ARRAY or files.is_empty() or files.size() > 4:
			errors.append("cue %s: files must list 1 to 4 variants" % id)
		else:
			for f in files:
				if not file_exists.call(ASSET_DIR + str(f)):
					errors.append("cue %s: missing file %s" % [id, f])
		if not BUSES.has(str(rule.get("bus", ""))):
			errors.append("cue %s: unknown bus '%s'" % [id, rule.get("bus", "")])
		var volume := float(rule.get("volume_db", 0.0))
		if volume < -40.0 or volume > 6.0:
			errors.append("cue %s: volume_db %s is outside -40..6" % [id, volume])
		var jitter := float(rule.get("pitch_jitter", 0.0))
		if jitter < 0.0 or jitter > 0.5:
			errors.append("cue %s: pitch_jitter %s is outside 0..0.5" % [id, jitter])
		if float(rule.get("cooldown", 0.0)) < 0.0:
			errors.append("cue %s: negative cooldown" % id)
	for name in events:
		if str(name).begins_with("_"):
			continue  # a "_why:<event>" comment
		var entry = events[name]
		if entry == null:
			if str(events.get("_why:" + str(name), "")).strip_edges() == "":
				errors.append("event %s: silent without a _why" % name)
			continue
		if typeof(entry) == TYPE_DICTIONARY and entry.has("stop"):
			if not bool(cues.get(entry["stop"], {}).get("loop", false)):
				errors.append("event %s: stop target %s is not a looping cue" % [name, entry["stop"]])
			continue
		for target in _targets(entry):
			if not cues.has(target):
				errors.append("event %s: unknown cue %s" % [name, target])
	for area in BIOMES:
		var b = biomes.get(area)
		if typeof(b) != TYPE_DICTIONARY:
			errors.append("biome %s: missing" % area)
			continue
		for key in ["music", "ambience"]:
			if not file_exists.call(ASSET_DIR + str(b.get(key, ""))):
				errors.append("biome %s: missing %s file" % [area, key])
		var wet := float(b.get("reverb_wet", -1.0))
		if wet < 0.0 or wet > 1.0:
			errors.append("biome %s: reverb_wet must be 0..1" % area)
		var shots: Dictionary = b.get("oneshots", {})
		var shot_cues: Array = shots.get("cues", [])
		if shot_cues.is_empty():
			errors.append("biome %s: oneshots need at least one cue" % area)
		for cue_id in shot_cues:
			if not cues.has(cue_id):
				errors.append("biome %s: oneshot cue %s is unknown" % [area, cue_id])
		var interval: Array = shots.get("interval", [])
		if interval.size() != 2 or float(interval[0]) <= 0.0 or float(interval[1]) < float(interval[0]):
			errors.append("biome %s: oneshot interval must be [low, high] with 0 < low <= high" % area)
		if float(shots.get("radius", 0.0)) <= 0.0:
			errors.append("biome %s: oneshot radius must be above 0" % area)
	return errors

## The cue ids one event entry can play.
func _targets(entry) -> Array:
	if typeof(entry) == TYPE_STRING:
		return [entry]
	var out: Array = []
	if typeof(entry) == TYPE_DICTIONARY:
		for key in entry:
			if key != "by" and typeof(entry[key]) == TYPE_STRING:
				out.append(entry[key])
	return out
```

- [ ] **Step 4: Run to verify the catalog tests pass**

Run: `tools/run_tests.sh audio_catalog`
Expected: the runner prints `PASS: <n> tests` with n at least 13 for this file. If `test_the_committed_catalog_validates_against_the_real_files` fails on a missing file, run the import command from Step 2 again and re-read `.tmp/test-logs/import.log`.

- [ ] **Step 5: Commit**

```bash
git add scripts/audio tests/test_audio_catalog.gd tests/test_audio_catalog.gd.uid assets/audio
git commit -m "feat: cue catalog routes events to cues, picks variants and validates the data"
```

---

### Task 6: VoicePool, ComboPitch and OneshotScheduler

**Files:**
- Create: `scripts/audio/voice_pool.gd`, `scripts/audio/combo_pitch.gd`, `scripts/audio/oneshot_scheduler.gd`
- Test: `tests/test_audio_pool.gd`

**Interfaces:**
- Produces:
  - `class_name VoicePool extends RefCounted`: `_init(p_capacity: int, p_clock: Callable)`; `acquire(cue: String, volume_db: float, cooldown: float) -> int` (slot index, or −1 while the cue's cooldown has not passed; a full pool steals the quietest voice, ties to the oldest); `release(slot: int)`; `busy_count() -> int`; `cue_at(slot: int) -> String`. `clock` returns seconds as float.
  - `class_name ComboPitch extends RefCounted`: `_init(p_clock: Callable)`; `next(cue: String, window: float, max_steps: int) -> int` (0 on the first trigger, +1 per retrigger inside `window` seconds, capped at `max_steps`).
  - `class_name OneshotScheduler extends RefCounted`: `_init(p_rng: RandomNumberGenerator)`; `set_biome(entry: Dictionary)` (entry has `cues`, `interval`, `radius`); `advance(delta: float) -> Array` of `{"cue": String, "offset": Vector2}` due now.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_audio_pool.gd`:

```gdscript
extends GutTest
## Voice pool, combo pitch and the ambience one-shot scheduler. Pure logic with an injected clock and RNG.

var now := 0.0

func _clock() -> float:
	return now

func _pool(capacity := 4) -> VoicePool:
	now = 0.0
	return VoicePool.new(capacity, _clock)

func test_the_pool_hands_out_distinct_free_slots() -> void:
	var p := _pool()
	var seen := {}
	for i in 4:
		seen[p.acquire("c%d" % i, -6.0, 0.0)] = true
	assert_eq(seen.size(), 4)
	assert_eq(p.busy_count(), 4)

func test_a_cue_inside_its_cooldown_is_dropped() -> void:
	var p := _pool()
	assert_ne(p.acquire("absorb", -6.0, 0.06), -1)
	now = 0.03
	assert_eq(p.acquire("absorb", -6.0, 0.06), -1)
	assert_eq(p.busy_count(), 1)
	now = 0.07
	assert_ne(p.acquire("absorb", -6.0, 0.06), -1)

func test_a_burst_in_one_frame_plays_once() -> void:
	var p := _pool(16)
	var played := 0
	for i in 12:  # twelve essence units absorbed in the same frame
		if p.acquire("eat_absorb", -10.0, 0.06) != -1:
			played += 1
	assert_eq(played, 1)

func test_a_full_pool_steals_the_quietest_voice() -> void:
	var p := _pool(3)
	var loud := p.acquire("loud", -3.0, 0.0)
	var quiet := p.acquire("quiet", -20.0, 0.0)
	var mid := p.acquire("mid", -10.0, 0.0)
	var stolen := p.acquire("new", -6.0, 0.0)
	assert_eq(stolen, quiet)
	assert_eq(p.cue_at(stolen), "new")
	assert_eq(p.cue_at(loud), "loud")
	assert_eq(p.cue_at(mid), "mid")
	assert_eq(p.busy_count(), 3)

func test_equally_quiet_voices_lose_the_oldest_first() -> void:
	var p := _pool(2)
	now = 1.0
	var first := p.acquire("a", -10.0, 0.0)
	now = 2.0
	p.acquire("b", -10.0, 0.0)
	now = 3.0
	assert_eq(p.acquire("c", -10.0, 0.0), first)

func test_release_frees_a_slot_for_reuse() -> void:
	var p := _pool(2)
	var a := p.acquire("a", -6.0, 0.0)
	p.acquire("b", -6.0, 0.0)
	p.release(a)
	assert_eq(p.busy_count(), 1)
	assert_eq(p.acquire("c", -6.0, 0.0), a)

# --- combo pitch ----------------------------------------------------------------

func test_combo_pitch_climbs_inside_the_window_and_resets_after_it() -> void:
	now = 0.0
	var c := ComboPitch.new(_clock)
	assert_eq(c.next("absorb", 0.8, 3), 0)
	now = 0.3
	assert_eq(c.next("absorb", 0.8, 3), 1)
	now = 0.6
	assert_eq(c.next("absorb", 0.8, 3), 2)
	now = 0.9
	assert_eq(c.next("absorb", 0.8, 3), 3)
	now = 1.2
	assert_eq(c.next("absorb", 0.8, 3), 3, "capped at max_steps")
	now = 5.0
	assert_eq(c.next("absorb", 0.8, 3), 0, "a gap resets the run")

func test_combo_pitch_tracks_each_cue_separately() -> void:
	now = 0.0
	var c := ComboPitch.new(_clock)
	c.next("a", 1.0, 5)
	now = 0.2
	assert_eq(c.next("b", 1.0, 5), 0)
	assert_eq(c.next("a", 1.0, 5), 1)

# --- one-shot scheduler ---------------------------------------------------------

func _entry() -> Dictionary:
	return {"cues": ["drip", "ping"], "interval": [1.0, 1.0], "radius": 100}

func test_nothing_is_due_without_a_biome() -> void:
	var s := OneshotScheduler.new(RandomNumberGenerator.new())
	assert_eq(s.advance(10.0), [])

func test_a_one_shot_fires_when_the_interval_passes_within_the_radius() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := OneshotScheduler.new(rng)
	s.set_biome(_entry())
	assert_eq(s.advance(0.5), [])
	var due := s.advance(0.6)
	assert_eq(due.size(), 1)
	assert_true(["drip", "ping"].has(due[0]["cue"]))
	assert_lte(due[0]["offset"].length(), 100.0)
	assert_eq(s.advance(0.5), [], "the next one waits a full interval")

func test_changing_biome_restarts_the_wait() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var s := OneshotScheduler.new(rng)
	s.set_biome(_entry())
	s.advance(0.9)
	s.set_biome(_entry())
	assert_eq(s.advance(0.5), [])
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh audio_pool`
Expected: FAIL with an engine error (`Identifier "VoicePool" not declared`).

- [ ] **Step 3: Write the three classes**

Create `scripts/audio/voice_pool.gd`:

```gdscript
class_name VoicePool
extends RefCounted
## Which of a fixed set of voices plays the next sound: a per-cue cooldown, and when every voice is
## busy the quietest one is stolen (ties go to the oldest). Pure logic; Audio owns the players.

var capacity: int
var _clock: Callable
var _slots: Array = []
var _last_played := {}  # cue id -> clock time

func _init(p_capacity: int, p_clock: Callable) -> void:
	capacity = p_capacity
	_clock = p_clock
	for i in capacity:
		_slots.append({"cue": "", "volume_db": 0.0, "since": 0.0, "busy": false})

## A slot for the cue, or -1 while its cooldown has not passed.
func acquire(cue: String, volume_db: float, cooldown: float) -> int:
	var now: float = _clock.call()
	if cooldown > 0.0 and _last_played.has(cue) and now - float(_last_played[cue]) < cooldown:
		return -1
	var slot := _free_slot()
	if slot == -1:
		slot = _quietest()
	_last_played[cue] = now
	_slots[slot] = {"cue": cue, "volume_db": volume_db, "since": now, "busy": true}
	return slot

func release(slot: int) -> void:
	_slots[slot]["busy"] = false

func busy_count() -> int:
	return _slots.filter(func(s: Dictionary) -> bool: return s["busy"]).size()

func cue_at(slot: int) -> String:
	return _slots[slot]["cue"]

func _free_slot() -> int:
	for i in capacity:
		if not _slots[i]["busy"]:
			return i
	return -1

func _quietest() -> int:
	var best := 0
	for i in range(1, capacity):
		var s: Dictionary = _slots[i]
		var b: Dictionary = _slots[best]
		if s["volume_db"] < b["volume_db"] or (s["volume_db"] == b["volume_db"] and s["since"] < b["since"]):
			best = i
	return best
```

Create `scripts/audio/combo_pitch.gd`:

```gdscript
class_name ComboPitch
extends RefCounted
## Pitch steps for a cue that retriggers quickly, so a run of absorbs climbs instead of repeating.

var _clock: Callable
var _steps := {}
var _last := {}

func _init(p_clock: Callable) -> void:
	_clock = p_clock

## 0 on the first trigger, +1 per retrigger inside `window` seconds, capped at `max_steps`.
func next(cue: String, window: float, max_steps: int) -> int:
	var now: float = _clock.call()
	var n := 0
	if _last.has(cue) and now - float(_last[cue]) <= window:
		n = mini(int(_steps.get(cue, 0)) + 1, max_steps)
	_steps[cue] = n
	_last[cue] = now
	return n
```

Create `scripts/audio/oneshot_scheduler.gd`:

```gdscript
class_name OneshotScheduler
extends RefCounted
## Random ambience one-shots (drips, pings, hums) for the current biome: a random cue on a random
## interval, at a random offset up to `radius` px from the player.

var _rng: RandomNumberGenerator
var _entry := {}
var _left := 0.0

func _init(p_rng: RandomNumberGenerator) -> void:
	_rng = p_rng

## entry is a biome's `oneshots`: {"cues": [...], "interval": [low, high], "radius": px}.
func set_biome(entry: Dictionary) -> void:
	_entry = entry
	_left = _next_delay()

## Advances time; returns the one-shots due now as [{"cue": id, "offset": Vector2}].
func advance(delta: float) -> Array:
	if _entry.is_empty():
		return []
	_left -= delta
	if _left > 0.0:
		return []
	_left = _next_delay()
	var cues: Array = _entry["cues"]
	var angle := _rng.randf() * TAU
	var reach := _rng.randf() * float(_entry["radius"])
	return [{"cue": cues[_rng.randi() % cues.size()], "offset": Vector2(cos(angle), sin(angle)) * reach}]

func _next_delay() -> float:
	var interval: Array = _entry["interval"]
	return _rng.randf_range(float(interval[0]), float(interval[1]))
```

- [ ] **Step 4: Run to verify the tests pass**

Run: `tools/run_tests.sh audio_pool`
Expected: a `PASS: <n> tests` line with no failures.

- [ ] **Step 5: Commit**

```bash
git add scripts/audio tests/test_audio_pool.gd tests/test_audio_pool.gd.uid
git commit -m "feat: voice pool, combo pitch and ambience one-shot scheduler"
```

---

### Task 7: Audio settings, Profile section and the bus layout

**Files:**
- Create: `scripts/audio/audio_settings.gd`, `tools/audio/build_bus_layout.gd`, `default_bus_layout.tres` (generated)
- Modify: `scripts/persistence/profile.gd` (add `dict_section` after `list_section`, around line 62)
- Test: `tests/test_audio_settings.gd`

**Interfaces:**
- Consumes: `Profile.set_section`, `Profile.save`, `Profile.reload`.
- Produces:
  - `Profile.dict_section(name: String) -> Dictionary` (a deep copy; anything that is not a Dictionary warns, is dropped and returns `{}`).
  - `class_name AudioSettings extends RefCounted`: consts `KEYS = ["master","music","ambience","sfx"]`, `LABELS`, `BUS_OF`, `DEFAULT = 0.8`, `STEP = 0.1`; vars `values: Dictionary`, `dirty: bool`; `load_from(profile: Profile)`; `save_to(profile: Profile) -> bool`; `set_value(key: String, v: float)`; `adjust(key: String, direction: int)`; `apply()` (sets bus volume and mute on `AudioServer`).
  - Buses in `default_bus_layout.tres`: `Master` (limiter), `Music` (effect 0: `AudioEffectAmplify`), `Ambience`, `SFX_Player`, `SFX_Enemy`, `SFX_World` (effect 0: `AudioEffectReverb`), `UI`, all sending to `Master`.

- [ ] **Step 1: Write the failing settings and bus tests**

Create `tests/test_audio_settings.gd`:

```gdscript
extends GutTest
## Volume settings (0..1, saved in the Profile) and the bus layout they drive.

const PATH := "user://test_audio_profile.json"

var profile: Profile

func before_each() -> void:
	profile = Profile.new(PATH)
	profile.warn = func(_msg: String) -> void: pass

func after_each() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	AudioSettings.new().apply()  # default volumes on the buses again after a test changed them

func test_defaults_are_eighty_percent() -> void:
	var s := AudioSettings.new()
	for k in AudioSettings.KEYS:
		assert_almost_eq(s.values[k], 0.8, 0.0001, k)
	assert_false(s.dirty)

func test_values_round_trip_through_the_profile() -> void:
	var s := AudioSettings.new()
	s.set_value("music", 0.3)
	s.set_value("sfx", 1.0)
	assert_true(s.dirty)
	assert_true(s.save_to(profile))
	assert_false(s.dirty)
	var again := Profile.new(PATH)
	again.reload()
	var t := AudioSettings.new()
	t.load_from(again)
	assert_almost_eq(t.values["music"], 0.3, 0.0001)
	assert_almost_eq(t.values["sfx"], 1.0, 0.0001)
	assert_almost_eq(t.values["master"], 0.8, 0.0001)

func test_a_malformed_section_resets_to_defaults() -> void:
	profile.set_section("audio", "loud")
	var s := AudioSettings.new()
	s.load_from(profile)
	for k in AudioSettings.KEYS:
		assert_almost_eq(s.values[k], 0.8, 0.0001, k)

func test_bad_values_are_dropped_one_by_one() -> void:
	profile.set_section("audio", {"master": 5.0, "music": "x", "ambience": 0.25, "sfx": -1.0})
	var s := AudioSettings.new()
	s.load_from(profile)
	assert_almost_eq(s.values["master"], 0.8, 0.0001)
	assert_almost_eq(s.values["music"], 0.8, 0.0001)
	assert_almost_eq(s.values["ambience"], 0.25, 0.0001)
	assert_almost_eq(s.values["sfx"], 0.8, 0.0001)

func test_adjust_steps_by_a_tenth_and_clamps() -> void:
	var s := AudioSettings.new()
	s.adjust("music", 1)
	assert_almost_eq(s.values["music"], 0.9, 0.0001)
	s.adjust("music", 1)
	s.adjust("music", 1)
	assert_almost_eq(s.values["music"], 1.0, 0.0001)
	for i in 12:
		s.adjust("music", -1)
	assert_almost_eq(s.values["music"], 0.0, 0.0001)

func test_the_bus_layout_has_every_bus_and_its_effects() -> void:
	for b in ["Music", "Ambience", "SFX_Player", "SFX_Enemy", "SFX_World", "UI"]:
		var i := AudioServer.get_bus_index(b)
		assert_ne(i, -1, b)
		assert_eq(AudioServer.get_bus_send(i), &"Master", b)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0) is AudioEffectAmplify)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX_World"), 0) is AudioEffectReverb)
	assert_true(AudioServer.get_bus_effect(0, 0) is AudioEffectLimiter)

func test_a_slider_at_zero_mutes_the_bus_and_never_writes_minus_infinity() -> void:
	var s := AudioSettings.new()
	s.set_value("music", 0.0)
	s.set_value("sfx", 0.0)
	s.apply()
	var music := AudioServer.get_bus_index("Music")
	assert_true(AudioServer.is_bus_mute(music))
	assert_gt(AudioServer.get_bus_volume_db(music), -100.0)
	for b in ["SFX_Player", "SFX_Enemy", "SFX_World"]:
		assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index(b)), b)
	s.set_value("music", 0.5)
	s.apply()
	assert_false(AudioServer.is_bus_mute(music))
	assert_almost_eq(AudioServer.get_bus_volume_db(music), linear_to_db(0.5), 0.01)
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh audio_settings`
Expected: FAIL with an engine error (`Identifier "AudioSettings" not declared`).

- [ ] **Step 3: Add `Profile.dict_section`**

In `scripts/persistence/profile.gd`, insert directly after `list_section` (which ends with `return v.duplicate()`):

```gdscript
## A Dictionary section. Anything else is malformed: warn, drop it and return {}.
func dict_section(name: String) -> Dictionary:
	var v = _sections.get(name)
	if v == null:
		return {}
	if typeof(v) != TYPE_DICTIONARY:
		warn.call("Profile: dropped malformed '%s' section" % name)
		_sections.erase(name)
		return {}
	return v.duplicate(true)
```

- [ ] **Step 4: Write `audio_settings.gd`**

Create `scripts/audio/audio_settings.gd`:

```gdscript
class_name AudioSettings
extends RefCounted
## The four volume sliders (0..1). Saved in the Profile under `audio`; applied to the buses.
## A slider at 0 mutes its buses: linear_to_db(0) is -inf and must never reach AudioServer.

const KEYS := ["master", "music", "ambience", "sfx"]
const LABELS := {"master": "Master", "music": "Music", "ambience": "Ambience", "sfx": "Effects"}
const BUS_OF := {"master": ["Master"], "music": ["Music"], "ambience": ["Ambience"],
	"sfx": ["SFX_Player", "SFX_Enemy", "SFX_World"]}
const DEFAULT := 0.8
const STEP := 0.1
const FLOOR_LINEAR := 0.0001

var values := {}
var dirty := false

func _init() -> void:
	_reset()

func _reset() -> void:
	for k in KEYS:
		values[k] = DEFAULT

func load_from(profile: Profile) -> void:
	_reset()
	var raw := profile.dict_section("audio")
	for k in KEYS:
		var v = raw.get(k)
		if (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and float(v) >= 0.0 and float(v) <= 1.0:
			values[k] = float(v)
	dirty = false

func save_to(profile: Profile) -> bool:
	profile.set_section("audio", values.duplicate())
	dirty = false
	return profile.save()

func set_value(key: String, v: float) -> void:
	values[key] = clampf(snappedf(v, 0.05), 0.0, 1.0)
	dirty = true

func adjust(key: String, direction: int) -> void:
	set_value(key, float(values[key]) + direction * STEP)

func apply() -> void:
	for k in KEYS:
		for bus_name in BUS_OF[k]:
			var i := AudioServer.get_bus_index(bus_name)
			if i == -1:
				continue
			AudioServer.set_bus_mute(i, float(values[k]) <= 0.0)
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(values[k]), FLOOR_LINEAR)))
```

- [ ] **Step 5: Write the bus layout tool and build the layout**

Create `tools/audio/build_bus_layout.gd`:

```gdscript
extends SceneTree
## Builds default_bus_layout.tres from scratch. Run from the project root:
##   mkdir -p .tmp/gdhome && env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/audio/build_bus_layout.gd

func _init() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	while AudioServer.get_bus_effect_count(0) > 0:
		AudioServer.remove_bus_effect(0, 0)
	for bus_name in ["Music", "Ambience", "SFX_Player", "SFX_Enemy", "SFX_World", "UI"]:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), AudioEffectAmplify.new())  # the duck
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.6
	reverb.damping = 0.5
	reverb.wet = 0.15
	reverb.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX_World"), reverb)
	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	quit(0 if err == OK else 1)
```

Run: `mkdir -p .tmp/gdhome && gtimeout -k 5 120 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/audio/build_bus_layout.gd > .tmp/test-logs/bus.log 2>&1; grep -c "bus/" default_bus_layout.tres; grep -E "SCRIPT ERROR|Parse Error" .tmp/test-logs/bus.log`
Expected: a count above 30 (each bus writes several lines), no error lines. Open `default_bus_layout.tres` and confirm it names `Music`, `Ambience`, `SFX_Player`, `SFX_Enemy`, `SFX_World` and `UI`.

- [ ] **Step 6: Import and run the settings tests**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh audio_settings`
Expected: a `PASS: <n> tests` line with no failures.

- [ ] **Step 7: Commit**

```bash
git add scripts/audio scripts/persistence/profile.gd tools/audio/build_bus_layout.gd tools/audio/build_bus_layout.gd.uid default_bus_layout.tres tests/test_audio_settings.gd tests/test_audio_settings.gd.uid
git commit -m "feat: audio settings, Profile dict section and the bus layout with duck and reverb"
```

---

### Task 8: EventBus channel, MusicDirector and the Audio autoload

**Files:**
- Create: `scripts/audio/music_director.gd`, `autoload/audio.gd`
- Modify: `autoload/event_bus.gd`, `project.godot` (autoload list), `tests/test_autoloads.gd`
- Test: `tests/test_audio_runtime.gd`

**Interfaces:**
- Consumes: `CueCatalog`, `VoicePool`, `ComboPitch`, `OneshotScheduler`, `AudioSettings`, `Compendium.profile`, `SkillRules` signals.
- Produces:
  - `EventBus.world_event(name: String, tags: Dictionary)`.
  - `class_name MusicDirector extends Node`: `current_area: String`, `current_music: String`, `scheduler: OneshotScheduler`; `setup(catalog: CueCatalog, p_scheduler: OneshotScheduler)`; `set_biome(area: String) -> bool` (true only when the bed changed); `static fade_gains(t: float) -> Vector2` (x fades in, y fades out, `x² + y² = 1`).
  - `Audio` autoload: `catalog: CueCatalog`, `settings: AudioSettings`, `director: MusicDirector`, `last_cue: String`; `play_cue(cue_id: String, pos := Vector2.INF)`; `stop_loop(cue_id: String)`; `is_looping(cue_id: String) -> bool`; `set_biome(area: String)`; `adjust_setting(key: String, direction: int)`; `reset()`.
  - Routing rule: the tag `pos` (Vector2), when present and the cue is `positional`, places the sound in the world.

- [ ] **Step 1: Write the failing runtime tests**

Create `tests/test_audio_runtime.gd`:

```gdscript
extends GutTest
## The Audio autoload end to end: events become cues, loops stop, the duck and biome behave.
## The audio driver is a dummy in headless runs, so these check routing and state, not sound.

var _duck_effect: AudioEffectAmplify

func before_each() -> void:
	Audio.reset()
	Audio.last_cue = ""
	_duck_effect = AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0)
	_duck_effect.volume_db = 0.0

func after_each() -> void:
	get_tree().paused = false
	Audio.reset()

func test_a_world_event_plays_its_cue() -> void:
	EventBus.world_event.emit("landed", {"hard": true})
	assert_eq(Audio.last_cue, "slime_land_hard")
	EventBus.world_event.emit("tackled", {})
	assert_eq(Audio.last_cue, "slime_tackle")

func test_a_game_event_plays_its_cue_and_skill_used_picks_by_id() -> void:
	EventBus.game_event.emit(Events.JUMPED, {"from": "ground"})
	assert_eq(Audio.last_cue, "slime_launch")
	Audio.last_cue = ""
	EventBus.game_event.emit(Events.SKILL_USED, {"id": "water_blade"})
	assert_eq(Audio.last_cue, "skill_water_blade")

func test_silent_and_unknown_events_play_nothing() -> void:
	EventBus.game_event.emit(Events.MANA_SPENT, {})
	EventBus.world_event.emit("not_an_event", {})
	assert_eq(Audio.last_cue, "")

func test_skill_rules_signals_play_their_stingers() -> void:
	SkillRules.skill_unlocked.emit("leap")
	assert_eq(Audio.last_cue, "skill_unlock")
	SkillRules.skill_leveled.emit("leap", 2)
	assert_eq(Audio.last_cue, "skill_rank_up")

func test_a_loop_starts_once_and_a_stop_event_ends_it() -> void:
	EventBus.world_event.emit("run_started", {})
	assert_true(Audio.is_looping("slime_run"))
	EventBus.world_event.emit("run_started", {})  # a second start does not stack
	assert_true(Audio.is_looping("slime_run"))
	EventBus.world_event.emit("run_stopped", {})
	assert_false(Audio.is_looping("slime_run"))

func test_reset_stops_every_loop() -> void:
	EventBus.world_event.emit("run_started", {})
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	assert_true(Audio.is_looping("slime_heartbeat"))
	Audio.reset()
	assert_false(Audio.is_looping("slime_run"))
	assert_false(Audio.is_looping("slime_heartbeat"))

func test_dying_ends_the_heartbeat_before_the_death_cue_plays() -> void:
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	EventBus.world_event.emit("run_started", {})
	EventBus.world_event.emit("player_died", {})
	assert_false(Audio.is_looping("slime_heartbeat"))
	assert_false(Audio.is_looping("slime_run"))
	assert_eq(Audio.last_cue, "slime_death")

func test_reset_frees_every_voice_and_forgets_cooldowns() -> void:
	EventBus.game_event.emit(Events.ABSORBED, {"essence": "poison", "source": "toad"})
	SkillRules.skill_unlocked.emit("leap")
	Audio.reset()
	assert_eq(Audio._pool.busy_count(), 0)
	Audio.last_cue = ""
	EventBus.game_event.emit(Events.ABSORBED, {"essence": "poison", "source": "toad"})
	assert_eq(Audio.last_cue, "eat_absorb", "the cooldown from before the reset is gone")

func test_a_new_run_stops_loops_left_from_the_last_one() -> void:
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	SkillRules.run_started.emit()
	assert_false(Audio.is_looping("slime_heartbeat"))

func test_an_absorb_burst_plays_once() -> void:
	Audio.last_cue = ""
	for i in 8:
		EventBus.game_event.emit(Events.ABSORBED, {"essence": "poison", "source": "toad"})
	assert_eq(Audio.last_cue, "eat_absorb")
	assert_eq(Audio._pool.busy_count(), 1)

func test_a_cue_with_a_missing_file_warns_once_and_does_not_crash() -> void:
	Audio.catalog.cues["ghost"] = {"files": ["sfx/ghost_1.ogg"], "bus": "UI", "volume_db": -6}
	Audio.play_cue("ghost")
	Audio.play_cue("ghost")
	assert_eq(Audio.last_cue, "", "nothing played")
	Audio.catalog.cues.erase("ghost")

func test_the_menu_ducks_the_music_and_releases_it() -> void:
	EventBus.world_event.emit("menu_opened", {})
	await get_tree().create_timer(0.4, true).timeout
	assert_almost_eq(_duck_effect.volume_db, Audio.DUCK_DB, 0.5)
	EventBus.world_event.emit("menu_closed", {})
	await get_tree().create_timer(0.9, true).timeout
	assert_almost_eq(_duck_effect.volume_db, 0.0, 0.5)

func test_the_duck_still_runs_while_the_tree_is_paused() -> void:
	assert_eq(Audio.process_mode, Node.PROCESS_MODE_ALWAYS)
	get_tree().paused = true
	EventBus.world_event.emit("menu_opened", {})
	await get_tree().create_timer(0.4, true).timeout
	get_tree().paused = false
	assert_almost_eq(_duck_effect.volume_db, Audio.DUCK_DB, 0.5)

func test_ui_voices_run_while_paused_and_gameplay_voices_do_not() -> void:
	Audio.play_cue("ui_confirm")
	var ui_slot := 0
	for i in Audio.VOICES:
		if Audio._pool.cue_at(i) == "ui_confirm":
			ui_slot = i
	assert_eq(Audio._voices[ui_slot][0].process_mode, Node.PROCESS_MODE_ALWAYS)
	Audio.play_cue("slime_tackle")
	for i in Audio.VOICES:
		if Audio._pool.cue_at(i) == "slime_tackle":
			assert_eq(Audio._voices[i][0].process_mode, Node.PROCESS_MODE_PAUSABLE)

# --- music director -------------------------------------------------------------

func _director() -> MusicDirector:
	var d := MusicDirector.new()
	d.setup(CueCatalog.load_file("res://data/audio/cues.json"), OneshotScheduler.new(RandomNumberGenerator.new()))
	add_child_autofree(d)
	return d

func test_crossfade_gains_keep_equal_power() -> void:
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var g := MusicDirector.fade_gains(t)
		assert_almost_eq(g.x * g.x + g.y * g.y, 1.0, 0.0001)
	assert_eq(MusicDirector.fade_gains(0.0), Vector2(0.0, 1.0))

func test_entering_the_same_biome_does_not_restart_the_bed() -> void:
	var d := _director()
	assert_true(d.set_biome("cave"))
	assert_eq(d.current_music, "res://assets/audio/music/cave.ogg")
	assert_false(d.set_biome("cave"))
	assert_true(d.set_biome("grotto"))
	assert_eq(d.current_area, "grotto")

func test_an_unknown_biome_warns_and_keeps_the_current_bed() -> void:
	var d := _director()
	d.set_biome("cave")
	assert_false(d.set_biome("moon"))
	assert_eq(d.current_area, "cave")
	assert_push_warning_count(1)

func test_the_audio_autoload_switches_biome_and_reverb() -> void:
	Audio.director.current_area = ""
	Audio.set_biome("flooded")
	await get_tree().create_timer(1.2, true).timeout
	var reverb := AudioServer.get_bus_effect(AudioServer.get_bus_index("SFX_World"), 0) as AudioEffectReverb
	assert_almost_eq(reverb.wet, 0.45, 0.02)
	Audio.set_biome("cave")
```

Add to `tests/test_autoloads.gd` at the end of `test_autoloads_boot_with_valid_content_and_wiring`:

```gdscript
	assert_not_null(Audio.catalog)
	assert_eq(Audio.catalog.validate(func(p: String) -> bool: return ResourceLoader.exists(p)), [])
	assert_true(EventBus.world_event.is_connected(Audio._on_event))
	assert_true(EventBus.game_event.is_connected(Audio._on_event))
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh audio_runtime`
Expected: FAIL with an engine error (`Identifier "Audio" not declared` or `Identifier "MusicDirector" not declared`).

- [ ] **Step 3: Add the EventBus channel**

Replace `autoload/event_bus.gd` with:

```gdscript
extends Node
## Global event channels.
## game_event: gameplay events. Only the player's components emit here. SkillRules and the
## Compendium count them.
## world_event: audio-only semantic moments (landings, hits, menus). Never counted; only Audio
## listens. Enemies and world objects may emit here: these are not gameplay events.

signal game_event(name: String, tags: Dictionary)
signal world_event(name: String, tags: Dictionary)
```

- [ ] **Step 4: Write `music_director.gd`**

Create `scripts/audio/music_director.gd`:

```gdscript
class_name MusicDirector
extends Node
## The music and ambience beds. Each has two players so a biome change can crossfade: the new bed
## fades in while the old one fades out with equal power (sin / cos), so the blend has no dip.

const ASSET_DIR := "res://assets/audio/"
const FADE_SECONDS := 2.0
const SILENT_DB := -80.0
const FLOOR_LINEAR := 0.0001

var current_area := ""
var current_music := ""
var scheduler: OneshotScheduler
var _catalog: CueCatalog
var _music: Array = []
var _ambience: Array = []
var _front := 0  # which player of each pair is the audible bed
var _fade: Tween

func _init() -> void:
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		var a := AudioStreamPlayer.new()
		a.bus = "Ambience"
		_music.append(m)
		_ambience.append(a)

func _ready() -> void:
	for p in _music + _ambience:
		p.volume_db = SILENT_DB
		add_child(p)

func setup(catalog: CueCatalog, p_scheduler: OneshotScheduler) -> void:
	_catalog = catalog
	scheduler = p_scheduler

## Equal-power gains for a fade at t in 0..1: x fades in, y fades out.
static func fade_gains(t: float) -> Vector2:
	var a := clampf(t, 0.0, 1.0) * PI / 2.0
	return Vector2(sin(a), cos(a))

## True when the bed changed. The same area, or an area with no bed, changes nothing.
func set_biome(area: String) -> bool:
	if area == current_area:
		return false
	var bed: Dictionary = _catalog.biomes.get(area, {})
	if bed.is_empty():
		push_warning("MusicDirector: unknown biome '%s'" % area)
		return false
	var music := _load_loop(str(bed["music"]))
	var ambience := _load_loop(str(bed["ambience"]))
	if music == null or ambience == null:
		push_warning("MusicDirector: could not load the beds for '%s'" % area)
		return false
	current_area = area
	current_music = ASSET_DIR + str(bed["music"])
	_front = 1 - _front
	_start(_music[_front], music)
	_start(_ambience[_front], ambience)
	scheduler.set_biome(bed["oneshots"])
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_method(_apply_fade, 0.0, 1.0, FADE_SECONDS)
	return true

func _start(player: AudioStreamPlayer, stream: AudioStream) -> void:
	player.stream = stream
	player.volume_db = SILENT_DB
	player.play()

func _apply_fade(t: float) -> void:
	var g := fade_gains(t)
	for pair in [_music, _ambience]:
		pair[_front].volume_db = linear_to_db(maxf(g.x, FLOOR_LINEAR))
		pair[1 - _front].volume_db = linear_to_db(maxf(g.y, FLOOR_LINEAR))
		if t >= 1.0:
			pair[1 - _front].stop()

func _load_loop(file: String) -> AudioStream:
	var path := ASSET_DIR + file
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path).duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	return stream
```

- [ ] **Step 5: Write the `Audio` autoload**

Create `autoload/audio.gd`:

```gdscript
extends Node
## The Audio autoload: the one place where events become sound. Gameplay emits semantic events
## (EventBus.game_event, EventBus.world_event) and never names a cue, a bus or a file;
## data/audio/cues.json maps each event to a cue. Registered after Compendium (the settings live
## in its Profile) and SkillRules (its signals feed the stingers).

const VOICES := 16
const CATALOG_PATH := "res://data/audio/cues.json"
const DUCK_DB := -4.0
const DUCK_ATTACK := 0.15
const DUCK_RELEASE := 0.6
const REVERB_SECONDS := 1.0

var catalog: CueCatalog
var settings := AudioSettings.new()
var director: MusicDirector
var last_cue := ""  # the last cue that started; tests and the preview tool read it
var _clock: Callable
var _pool: VoicePool
var _combo: ComboPitch
var _rng := RandomNumberGenerator.new()
var _voices: Array = []   # per slot: [AudioStreamPlayer, AudioStreamPlayer2D]
var _loops := {}          # looping cue id -> slot
var _streams := {}        # "path|loop" -> AudioStream, or null for a file that would not load
var _duck_holds := 0
var _duck_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the duck and crossfade tweens run while the game is paused
	_rng.randomize()
	catalog = CueCatalog.load_file(CATALOG_PATH)
	for e in catalog.validate(func(p: String) -> bool: return ResourceLoader.exists(p)):
		push_error("audio: " + e)
	_clock = func() -> float: return Time.get_ticks_msec() / 1000.0
	_pool = VoicePool.new(VOICES, _clock)
	_combo = ComboPitch.new(_clock)
	for i in VOICES:
		var flat := AudioStreamPlayer.new()
		var spatial := AudioStreamPlayer2D.new()
		flat.finished.connect(_on_voice_finished.bind(i))
		spatial.finished.connect(_on_voice_finished.bind(i))
		add_child(flat)
		add_child(spatial)
		_voices.append([flat, spatial])
	director = MusicDirector.new()
	director.setup(catalog, OneshotScheduler.new(_rng))
	add_child(director)
	settings.load_from(Compendium.profile)
	settings.apply()
	EventBus.game_event.connect(_on_event)
	EventBus.world_event.connect(_on_event)
	SkillRules.skill_unlocked.connect(func(id: String) -> void: _on_event("skill_unlocked", {"id": id}))
	SkillRules.skill_leveled.connect(func(id: String, level: int) -> void: _on_event("skill_leveled", {"id": id, "level": level}))
	SkillRules.evolution_ready.connect(func(id: String) -> void: _on_event("evolution_ready", {"id": id}))
	SkillRules.run_started.connect(reset)

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for shot in director.scheduler.advance(delta):
		play_cue(shot["cue"], player.global_position + shot["offset"])

func set_biome(area: String) -> void:
	if director.set_biome(area):
		_fade_reverb(float(catalog.biomes[area]["reverb_wet"]))

func adjust_setting(key: String, direction: int) -> void:
	settings.adjust(key, direction)
	settings.apply()

## Silences everything and forgets cooldowns and combos: every voice stops, every loop ends and
## the duck lets go. A new run, a death and a scene reload all start from here.
func reset() -> void:
	for cue_id in _loops.keys():
		stop_loop(cue_id)
	for pair in _voices:
		for voice in pair:
			voice.stop()
	_pool = VoicePool.new(VOICES, _clock)
	_combo = ComboPitch.new(_clock)
	_duck_holds = 0
	_fade_duck(0.0, DUCK_RELEASE)

func is_looping(cue_id: String) -> bool:
	return _loops.has(cue_id)

func stop_loop(cue_id: String) -> void:
	if not _loops.has(cue_id):
		return
	var slot: int = _loops[cue_id]
	_loops.erase(cue_id)
	for voice in _voices[slot]:
		voice.stop()
	_pool.release(slot)

func play_cue(cue_id: String, pos: Vector2 = Vector2.INF) -> void:
	var rule: Dictionary = catalog.cues.get(cue_id, {})
	if rule.is_empty():
		return
	var loop := bool(rule.get("loop", false))
	if loop and _loops.has(cue_id):
		return
	var stream := _stream(catalog.pick_file(cue_id, _rng), loop)
	if stream == null:
		return
	var volume := float(rule.get("volume_db", 0.0))
	var slot := _pool.acquire(cue_id, volume, float(rule.get("cooldown", 0.0)))
	if slot == -1:
		return
	for looping in _loops.keys():  # a stolen voice ends the loop it was carrying
		if _loops[looping] == slot:
			_loops.erase(looping)
	var spatial := bool(rule.get("positional", false)) and pos != Vector2.INF
	var pair: Array = _voices[slot]
	pair[0].stop()
	pair[1].stop()
	var voice = pair[1] if spatial else pair[0]
	voice.stream = stream
	voice.bus = str(rule["bus"])
	voice.volume_db = volume
	voice.process_mode = Node.PROCESS_MODE_ALWAYS if str(rule["bus"]) == "UI" else Node.PROCESS_MODE_PAUSABLE
	voice.pitch_scale = _pitch(cue_id, rule)
	if spatial:
		voice.global_position = pos
	voice.play()
	if loop:
		_loops[cue_id] = slot
	last_cue = cue_id
	if bool(rule.get("duck", false)):
		_duck_for(stream.get_length())

func _on_event(event_name: String, tags: Dictionary) -> void:
	if event_name == "player_died":
		reset()  # the heartbeat and the run loop end before the death cue plays
	if event_name == "menu_opened":
		_hold_duck()
	elif event_name == "menu_closed":
		_release_duck()
		if settings.dirty:
			settings.save_to(Compendium.profile)
	var routed := catalog.route(event_name, tags)
	if routed.has("cue"):
		play_cue(routed["cue"], tags.get("pos", Vector2.INF))
	elif routed.has("stop"):
		stop_loop(routed["stop"])

func _on_voice_finished(slot: int) -> void:
	_pool.release(slot)

func _pitch(cue_id: String, rule: Dictionary) -> float:
	var pitch := 1.0 + _rng.randf_range(-1.0, 1.0) * float(rule.get("pitch_jitter", 0.0))
	var combo: Dictionary = rule.get("combo", {})
	if not combo.is_empty():
		var steps := _combo.next(cue_id, float(combo["window"]), int(combo["max_steps"]))
		pitch *= pow(2.0, steps * float(combo["step"]) / 12.0)  # step is in semitones
	return pitch

func _stream(path: String, loop: bool) -> AudioStream:
	var key := "%s|%s" % [path, loop]
	if _streams.has(key):
		return _streams[key]
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = load(path).duplicate()
		if loop and stream is AudioStreamOggVorbis:
			stream.loop = true
	else:
		push_warning("audio: cannot load '%s'" % path)
	_streams[key] = stream  # a failure is cached too, so it warns once
	return stream

func _hold_duck() -> void:
	_duck_holds += 1
	_fade_duck(DUCK_DB, DUCK_ATTACK)

func _release_duck() -> void:
	_duck_holds = maxi(0, _duck_holds - 1)
	if _duck_holds == 0:
		_fade_duck(0.0, DUCK_RELEASE)

func _duck_for(seconds: float) -> void:
	_hold_duck()
	get_tree().create_timer(seconds, true).timeout.connect(_release_duck)

func _fade_duck(target_db: float, seconds: float) -> void:
	var i := AudioServer.get_bus_index("Music")
	if i == -1 or AudioServer.get_bus_effect_count(i) == 0:
		return
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_property(AudioServer.get_bus_effect(i, 0), "volume_db", target_db, seconds)

func _fade_reverb(wet: float) -> void:
	var i := AudioServer.get_bus_index("SFX_World")
	if i == -1 or AudioServer.get_bus_effect_count(i) == 0:
		return
	create_tween().tween_property(AudioServer.get_bus_effect(i, 0), "wet", wet, REVERB_SECONDS)
```

- [ ] **Step 6: Register the autoload**

In `project.godot`, add after the `Announcer=` line in `[autoload]`:

```
Audio="*res://autoload/audio.gd"
```

- [ ] **Step 7: Import and run the audio tests**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh audio_runtime`
Expected: a `PASS: <n> tests` line with no failures. Then run `tools/run_tests.sh audio_settings` and `tools/run_tests.sh autoloads`; both PASS.

While planning, a headless probe printed `ERROR: Condition "ret != noErr" is true` once. It is a macOS CoreAudio message from the audio driver, not from GDScript; `--headless` already selects the Dummy audio driver and the existing suite passes with the message present. If a test fails with that text, read `.tmp/test-logs/gut.log` to see where it fires and report it. Do not change tests to swallow it.

If `test_the_duck_still_runs_while_the_tree_is_paused` stalls the runner (the 180 s ceiling reports FAIL), the cause is GUT's own processing under pause. Diagnose from `.tmp/test-logs/gut.log` before changing anything; the intended fix is to keep the paused assertion but read the duck value through a `SceneTreeTimer` created with `process_always = true` as written, not to delete the pause.

- [ ] **Step 8: Commit**

```bash
git add autoload/event_bus.gd autoload/audio.gd autoload/audio.gd.uid scripts/audio project.godot tests/test_audio_runtime.gd tests/test_audio_runtime.gd.uid tests/test_autoloads.gd
git commit -m "feat: Audio autoload turns game and world events into sound, with duck, reverb and biome beds"
```

---

### Task 9: Player audio events

**Files:**
- Create: `scripts/player/player_audio_events.gd`
- Modify: `scripts/player/player.gd`
- Test: `tests/test_audio_player_events.gd`

**Interfaces:**
- Consumes: `EventBus.world_event`.
- Produces: `class_name PlayerAudioEvents extends RefCounted`: consts `HARD_LANDING_SPEED = 400.0`, `MIN_LANDING_SPEED = 60.0`, `RUN_SPEED = 40.0`; var `emit_event: Callable` (when invalid, emits on `EventBus.world_event`); `update(on_floor: bool, fall_speed: float, vx: float, spread: bool, wall_sliding: bool)`; `reset()`. Events emitted: `landed {hard: bool, speed: float}`, `run_started`, `run_stopped`, `wall_slide_started`, `wall_slide_stopped`. `Player` gains `var audio_events := PlayerAudioEvents.new()` and emits `tackled`, `spread {on: bool}`, `eat_started {pos: Vector2}`, `evolved {id: String}`, `leveled_up {level: int}`, `player_died`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_audio_player_events.gd`:

```gdscript
extends GutTest
## The player's audio-only events: landings, run and wall-slide loops, and the moments Player emits directly.

var seen: Array = []
var rules: SkillRulesEngine
var compendium: CompendiumModel
var player: Player

func _record(n: String, t: Dictionary) -> void:
	seen.append([n, t])

func _names() -> Array:
	return seen.map(func(e): return e[0])

func before_each() -> void:
	seen = []
	EventBus.world_event.connect(_record)

func after_each() -> void:
	EventBus.world_event.disconnect(_record)

func _tracker() -> PlayerAudioEvents:
	var p := PlayerAudioEvents.new()
	p.emit_event = _record
	return p

func test_a_hard_landing_reports_its_speed() -> void:
	var p := _tracker()
	p.update(false, 500.0, 0.0, false, false)   # falling
	p.update(true, 500.0, 0.0, false, false)    # touches down at 500 px/s
	assert_eq(seen, [["landed", {"hard": true, "speed": 500.0}]])

func test_a_soft_landing_and_no_landing_from_a_tiny_drop() -> void:
	var p := _tracker()
	p.update(false, 200.0, 0.0, false, false)
	p.update(true, 200.0, 0.0, false, false)
	assert_eq(seen, [["landed", {"hard": false, "speed": 200.0}]])
	seen = []
	p.update(false, 30.0, 0.0, false, false)
	p.update(true, 30.0, 0.0, false, false)
	assert_eq(seen, [])

func test_standing_on_the_floor_never_lands_again() -> void:
	var p := _tracker()
	for i in 10:
		p.update(true, 0.0, 0.0, false, false)
	assert_eq(seen, [])

func test_running_starts_and_stops_once_per_run() -> void:
	var p := _tracker()
	p.update(true, 0.0, 140.0, false, false)
	p.update(true, 0.0, 140.0, false, false)
	p.update(true, 0.0, 0.0, false, false)
	assert_eq(_names(), ["run_started", "run_stopped"])

func test_running_stops_when_leaving_the_floor_or_spreading() -> void:
	var p := _tracker()
	p.update(true, 0.0, 140.0, false, false)
	p.update(false, 100.0, 140.0, false, false)
	assert_eq(_names(), ["run_started", "run_stopped"])
	seen = []
	p.update(true, 0.0, 140.0, false, false)
	p.update(true, 0.0, 140.0, true, false)
	assert_eq(_names(), ["run_started", "run_stopped"])

func test_wall_slide_starts_and_stops() -> void:
	var p := _tracker()
	p.update(false, 80.0, 0.0, false, true)
	p.update(false, 80.0, 0.0, false, true)
	p.update(false, 80.0, 0.0, false, false)
	assert_eq(_names(), ["wall_slide_started", "wall_slide_stopped"])

func test_reset_ends_a_run_loop_and_says_nothing_the_second_time() -> void:
	var p := _tracker()
	p.update(true, 0.0, 140.0, false, false)
	seen = []
	p.reset()
	p.reset()
	assert_eq(_names(), ["run_stopped"])

func test_reset_ends_a_wall_slide_loop() -> void:
	var p := _tracker()
	p.update(false, 80.0, 0.0, false, true)
	seen = []
	p.reset()
	assert_eq(_names(), ["wall_slide_stopped"])

# --- Player emits the rest -------------------------------------------------------

func _player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	return player

func test_tackle_spread_and_level_up_emit_world_events() -> void:
	_player()
	player.do_tackle()
	assert_has(_names(), "tackled")
	player.set_spread(true)
	assert_true(seen.any(func(e): return e[0] == "spread" and e[1]["on"] == true))
	player.set_spread(false)
	assert_true(seen.any(func(e): return e[0] == "spread" and e[1]["on"] == false))
	player.award_xp(1000)
	assert_has(_names(), "leveled_up")

func test_dying_says_so_and_ends_the_loops() -> void:
	_player()
	player.audio_events.emit_event = _record
	player.audio_events.update(true, 0.0, 140.0, false, false)
	seen = []
	player.receive_hit(999, "physical")
	assert_has(_names(), "player_died")
	assert_has(_names(), "run_stopped")

func test_setting_spread_to_the_same_state_is_silent() -> void:
	_player()
	seen = []
	player.set_spread(false)
	assert_eq(seen, [])
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh audio_player_events`
Expected: FAIL with an engine error (`Identifier "PlayerAudioEvents" not declared`).

- [ ] **Step 3: Write `player_audio_events.gd`**

Create `scripts/player/player_audio_events.gd`:

```gdscript
class_name PlayerAudioEvents
extends RefCounted
## Turns the player's per-frame physics state into audio-only world events: landings, and the
## start and stop of the run and wall-slide loops. Emits on EventBus.world_event unless a test
## injects emit_event.

const HARD_LANDING_SPEED := 400.0  # px/s: a drop of about 90 px
const MIN_LANDING_SPEED := 60.0    # slower than this is a step, not a landing
const RUN_SPEED := 40.0

var emit_event: Callable = Callable()
var _was_on_floor := true
var _running := false
var _sliding := false

## fall_speed is velocity.y read before move_and_slide(), which zeroes it on contact.
func update(on_floor: bool, fall_speed: float, vx: float, spread: bool, wall_sliding: bool) -> void:
	if on_floor and not _was_on_floor and fall_speed >= MIN_LANDING_SPEED:
		_emit("landed", {"hard": fall_speed >= HARD_LANDING_SPEED, "speed": fall_speed})
	_was_on_floor = on_floor
	_set_running(on_floor and not spread and absf(vx) > RUN_SPEED)
	_set_sliding(wall_sliding)

## Ends any loop that is running (death, a new run).
func reset() -> void:
	_set_running(false)
	_set_sliding(false)

func _set_running(now: bool) -> void:
	if now == _running:
		return
	_running = now
	if now:
		_emit("run_started", {})
	else:
		_emit("run_stopped", {})

func _set_sliding(now: bool) -> void:
	if now == _sliding:
		return
	_sliding = now
	if now:
		_emit("wall_slide_started", {})
	else:
		_emit("wall_slide_stopped", {})

func _emit(event_name: String, tags: Dictionary) -> void:
	if emit_event.is_valid():
		emit_event.call(event_name, tags)
	else:
		EventBus.world_event.emit(event_name, tags)
```

- [ ] **Step 4: Wire it into `Player`**

In `scripts/player/player.gd`:

1. After `var sensors := PlayerSensors.new()` add:

```gdscript
var audio_events := PlayerAudioEvents.new()
```

2. In `_physics_process`, replace the line `move_and_slide()` (the one before `if rope != null:` / `_stay_on_rope()`) with:

```gdscript
	var fall_speed := velocity.y  # move_and_slide zeroes it on landing
	move_and_slide()
	audio_events.update(is_on_floor(), fall_speed, velocity.x, spreading, _clinging())
```

3. In `do_tackle`, after `_tackle_time = TACKLE_SECONDS` add:

```gdscript
	EventBus.world_event.emit("tackled", {})
```

4. In `set_spread`, after `spreading = value` add:

```gdscript
	EventBus.world_event.emit("spread", {"on": value})
```

5. In `begin_predate`, after `_start_cover(target)` add:

```gdscript
	EventBus.world_event.emit("eat_started", {"pos": target.global_position})
```

6. In `try_evolve`, replace `progression.spend_ep(cost)\n\treturn true` with:

```gdscript
	progression.spend_ep(cost)
	EventBus.world_event.emit("evolved", {"id": id})
	return true
```

7. In `_on_leveled_up`, add as the first line:

```gdscript
	EventBus.world_event.emit("leveled_up", {"level": _level})
```

and rename the parameter from `_level` to `level` in the signature and the emit (`func _on_leveled_up(level: int) -> void:` and `{"level": level}`).

8. In `_on_health_died`, add as the first lines:

```gdscript
	audio_events.reset()
	EventBus.world_event.emit("player_died", {})
```

- [ ] **Step 5: Run to verify the tests pass**

Run: `tools/run_tests.sh audio_player_events`
Expected: a `PASS: <n> tests` line with no failures. Then run the existing player suites to catch regressions: `tools/run_tests.sh player`, `tools/run_tests.sh aim`, `tools/run_tests.sh eat_cover`. Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/player/player_audio_events.gd scripts/player/player_audio_events.gd.uid scripts/player/player.gd tests/test_audio_player_events.gd tests/test_audio_player_events.gd.uid
git commit -m "feat: the player emits landing, run, wall-slide, spread, tackle, level-up and death audio events"
```

---

### Task 10: Enemy and world audio events

**Files:**
- Modify: `scripts/enemies/enemy.gd`, `scripts/world/tablet.gd`, `scripts/world/shortcut_switch.gd`, `scripts/world/glow_pool.gd`
- Test: `tests/test_audio_world_events.gd`

**Interfaces:**
- Consumes: `EventBus.world_event`.
- Produces: `enemy_hit {pos: Vector2}` (when a hit lands), `enemy_died {id: String, pos: Vector2}`, `tablet_read {pos: Vector2}`, `switch_opened {pos: Vector2}`, `pool_rested {pos: Vector2}`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_audio_world_events.gd`:

```gdscript
extends GutTest
## Enemies and world objects say what happened; they never name a sound.

var seen: Array = []
var skills_by_id := {}
var creatures := {}

func _record(n: String, t: Dictionary) -> void:
	seen.append([n, t])

func before_each() -> void:
	seen = []
	EventBus.world_event.connect(_record)
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func after_each() -> void:
	EventBus.world_event.disconnect(_record)

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = Vector2(40, 20)
	e.set_physics_process(false)
	return e

func test_a_hit_says_where_it_landed() -> void:
	var e := _enemy("toad")
	e.receive_hit(1, "physical")
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], "enemy_hit")
	assert_eq(seen[0][1]["pos"], Vector2(40, 20))

func test_a_kill_says_who_died_and_a_dead_enemy_is_not_hit_again() -> void:
	var e := _enemy("bat")
	e.receive_hit(999, "physical")
	var names := seen.map(func(x): return x[0])
	assert_has(names, "enemy_died")
	var died: Array = seen.filter(func(x): return x[0] == "enemy_died")[0]
	assert_eq(died[1]["id"], "bat")
	assert_eq(died[1]["pos"], Vector2(40, 20))
	seen = []
	e.receive_hit(1, "physical")
	assert_eq(seen, [])

func test_reading_a_tablet_says_so() -> void:
	var t := Tablet.new()
	t.setup({"id": "t1", "title": "T", "text": "words", "hint": "", "pos": Vector2(10, 20)}, {})
	add_child_autofree(t)
	t.interact(autofree(Player.new()))
	assert_eq(seen.map(func(x): return x[0]), ["tablet_read"])
	assert_eq(seen[0][1]["pos"], Vector2(10, 20))

func test_opening_a_switch_says_so() -> void:
	var s := ShortcutSwitch.new()
	s.setup({"shortcut": "a", "pos": Vector2(5, 6)}, {})
	add_child_autofree(s)
	s.open()
	assert_eq(seen.map(func(x): return x[0]), ["switch_opened"])
	assert_eq(seen[0][1]["pos"], Vector2(5, 6))

func test_soaking_in_a_glow_pool_says_so() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	var player := Player.new()
	player.setup(rules, compendium, creature_list, func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(player)
	rules.start_run()
	seen = []
	var pool := GlowPool.new()
	pool.setup({"id": "p1", "pos": Vector2(7, 8)}, {})
	add_child_autofree(pool)
	pool.interact(player)
	assert_true(seen.any(func(x): return x[0] == "pool_rested" and x[1]["pos"] == Vector2(7, 8)))
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh audio_world_events`
Expected: FAIL (assertions on empty `seen`, for example `Expected [...] to equal [...]`).

- [ ] **Step 3: Emit from the enemy and world scripts**

In `scripts/enemies/enemy.gd`:

1. Update the header note on line 10 so it stays true. Replace `## Enemies never emit gameplay events (Health has no emitter).` with:

```gdscript
## Enemies never emit gameplay events (Health has no emitter). They do emit audio-only world
## events (EventBus.world_event), which nothing counts.
```

2. In `receive_hit`, after the early-return guard and before `health.take_hit(...)`:

```gdscript
	EventBus.world_event.emit("enemy_hit", {"pos": global_position})
```

3. In `_on_died`, add as the first line:

```gdscript
	EventBus.world_event.emit("enemy_died", {"id": def.id, "pos": global_position})
```

In `scripts/world/tablet.gd`, first line of `interact`:

```gdscript
	EventBus.world_event.emit("tablet_read", {"pos": global_position})
```

In `scripts/world/shortcut_switch.gd`, first line of `open`:

```gdscript
	EventBus.world_event.emit("switch_opened", {"pos": global_position})
```

In `scripts/world/glow_pool.gd`, after the two `restore`/`heal` lines in `interact`:

```gdscript
	EventBus.world_event.emit("pool_rested", {"pos": global_position})
```

- [ ] **Step 4: Run to verify the tests pass**

Run: `tools/run_tests.sh audio_world_events`
Expected: a `PASS: <n> tests` line with no failures. Then run the suites that already cover these classes to catch regressions: `tools/run_tests.sh enemy`, `tools/run_tests.sh world`, `tools/run_tests.sh tablet`. Expected: all PASS. The existing `tests/test_enemy.gd` check that enemies emit nothing on `EventBus.game_event` still passes because these go to `world_event`.

- [ ] **Step 5: Commit**

```bash
git add scripts/enemies/enemy.gd scripts/world/tablet.gd scripts/world/shortcut_switch.gd scripts/world/glow_pool.gd tests/test_audio_world_events.gd tests/test_audio_world_events.gd.uid
git commit -m "feat: enemies, tablets, switches and glow pools emit audio world events"
```

---

### Task 11: Skill screen events, Sound tab and HUD events

**Files:**
- Modify: `scripts/ui/skill_screen.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/hud.gd`, `tests/test_skill_screen.gd:168-173`
- Test: `tests/test_audio_ui.gd`

**Interfaces:**
- Consumes: `Audio.settings`, `Audio.adjust_setting(key, direction)`, `AudioSettings.KEYS`, `AudioSettings.LABELS`.
- Produces: `SkillScreen.TABS = ["skills","compendium","bestiary","map","sound"]`; constants `TAB_X = 28.0`, `TAB_STRIDE = 102.0`, `TAB_W = 96.0`; `SkillScreen.adjust(direction: int)` (Sound tab only); `SkillScreenModel.sound_rows(settings) -> Array` of `{kind: "slider", id, name, value}`; world events `menu_opened`, `menu_closed`, `menu_move`, `menu_confirm`, `denied`, `ticker_shown`.

- [ ] **Step 1: Write the failing UI tests**

Create `tests/test_audio_ui.gd`:

```gdscript
extends GutTest
## Skill screen sounds, the Sound tab and its layout, and the HUD's denied and ticker events.

var seen: Array = []
var rules: SkillRulesEngine
var compendium: CompendiumModel
var skills: Array
var player: Player
var screen: SkillScreen

func _record(n: String, t: Dictionary) -> void:
	seen.append([n, t])

func _names() -> Array:
	return seen.map(func(e): return e[0])

func before_each() -> void:
	seen = []
	EventBus.world_event.connect(_record)
	skills = DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	screen = SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, skills)

func after_each() -> void:
	EventBus.world_event.disconnect(_record)
	get_tree().paused = false
	Audio.settings = AudioSettings.new()
	Audio.settings.apply()

func test_opening_and_closing_the_screen_emit_menu_events() -> void:
	screen.open()
	screen.close()
	assert_eq(_names(), ["menu_opened", "menu_closed"])

func test_moving_and_switching_tabs_emit_menu_move() -> void:
	screen.open()
	seen = []
	screen.switch_tab(1)
	assert_eq(_names(), ["menu_move"])

func test_moving_the_selection_emits_only_when_it_moves() -> void:
	screen.open()
	seen = []
	screen.move(-1)  # already at the top
	assert_eq(seen, [])

func test_there_are_five_tabs_and_the_wrap_includes_sound() -> void:
	assert_eq(SkillScreen.TABS.size(), 5)
	screen.open()
	screen.switch_tab(4)
	assert_eq(screen.tab(), "sound")
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "sound")

func test_the_five_tabs_fit_the_screen_and_their_labels_fit_the_tabs() -> void:
	screen.open()
	var panels: Array = screen._tab_labels
	assert_eq(panels.size(), 5)
	for p in panels:
		assert_eq(p.size.x, SkillScreen.TAB_W)
		var label: Label = p.get_child(0)
		var text_width := label.get_theme_default_font().get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, SkillScreen.FONT_MAIN).x
		assert_lte(text_width, SkillScreen.TAB_W, label.text)
	var last: Panel = panels[4]
	assert_lt(last.position.x + last.size.x, 612.0)
	for i in range(1, 5):
		assert_gt(panels[i].position.x, panels[i - 1].position.x + panels[i - 1].size.x - 0.5, "no overlap")

func test_the_sound_tab_lists_four_sliders_and_adjusts_the_selected_one() -> void:
	screen.open()
	screen.switch_tab(4)
	var rows: Array = SkillScreenModel.sound_rows(Audio.settings)
	assert_eq(rows.map(func(r): return r["id"]), ["master", "music", "ambience", "sfx"])
	assert_almost_eq(Audio.settings.values["master"], 0.8, 0.0001)
	seen = []
	screen.adjust(1)
	assert_almost_eq(Audio.settings.values["master"], 0.9, 0.0001)
	assert_has(_names(), "menu_move")
	screen.move(1)
	screen.adjust(-1)
	assert_almost_eq(Audio.settings.values["music"], 0.7, 0.0001)

func test_adjust_does_nothing_off_the_sound_tab() -> void:
	screen.open()
	screen.adjust(1)
	assert_almost_eq(Audio.settings.values["master"], 0.8, 0.0001)

func test_a_changed_slider_is_saved_when_the_screen_closes() -> void:
	screen.open()
	screen.switch_tab(4)
	screen.adjust(-1)
	assert_true(Audio.settings.dirty)
	screen.close()
	assert_false(Audio.settings.dirty)

func test_every_control_on_the_sound_tab_stays_on_the_screen() -> void:
	screen.open()
	screen.switch_tab(4)
	for c in screen.find_children("*", "Control", true, false):
		var r: Rect2 = c.get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))
```

Also update `tests/test_skill_screen.gd`: replace `test_tabs_cycle_through_all_four` (lines 168-173 and its header) with:

```gdscript
func test_tabs_cycle_through_all_five() -> void:
	_screen()
	screen.open()
	screen.switch_tab(3)
	assert_eq(screen.tab(), "map")
	screen.switch_tab(4)
	assert_eq(screen.tab(), "sound")
	screen.switch_tab(5)
	assert_eq(screen.tab(), "skills")
	screen.switch_tab(-1)
	assert_eq(screen.tab(), "sound")
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh audio_ui`
Expected: FAIL (for example `Invalid access to property 'TAB_W'` or the event lists being empty).

- [ ] **Step 3: Add the model rows**

In `scripts/ui/skill_screen_model.gd`, add at the end of the class:

```gdscript
## The Sound tab's rows: one slider per setting, in AudioSettings.KEYS order.
static func sound_rows(settings) -> Array:
	var out: Array = []
	for k in AudioSettings.KEYS:
		out.append({"kind": "slider", "id": k, "name": AudioSettings.LABELS[k], "value": float(settings.values[k])})
	return out
```

- [ ] **Step 4: Edit the skill screen**

In `scripts/ui/skill_screen.gd`:

1. Update the class header comment's first line to mention the new tab: `## Great Sage skill window (Style D): Skills, Compendium, Bestiary, Map and Sound tabs, ...` (keep the rest of the comment), and replace the TABS/const block start:

```gdscript
const TABS := ["skills", "compendium", "bestiary", "map", "sound"]
## Five tabs share the top row: they end at x = 532 on the 640 px canvas.
const TAB_X := 28.0
const TAB_STRIDE := 102.0
const TAB_W := 96.0
```

2. `open()` and `close()`:

```gdscript
func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true
	EventBus.world_event.emit("menu_opened", {})

func close() -> void:
	visible = false
	get_tree().paused = false
	EventBus.world_event.emit("menu_closed", {})
```

3. `switch_tab` emits after refreshing; `move` emits only when the selection changes:

```gdscript
func switch_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_sel = 0
	_scroll = 0
	_refresh()
	EventBus.world_event.emit("menu_move", {})

func move(delta: int) -> void:
	if _selectable.is_empty():
		return
	var before := _sel
	_sel = clampi(_sel + delta, 0, _selectable.size() - 1)
	_refresh()
	if _sel != before:
		EventBus.world_event.emit("menu_move", {})
```

4. In `accept()`, emit `menu_confirm` after each action that changes something. Replace the two action paths:

```gdscript
	if id != "" and _rows[_selectable[_sel]]["kind"] == "ready":
		if _player.try_evolve(id):
			EventBus.world_event.emit("menu_confirm", {})
		_refresh()
		return
	if tab() != "skills" or id == "" or SkillEffects.active_scene(_defs[id]) == "":
		return
	var slots := _player.skillset.slots
	slots.assign(slots.next_slot_for(id), id)
	EventBus.world_event.emit("menu_confirm", {})
	_refresh()
```

5. Add `adjust` after `accept`:

```gdscript
## Sound tab: changes the selected slider by one step (direction is -1 or +1).
func adjust(direction: int) -> void:
	if tab() != "sound" or _selectable.is_empty():
		return
	Audio.adjust_setting(str(_rows[_selectable[_sel]]["id"]), direction)
	EventBus.world_event.emit("menu_move", {})
	_refresh()
```

6. In `_unhandled_input`, add left/right handling before the `menu_accept` branch:

```gdscript
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		adjust(1)
```

7. In `_build_frame`, replace the tab loop body's two lines that use 128 and 120:

```gdscript
	for i in TABS.size():
		var tab_panel := _panel(_frame, Vector2(TAB_X + i * TAB_STRIDE, 10), Vector2(TAB_W, 20), COL_ROW, 1)
		var l := _label(tab_panel, TABS[i].to_upper(), Vector2(0, 3), Vector2(TAB_W, 14), FONT_MAIN, Color.WHITE)
```

8. In `_refresh`, add a Sound branch directly after the map branch (after its `return`):

```gdscript
	if tab() == "sound":
		_rows = SkillScreenModel.sound_rows(Audio.settings)
		_selectable = []
		for i in _rows.size():
			_selectable.append(i)
		_sel = clampi(_sel, 0, _rows.size() - 1)
		_hint.text = "LB/RB Tabs    Left/Right Adjust    B Back" if Controls.using_joypad else "Q/E Tabs    A/D Adjust    Esc Back"
		_build_stats()
		_clear(_list)
		_clear(_detail)
		_build_sound()
		return
```

9. Add `_build_sound` next to `_build_map`:

```gdscript
func _build_sound() -> void:
	_label(_list, "SOUND", Vector2(LIST_X, LIST_TOP), Vector2(200, 14), FONT_BIG, COL_TITLE)
	var y := LIST_TOP + 30.0
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if i == _sel:
			_panel(_list, Vector2(LIST_X - 4.0, y - 5.0), Vector2(454.0, 24.0), COL_SELECTED, 1)
		_label(_list, r["name"], Vector2(LIST_X, y), Vector2(110, 14), FONT_MAIN, Color.WHITE)
		_bar(_list, Vector2(LIST_X + 120.0, y + 3.0), Vector2(240, 8), r["value"], COL_PIP_ON)
		_label(_list, "%d%%" % int(round(r["value"] * 100.0)), Vector2(LIST_X + 372.0, y), Vector2(60, 14), FONT_MAIN, COL_DIM)
		y += 34.0
```

- [ ] **Step 5: HUD events**

In `scripts/ui/hud.gd`:

1. Replace the `not_enough_mp` connection (line 41) with:

```gdscript
	player.not_enough_mp.connect(func(_id: String) -> void:
		_ticker_lines.append(["Not enough MP", TICKER_SECONDS])
		EventBus.world_event.emit("denied", {}))
```

2. Add a member `var _last_popup := ""` next to the other vars, and in `_process` after `_popup.text = popup_text()`:

```gdscript
	if _popup.text != "" and _popup.text != _last_popup:
		EventBus.world_event.emit("ticker_shown", {"kind": "unlock"})
	_last_popup = _popup.text
```

and inside the `while not entry.is_empty():` loop, after the `_ticker_lines.append(...)` line:

```gdscript
		EventBus.world_event.emit("ticker_shown", {"kind": entry["kind"]})
```

- [ ] **Step 6: Run to verify**

Run: `tools/run_tests.sh audio_ui`
Expected: a `PASS: <n> tests` line with no failures. Then run `tools/run_tests.sh skill_screen`, `tools/run_tests.sh map`, `tools/run_tests.sh hud` and `tools/run_tests.sh game`. Expected: all PASS. The existing "every control inside 640×360" test in `test_skill_screen.gd` must still pass with the new tab layout.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/skill_screen.gd scripts/ui/skill_screen_model.gd scripts/ui/hud.gd tests/test_audio_ui.gd tests/test_audio_ui.gd.uid tests/test_skill_screen.gd
git commit -m "feat: menu and HUD sounds, and a Sound tab with four volume sliders on the skill screen"
```

---

### Task 12: Biome on room entry, boundary and coverage tests, scene reload

**Files:**
- Modify: `scripts/game.gd`
- Test: `tests/test_audio_boundary.gd`, `tests/test_audio_game.gd`

**Interfaces:**
- Consumes: `Audio.set_biome`, `Audio.director`, `CueCatalog`.
- Produces: `Game._on_room_entered` calls `Audio.set_biome(world.rooms[id].area)`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_audio_boundary.gd`:

```gdscript
extends GutTest
## Gameplay says what happened; Audio decides the sound. These tests read the source to keep that true.

const ROOTS := ["res://scripts", "res://autoload"]
const AUDIO_OWNED := ["res://autoload/audio.gd"]

var catalog: CueCatalog

func before_all() -> void:
	catalog = CueCatalog.load_file("res://data/audio/cues.json")

func _gd_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out

func _gameplay_files() -> Array:
	var out: Array = []
	for root in ROOTS:
		for f in _gd_files(root):
			if not AUDIO_OWNED.has(f) and not f.begins_with("res://scripts/audio/"):
				out.append(f)
	return out

func test_gameplay_scripts_name_no_cue_and_never_call_audio_play() -> void:
	var play := RegEx.create_from_string("Audio\\.(play|play_cue|stop_loop)\\b")
	var files := _gameplay_files()
	assert_gt(files.size(), 50)
	for f in files:
		var text := FileAccess.get_file_as_string(f)
		assert_null(play.search(text), "%s calls Audio.play*" % f)
		for id in catalog.cues:
			assert_false(text.contains('"%s"' % id), "%s names the cue %s" % [f, id])

func test_every_emitted_world_event_has_a_catalog_entry() -> void:
	var emitted := RegEx.create_from_string("(?:world_event\\.emit|_emit)\\(\"([a-z_]+)\"")
	var names := {}
	for f in _gameplay_files():
		for m in emitted.search_all(FileAccess.get_file_as_string(f)):
			names[m.get_string(1)] = f
	assert_gt(names.size(), 20)
	for n in names:
		assert_true(catalog.events.has(n), "%s (emitted in %s) has no entry in data/audio/cues.json" % [n, names[n]])

func test_every_event_entry_that_plays_is_reachable_or_reserved() -> void:
	# Events the catalog maps but no script emits yet; each is reserved on purpose.
	var reserved := ["water_entered", "water_exited"]
	var emitted := RegEx.create_from_string("(?:world_event\\.emit|_emit)\\(\"([a-z_]+)\"")
	var names := {}
	for f in _gameplay_files():
		for m in emitted.search_all(FileAccess.get_file_as_string(f)):
			names[m.get_string(1)] = true
	for n in catalog.events:
		if str(n).begins_with("_") or Events.ALL.has(n) or ["skill_unlocked", "skill_leveled", "evolution_ready"].has(n):
			continue
		assert_true(names.has(n) or reserved.has(n), "%s is in the catalog but nothing emits it" % n)
```

Create `tests/test_audio_game.gd`:

```gdscript
extends GutTest
## The game wires the biome on room entry, and a scene reload does not restart the music or leave loops running.

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()
	Audio.reset()

func test_entering_a_room_sets_the_biome_of_its_area() -> void:
	Audio.director.current_area = ""
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(Audio.director.current_area, game.world.rooms[game.world.current_id].area)
	assert_eq(Audio.director.current_area, "cave")

func test_a_second_game_in_the_same_biome_does_not_restart_the_bed() -> void:
	var first = load("res://scenes/main.tscn").instantiate()
	add_child(first)
	await wait_physics_frames(5)
	var path: String = Audio.director.current_music
	first.queue_free()
	await wait_physics_frames(2)
	var second = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(second)
	await wait_physics_frames(5)
	assert_eq(Audio.director.current_music, path)
	assert_false(Audio.director.set_biome("cave"), "still cave: nothing to restart")

func test_dying_ends_the_loops() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	EventBus.world_event.emit("run_started", {})
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	assert_true(Audio.is_looping("slime_run"))
	game.player.receive_hit(9999, "physical")
	assert_false(Audio.is_looping("slime_run"), "the player's death ends the run loop")
	assert_false(Audio.is_looping("slime_heartbeat"), "the heartbeat stops on the death card")
	EventBus.game_event.emit(Events.HP_LOW_ENTERED, {})
	SkillRules.run_started.emit()
	assert_false(Audio.is_looping("slime_heartbeat"), "a new run ends a heartbeat left over")
```

- [ ] **Step 2: Run to verify it fails**

Run: `tools/run_tests.sh audio_game`
Expected: FAIL on `test_entering_a_room_sets_the_biome_of_its_area` (`current_area` is `""`). The boundary tests may already pass; run `tools/run_tests.sh audio_boundary` and read the result: if any file fails, fix that file (move the cue name out of gameplay, or add the missing `events` entry) rather than weakening the test.

- [ ] **Step 3: Set the biome on room entry**

In `scripts/game.gd`, replace `_on_room_entered` with:

```gdscript
## Each biome sets its own ambient light and sound: the bright Cave, a darker deep, and so on.
func _on_room_entered(id: String) -> void:
	var area: String = world.rooms[id].area
	var target: Color = TerrainArt.ambient(area, AMBIENT)
	var tw := create_tween()
	tw.tween_property(ambient, "color", target, 0.6)
	Audio.set_biome(area)
```

- [ ] **Step 4: Run to verify the tests pass**

Run: `tools/run_tests.sh audio_game` then `tools/run_tests.sh audio_boundary`
Expected: both PASS. Then `tools/run_tests.sh game` and `tools/run_tests.sh world`: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/game.gd tests/test_audio_boundary.gd tests/test_audio_boundary.gd.uid tests/test_audio_game.gd tests/test_audio_game.gd.uid
git commit -m "feat: rooms set the biome bed, and tests keep gameplay free of cue names"
```

---

### Task 13: Preview tool, checklist, spec write-back and full verification

**Files:**
- Create: `tools/audio/preview.gd`, `tools/audio/preview.tscn`
- Modify: `docs/playtest-checklist.md`, `docs/superpowers/specs/2026-09-28-polished-sound-design.md`

**Interfaces:**
- Consumes: `Audio.catalog`, `Audio.play_cue`, `Audio.stop_loop`, `Audio.is_looping`, `Audio.set_biome`, `CueCatalog.BIOMES`.

- [ ] **Step 1: Write the preview scene**

Create `tools/audio/preview.gd`:

```gdscript
extends Control
## Audition every biome bed and every cue. Run from the project root:
##   godot --path . res://tools/audio/preview.tscn
## Loop cues toggle: press once to start, again to stop.

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_header(box, "Biome beds (music + ambience)")
	for area in CueCatalog.BIOMES:
		_button(box, "biome: " + area, func() -> void: Audio.set_biome(area))
	var by_bus := {}
	for id in Audio.catalog.cues:
		var bus: String = Audio.catalog.cues[id]["bus"]
		if not by_bus.has(bus):
			by_bus[bus] = []
		by_bus[bus].append(id)
	for bus in by_bus:
		_header(box, "Cues on " + bus)
		for id in by_bus[bus]:
			var looping: bool = Audio.catalog.cues[id].get("loop", false)
			_button(box, id + ("  (loop)" if looping else ""), func() -> void: _play(id, looping))

func _play(id: String, looping: bool) -> void:
	if looping and Audio.is_looping(id):
		Audio.stop_loop(id)
	else:
		Audio.play_cue(id)

func _header(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	box.add_child(l)

func _button(box: VBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(action)
	box.add_child(b)
```

Create `tools/audio/preview.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://tools/audio/preview.gd" id="1"]

[node name="Preview" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 2: Check the preview scene loads**

Add to `tests/test_audio_boundary.gd`:

```gdscript
func test_the_preview_scene_builds_a_button_per_cue_and_biome() -> void:
	var preview = load("res://tools/audio/preview.tscn").instantiate()
	add_child_autofree(preview)
	var buttons := preview.find_children("*", "Button", true, false)
	assert_eq(buttons.size(), catalog.cues.size() + CueCatalog.BIOMES.size())
```

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh audio_boundary`
Expected: `PASS`.

- [ ] **Step 3: Add the by-ear pass to the playtest checklist**

Append to `docs/playtest-checklist.md`:

```markdown
## Sound (by ear; headless tests cannot judge how it sounds)

- [ ] Open `tools/audio/preview.tscn` and play every cue. Note any that clip, click, sound harsh, or are far louder or quieter than their neighbours. Tune `volume_db` in `art_source/audio/recipes/*.json`, then rebuild with `tools/audio/synth_sfx.py` and `tools/audio/build_cues.py`.
- [ ] Play each biome bed for at least a minute. The loop point should be inaudible.
- [ ] In a run: jump, land from a small and a big drop, run, wall-slide, crouch-spread, tackle, eat, take a hit, drop below 30% HP (heartbeat), die. Each has a sound and none keeps looping after death or restart.
- [ ] Absorb a stack of essence: one pleasant rising chime, not a machine gun.
- [ ] Open the menu: the music dips and returns. The Sound tab's sliders change loudness; 0 is silent. Quit and relaunch: the values persist.
- [ ] Walk between rooms in the same biome: the music never restarts.
```

- [ ] **Step 4: Write the deviations back into the spec**

Edit `docs/superpowers/specs/2026-09-28-polished-sound-design.md`:

1. Under "Asset pipeline", replace the line beginning `- **Loudness targets:**` (SFX about −16 LUFS, …) with:

```markdown
- **Loudness targets:** SFX are peak-normalised to −2 dBFS and balanced by each cue's `volume_db`
  (LUFS is not meaningful for clips under half a second, and transient sounds cannot reach −16 LUFS
  under the peak ceiling). Music is about −20 LUFS and ambience about −24 LUFS. Nothing peaks
  above −1 dBTP, measured as sample peak after encoding.
- **Encoding:** Ogg Vorbis, stereo, through ffmpeg's native `vorbis` encoder (`-strict -2`), which
  accepts two channels only. Mono sources are duplicated to stereo.
- **Placeholder beds:** until a provider is chosen, `gen_bed.py` renders each bed itself with a
  built-in synth provider. A `local` provider decodes a file dropped in `art_source/audio/raw/`,
  and the ElevenLabs provider replaces the placeholders when Sean supplies a key.
```

2. In "Testing", replace items 5 and 6 (loop seams, loudness) with:

```markdown
5. **Loop seams** (Python, `tools/audio/test_assets.py`): the jump from a file's last sample to its
   first is under 3× the loudest normal sample-to-sample step, for every bed and every looping cue.
6. **Loudness** (Python, same file): music and ambience are within ±2 LU of their targets, and no
   file peaks above −1 dBFS. These are Python because they need PCM samples, which headless Godot
   cannot provide; run them with `python3 -m unittest discover -s tools/audio -p "test_*.py"`.
```

3. In "Cue coverage", replace the World row with:

```markdown
| World | tablet read, shortcut switch, glow-pool rest, water enter and exit (catalogued; emitted once a swim mechanic exists), ambience one-shots (drip, crystal ping, hum, bubble, spore) |
```

and the Enemies row with:

```markdown
| Enemies | hit, stun, death (four death cues: flyer, crawler, beast, boss, chosen by creature id in the catalog) |
```

4. In "Ownership", add `tools/audio/test_*.py`, `art_source/audio/recipes/`, `art_source/audio/beds/` to the new-paths list.

- [ ] **Step 5: Run every check**

Run, in order:

1. `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_*.py" -v` — expected: all OK.
2. `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh` — expected: `PASS: <n> tests`, where n is the previous 482 plus the new audio tests, with 0 failures.
3. `git status --short` — expected: only `.DS_Store` files and `tools/slime_in_game.gd.uid` untracked (both existed before this work), no stray `.tmp.ogg`.

Read the full-suite `PASS` line itself. If any earlier test fails, diagnose which of this plan's tasks changed its assumptions (the tab count and the `EventBus` comment are the likeliest) and fix the cause.

- [ ] **Step 6: Commit**

```bash
git add tools/audio/preview.gd tools/audio/preview.gd.uid tools/audio/preview.tscn tests/test_audio_boundary.gd docs/playtest-checklist.md docs/superpowers/specs/2026-09-28-polished-sound-design.md
git commit -m "feat: audio preview scene and by-ear checklist; write the plan's deviations back into the spec"
```

---

### Task 14: ElevenLabs bed provider (blocked on Sean's key)

This task needs `ELEVENLABS_API_KEY` in the environment (see the handoff note: an environment variable in the shell that launches Claude Code, never a file in the repo). Do not start it until Sean confirms the key is set. Everything before this task works without it.

**Files:**
- Modify: `tools/audio/gen_bed.py`, `art_source/audio/beds/*.json`
- Test: `tools/audio/test_gen_bed.py`

**Interfaces:**
- Consumes: `os.environ["ELEVENLABS_API_KEY"]`, the `prompt` field of each bed spec.
- Produces: provider `"elevenlabs"` in `gen_bed.raw_samples`; a spec object `{"provider": "elevenlabs", "seconds": 30}` per kind; raw responses saved under `art_source/audio/raw/<biome>_<kind>.mp3` (gitignored) before processing.

- [ ] **Step 1: Check the current API before coding**

Fetch the ElevenLabs API reference for music generation and sound-effect generation (WebFetch on `https://elevenlabs.io/docs/api-reference`). Confirm, and write down in the commit message: the endpoint path and JSON body for text-to-music (expected `POST https://api.elevenlabs.io/v1/music` with `prompt` and `music_length_ms`, instrumental option), the endpoint for text-to-sound-effects (expected `POST https://api.elevenlabs.io/v1/sound-generation` with `text` and `duration_seconds`, maybe `loop`), the auth header (expected `xi-api-key`), the default response format (expected MP3 bytes), and the maximum durations. If any differs from the expectation in Step 3, use the documented values.

- [ ] **Step 2: Write the failing tests (no network)**

Add to `tools/audio/test_gen_bed.py`, inside `GenBedTest`:

```python
    def test_elevenlabs_needs_the_key_in_the_environment(self):
        old = os.environ.pop("ELEVENLABS_API_KEY", None)
        try:
            with self.assertRaises(a.AudioToolError) as ctx:
                gen_bed.raw_samples({"provider": "elevenlabs", "seconds": 30, "prompt": "x"}, "t", "music")
            self.assertIn("ELEVENLABS_API_KEY", str(ctx.exception))
        finally:
            if old is not None:
                os.environ["ELEVENLABS_API_KEY"] = old

    def test_elevenlabs_saves_the_raw_response_and_decodes_it(self):
        calls = []

        def fake_fetch(url, headers, body):
            calls.append((url, headers, body))
            with tempfile.TemporaryDirectory() as d:
                p = os.path.join(d, "x.wav")
                a.write_wav(p, [0.2 * __import__("math").sin(i / 20.0) for i in range(44100)])
                with open(p, "rb") as f:
                    return f.read()

        os.environ["ELEVENLABS_API_KEY"] = "test-key"
        with tempfile.TemporaryDirectory() as d:
            spec = {"provider": "elevenlabs", "seconds": 5, "prompt": "warm cave pads"}
            samples = gen_bed.raw_samples(spec, "t", "music", raw_dir=d, fetch=fake_fetch)
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0][1]["xi-api-key"], "test-key")
            self.assertIn("warm cave pads", calls[0][2])
            self.assertTrue(os.path.exists(os.path.join(d, "t_music.mp3")))
            self.assertEqual(len(samples), 2)
        del os.environ["ELEVENLABS_API_KEY"]
```

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_gen_bed.py" -v`
Expected: FAIL (`unknown provider 'elevenlabs'` and `unexpected keyword argument 'raw_dir'`).

- [ ] **Step 3: Add the provider**

In `tools/audio/gen_bed.py`, add `import urllib.request` to the imports, add the constants and the fetch helper, and extend `raw_samples`:

```python
RAW_DIR = "art_source/audio/raw"
ELEVENLABS = {"music": "https://api.elevenlabs.io/v1/music",
              "ambience": "https://api.elevenlabs.io/v1/sound-generation"}


def _fetch(url, headers, body):
    request = urllib.request.Request(url, data=body.encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            return response.read()
    except OSError as e:
        raise audiolib.AudioToolError("request to %s failed: %s" % (url, e)) from e


def _elevenlabs(spec, biome, kind, raw_dir, fetch):
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        raise audiolib.AudioToolError("%s/%s: set ELEVENLABS_API_KEY in the environment" % (biome, kind))
    seconds = float(spec["seconds"])
    if kind == "music":
        payload = {"prompt": spec["prompt"], "music_length_ms": int(seconds * 1000), "force_instrumental": True}
    else:
        payload = {"text": spec["prompt"], "duration_seconds": seconds, "loop": True}
    data = fetch(ELEVENLABS[kind], {"xi-api-key": key, "Content-Type": "application/json"}, json.dumps(payload))
    os.makedirs(raw_dir, exist_ok=True)
    raw_path = os.path.join(raw_dir, "%s_%s.mp3" % (biome, kind))
    with open(raw_path, "wb") as f:
        f.write(data)
    return audiolib.decode_pcm(raw_path)
```

Change the signature and add the branch in `raw_samples`:

```python
def raw_samples(spec, biome, kind, raw_dir=RAW_DIR, fetch=_fetch):
    provider = spec.get("provider")
    if provider == "elevenlabs":
        return _elevenlabs(spec, biome, kind, raw_dir, fetch)
    ...  # the existing synth and local branches stay as they are
```

Adjust `_elevenlabs` and the tests to the documented request shape from Step 1 if it differed. In `main`, when a kind's spec has `"provider": "elevenlabs"` and no `prompt` of its own, fill it from the bed file's top-level `prompt` before calling `build`:

```python
            for kind in KINDS:
                if kind in spec:
                    kind_spec = dict(spec[kind])
                    kind_spec.setdefault("prompt", spec.get("prompt", ""))
                    build(biome, kind, kind_spec)
```

Note that `build(biome, kind, spec, out_root)` calls `raw_samples(spec, biome, kind)`, so real runs use the defaults.

- [ ] **Step 4: Run to verify the tests pass**

Run: `TMPDIR="$PWD/.tmp/audio-work" python3 -m unittest discover -s tools/audio -p "test_gen_bed.py" -v`
Expected: all OK, including the two new tests.

- [ ] **Step 5: Generate one bed for real, with Sean's approval of the cost**

Ask Sean before spending API credit. With approval, switch only the cave music to the provider: in `art_source/audio/beds/cave.json` set `"music": {"provider": "elevenlabs", "seconds": 30}`. Run `TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/gen_bed.py cave` with `allowed_domains: ["api.elevenlabs.io"]` on the command. Expected: `built music cave`, `art_source/audio/raw/cave_music.mp3` exists and is ignored by git, `assets/audio/music/cave.ogg` is rebuilt. Then rerun `python3 -m unittest discover -s tools/audio -p "test_assets.py" -v` (loudness and seam must still pass) and `tools/run_tests.sh audio` after an import. Let Sean listen in the preview tool; only then switch the other beds.

- [ ] **Step 6: Commit**

```bash
git add tools/audio/gen_bed.py tools/audio/test_gen_bed.py art_source/audio/beds assets/audio/music
git commit -m "feat: ElevenLabs provider for the music and ambience beds"
```

---

## Self-Review

**Spec coverage.**

| Spec section | Task |
|---|---|
| Runtime units (`Audio`, `CueCatalog`, `VoicePool`, `MusicDirector`, `AudioSettings`) | 5, 6, 7, 8 |
| Cue catalog format (`cues`, `events`, `biomes`, `_why`, loops, tag selection) | 4, 5 |
| Buses, limiter, reverb per biome, duck | 7, 8 |
| Triggers (`game_event`, `world_event`, `SkillRules` signals, room entry) | 8, 9, 10, 11, 12 |
| Cue coverage (slime, eating, skills, enemies, world, UI) | 2, 4, 9, 10, 11 |
| Music and ambience (crossfade, same-biome no-op, one-shots, `deep` reserved) | 3, 4, 6, 8, 12 |
| Asset pipeline (synth SFX, beds, build_cues, loudness, gitignore, failure behavior) | 1, 2, 3, 4 |
| Settings and persistence, five-tab layout | 7, 11 |
| Tests 1–10 | 1–4 (5, 6, 10), 5 (1, 2), 6 (3), 5 (4), 7 (7), 8 (8, 9), 12 |
| Preview tool and playtest checklist | 13 |
| Ownership list | all; `Profile`, `event_bus`, `game.gd`, `skill_screen.gd` in 7, 8, 11, 12 |

Gaps found while checking and fixed: `evolved` needed an emitter (Task 9, `try_evolve`); `denied` and `ticker_shown` needed HUD emitters (Task 11); the spec's grep test for gameplay scripts is Task 12; the spec's "every silent entry has a `_why`" is enforced in `CueCatalog.validate` (Task 5).

**Placeholder scan.** No "TBD", "similar to Task N" or undefined references. Recipe numbers are concrete starting values, stated as such.

**Type consistency.** `CueCatalog.route` returns `{"cue"}` / `{"stop"}` / `{}` in Tasks 5 and 8. `VoicePool.acquire(cue, volume_db, cooldown) -> int` matches its use in `Audio.play_cue`. `ComboPitch.next(cue, window, max_steps)` matches. `OneshotScheduler.set_biome(entry)` / `advance(delta)` match `MusicDirector` and `Audio._process`. `AudioSettings.values/dirty/adjust/apply/load_from/save_to` match Tasks 7, 8, 11. `PlayerAudioEvents.update(on_floor, fall_speed, vx, spread, wall_sliding)` matches the `Player` call. Cue ids used in `events` (Task 4) equal recipe names (Task 2): `enemy_impact`, `tablet_chime` avoid colliding with the event names `enemy_hit`, `tablet_read`, which the boundary test in Task 12 needs.

**Review Focus coverage.** (1) restart and reload: Task 8 `test_reset_stops_every_loop`, `test_a_new_run_stops_loops...`; Task 9 death; Task 12 scene tests. (2) absorb burst: Task 6 `test_a_burst_in_one_frame_plays_once`, Task 8 `test_an_absorb_burst_plays_once`. (3) slider at 0: Task 7. (4) missing file: Task 8. (5) pause: Task 8 (duck under pause, UI versus gameplay process modes).
