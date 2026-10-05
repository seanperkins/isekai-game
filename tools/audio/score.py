"""Render a small chiptune score (art_source/audio/scores/<name>.json) to a seamless stereo loop.

A score is data, so the tune can be changed by editing notes instead of code:
  {"bpm", "beats_per_bar", "steps_per_bar", "bars",
   "chords":      {"Am": ["A", "C", "E"], ...},     pitch classes of each chord
   "progression": ["Am", "Am", "F", ...],           one chord per bar
   "voices":      {"lead": {"wave": pulse|tri|saw, "duty", "vibrato": [Hz, depth], "attack", "decay",
                            "sustain", "release", "lp", "gain", "pan": -1..1}},
   "tracks": {...}}
Each track has a "kind" (melody when left out):
  melody  {"voice", "bars": ["A4 - - . C5 ...", ...]}   one note name, "-" (hold) or "." (rest) per step
  arp     {"kind": "arp", "voice", "octave", "pattern": [0, 1, 2, 3, ...], "bars": [1, 1, 0, ...] (optional)}
          steps through the chord's ladder (root, third, fifth, octave); one index per step
  bass    {"kind": "bass", "voice", "octave", "patterns": {name: "r.r.o.r..."}, "bars": [name, ...]}
          r = root, o = root an octave up, 5 = fifth, "." holds the note, "_" rests
  pad     {"kind": "pad", "voice", "octave", "bars": [1, 0, ...]}   the whole chord held for the bar
  drums   {"kind": "drums", "patterns": {name: {"kick": "k...", "snare": "....s...", "hat": ..., "open": ..., "crash": ...}},
           "bars": [name, ...], "gains": {"kick": 0.6, ...}}
Every note that rings past the end of the loop wraps onto its start, so the loop is seamless by
construction and needs no crossfade. Rendering is deterministic. Run from the project root.
"""
import math
import random
import re

from audiolib import RATE, AudioToolError
import dsp

SEMITONE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
NOTE = re.compile(r"^([A-G])(#|b)?(-?\d)$")
PITCH_CLASS = re.compile(r"^([A-G])(#|b)?$")
ENV_DB = 6.9  # exp(-6.9) is -60 dB: a decay or release time is the time to fall that far
DRUM_GAINS = {"kick": 0.75, "snare": 0.45, "hat": 0.16, "open": 0.18, "crash": 0.28}
DRUM_PAN = {"kick": 0.0, "snare": 0.0, "hat": 0.25, "open": 0.25, "crash": -0.2}
LANES = tuple(DRUM_GAINS)


def _semitone(name):
    m = PITCH_CLASS.match(name)
    if not m:
        raise AudioToolError("not a pitch class: %r" % name)
    return SEMITONE[m.group(1)] + {"#": 1, "b": -1, None: 0}[m.group(2)]


def note_to_midi(name):
    m = NOTE.match(name or "")
    if not m:
        raise AudioToolError("not a note name: %r" % name)
    return 12 * (int(m.group(3)) + 1) + SEMITONE[m.group(1)] + {"#": 1, "b": -1, None: 0}[m.group(2)]


def midi_to_hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def ladder(pitch_classes, octave, count=6):
    """MIDI notes climbing through the chord from its first tone at `octave`: root, third, fifth, root, ..."""
    first = 12 * (octave + 1) + _semitone(pitch_classes[0])
    out = [first]
    while len(out) < count:
        target = _semitone(pitch_classes[len(out) % len(pitch_classes)]) % 12
        m = out[-1] + 1
        while m % 12 != target:
            m += 1
        out.append(m)
    return out


def _envelope(n, gate, v, rate=RATE):
    attack = max(v.get("attack", 0.003), 1.0 / rate)
    decay = max(v.get("decay", 0.2), 0.001)
    sustain = v.get("sustain", 0.7)
    release = max(v.get("release", 0.03), 0.001)
    out = []
    for i in range(n):
        t = i / rate
        if t < gate / rate:
            level = t / attack if t < attack else sustain + (1.0 - sustain) * math.exp(-ENV_DB * (t - attack) / decay)
        else:
            end = gate / rate
            held = end / attack if end < attack else sustain + (1.0 - sustain) * math.exp(-ENV_DB * (end - attack) / decay)
            level = held * math.exp(-ENV_DB * (t - end) / release)
        out.append(level)
    return out


def _wave(kind, freq, n, v, rate=RATE):
    vib_rate, vib_depth = v.get("vibrato", [0.0, 0.0])
    duty = v.get("duty", 0.5)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / rate
        f = freq * (1.0 + vib_depth * min(1.0, t / 0.2) * math.sin(2.0 * math.pi * vib_rate * t)) if vib_depth else freq
        phase += f / rate
        p = phase % 1.0
        if kind == "pulse":
            out.append(1.0 if p < duty else -1.0)
        elif kind == "tri":
            out.append(4.0 * abs(p - 0.5) - 1.0)
        elif kind == "saw":
            out.append(2.0 * p - 1.0)
        else:
            raise AudioToolError("unknown wave %r" % kind)
    return out


def _note_buffer(v, midi, gate):
    """One note of voice `v`: `gate` samples held, then its release."""
    release = max(v.get("release", 0.03), 0.001)
    n = gate + int(release * RATE * 1.2)
    buf = _wave(v["wave"], midi_to_hz(midi), n, v)
    if "lp" in v:
        buf = dsp.lowpass(buf, v["lp"])
    env = _envelope(n, gate, v)
    return [b * e for b, e in zip(buf, env)]


def _drum_buffers():
    rng = random.Random(1234)

    def burst(seconds, fn):
        n = int(seconds * RATE)
        return fn(n)

    def kick(n):
        body = dsp.osc("sine", n, 165.0, 42.0)
        click = dsp.highpass(dsp.noise("white", n, rng), 1500.0)
        env = dsp.envelope(n, 0.001, 0.13)
        click_env = dsp.envelope(n, 0.0005, 0.012)
        return [(b * e + 0.35 * c * ce) for b, c, e, ce in zip(body, click, env, click_env)]

    def snare(n):
        noise = dsp.lowpass(dsp.highpass(dsp.noise("white", n, rng), 1100.0), 8000.0)
        tone = dsp.osc("tri", n, 200.0, 170.0)
        return [(0.9 * x * e + 0.5 * t * te) for x, t, e, te in zip(noise, tone, dsp.envelope(n, 0.001, 0.16), dsp.envelope(n, 0.001, 0.09))]

    def hat(decay):
        def make(n):
            noise = dsp.highpass(dsp.noise("white", n, rng), 7000.0)
            return [x * e for x, e in zip(noise, dsp.envelope(n, 0.0005, decay))]
        return make

    def crash(n):
        noise = dsp.highpass(dsp.noise("white", n, rng), 3500.0)
        return [x * e for x, e in zip(noise, dsp.envelope(n, 0.001, 1.1))]

    return {"kick": burst(0.22, kick), "snare": burst(0.24, snare), "hat": burst(0.06, hat(0.04)),
            "open": burst(0.30, hat(0.22)), "crash": burst(1.3, crash)}


class _Mix:
    def __init__(self, total):
        self.n = total
        self.left = [0.0] * total
        self.right = [0.0] * total

    def add(self, start, buf, gain, pan):
        theta = (pan + 1.0) * math.pi / 4.0  # equal power: -1 is all left, +1 all right
        gl, gr = gain * math.cos(theta), gain * math.sin(theta)
        n = self.n
        left, right = self.left, self.right
        for i, s in enumerate(buf):
            k = (start + i) % n  # past the end, a ringing note lands on the start of the loop
            left[k] += s * gl
            right[k] += s * gr


def _check_bars(name, bars, count):
    if len(bars) != count:
        raise AudioToolError("track %s lists %d bars, the score has %d" % (name, len(bars), count))


def _voice(spec, track_name, track):
    voice = spec["voices"].get(track.get("voice"))
    if voice is None:
        raise AudioToolError("track %s names the voice %r, which the score does not define" % (track_name, track.get("voice")))
    return voice


def _chord(spec, bar):
    name = spec["progression"][bar]
    if name not in spec["chords"]:
        raise AudioToolError("bar %d uses the chord %r, which the score does not define" % (bar + 1, name))
    return spec["chords"][name]


def _melody(spec, mix, name, track, step_samples):
    voice = _voice(spec, name, track)
    steps = spec["steps_per_bar"]
    _check_bars(name, track["bars"], spec["bars"])
    tokens = []
    for b, bar in enumerate(track["bars"]):
        parts = bar.split()
        if len(parts) != steps:
            raise AudioToolError("track %s bar %d has %d steps, not %d: %r" % (name, b + 1, len(parts), steps, bar))
        tokens.extend(parts)
    cache = {}
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token in ("-", "."):
            i += 1
            continue
        midi = note_to_midi(token)
        j = i + 1
        while j < len(tokens) and tokens[j] == "-":
            j += 1
        gate = int(round((j - i) * step_samples * 0.94))
        key = (midi, gate)
        if key not in cache:
            cache[key] = _note_buffer(voice, midi, gate)
        mix.add(int(round(i * step_samples)), cache[key], voice.get("gain", 0.3), voice.get("pan", 0.0))
        i = j


def _arp(spec, mix, name, track, step_samples):
    voice = _voice(spec, name, track)
    steps = spec["steps_per_bar"]
    pattern = track["pattern"]
    if len(pattern) != steps:
        raise AudioToolError("track %s: the arp pattern needs %d steps" % (name, steps))
    on = track.get("bars", [1] * spec["bars"])
    _check_bars(name, on, spec["bars"])
    gate = int(round(step_samples * 0.85))
    cache = {}
    for b in range(spec["bars"]):
        if not on[b]:
            continue
        notes = ladder(_chord(spec, b), track.get("octave", 3), 4)
        for s, index in enumerate(pattern):
            midi = notes[index % len(notes)]
            if midi not in cache:
                cache[midi] = _note_buffer(voice, midi, gate)
            mix.add(int(round((b * steps + s) * step_samples)), cache[midi], voice.get("gain", 0.13), voice.get("pan", 0.0))


def _bass(spec, mix, name, track, step_samples):
    voice = _voice(spec, name, track)
    steps = spec["steps_per_bar"]
    _check_bars(name, track["bars"], spec["bars"])
    for pattern in track["patterns"].values():
        if len(pattern) != steps:
            raise AudioToolError("track %s: a bass pattern needs %d steps" % (name, steps))
    cache = {}
    for b in range(spec["bars"]):
        pattern = track["patterns"].get(track["bars"][b])
        if pattern is None:
            raise AudioToolError("track %s bar %d names the pattern %r, which it does not define" % (name, b + 1, track["bars"][b]))
        pcs = _chord(spec, b)
        root = 12 * (track.get("octave", 2) + 1) + _semitone(pcs[0])
        fifth = root + 7 if len(pcs) < 3 else ladder(pcs, track.get("octave", 2), 3)[2]
        pitch = {"r": root, "o": root + 12, "5": fifth}
        s = 0
        while s < steps:
            c = pattern[s]
            if c not in pitch:
                s += 1
                continue
            e = s + 1
            while e < steps and pattern[e] == ".":
                e += 1
            gate = int(round((e - s) * step_samples * 0.92))
            key = (pitch[c], gate)
            if key not in cache:
                cache[key] = _note_buffer(voice, pitch[c], gate)
            mix.add(int(round((b * steps + s) * step_samples)), cache[key], voice.get("gain", 0.4), voice.get("pan", 0.0))
            s = e


def _pad(spec, mix, name, track, step_samples):
    voice = _voice(spec, name, track)
    steps = spec["steps_per_bar"]
    on = track["bars"]
    _check_bars(name, on, spec["bars"])
    gate = int(round(steps * step_samples * 0.98))
    cache = {}
    for b in range(spec["bars"]):
        if not on[b]:
            continue
        for k, midi in enumerate(ladder(_chord(spec, b), track.get("octave", 3), 3)):
            if midi not in cache:
                cache[midi] = _note_buffer(voice, midi, gate)
            spread = (-0.5, 0.0, 0.5)[k % 3]
            mix.add(int(round(b * steps * step_samples)), cache[midi], voice.get("gain", 0.07), voice.get("pan", 0.0) + spread)


def _drums(spec, mix, name, track, step_samples):
    steps = spec["steps_per_bar"]
    _check_bars(name, track["bars"], spec["bars"])
    gains = dict(DRUM_GAINS, **track.get("gains", {}))
    buffers = _drum_buffers()
    for pattern_name, pattern in track["patterns"].items():
        for lane, hits in pattern.items():
            if lane not in LANES:
                raise AudioToolError("track %s pattern %s: unknown lane %r" % (name, pattern_name, lane))
            if len(hits) != steps:
                raise AudioToolError("track %s pattern %s lane %s needs %d steps" % (name, pattern_name, lane, steps))
    for b in range(spec["bars"]):
        pattern = track["patterns"].get(track["bars"][b])
        if pattern is None:
            raise AudioToolError("track %s bar %d names the pattern %r, which it does not define" % (name, b + 1, track["bars"][b]))
        for lane, hits in pattern.items():
            for s, c in enumerate(hits):
                if c != ".":
                    mix.add(int(round((b * steps + s) * step_samples)), buffers[lane], gains[lane], DRUM_PAN[lane])


def render(spec):
    """The whole score as a (left, right) pair of float lists, exactly `bars` bars long."""
    steps = spec["steps_per_bar"]
    step_samples = RATE * 60.0 / spec["bpm"] / (steps / spec["beats_per_bar"])
    if len(spec["progression"]) != spec["bars"]:
        raise AudioToolError("the progression lists %d chords for %d bars" % (len(spec["progression"]), spec["bars"]))
    for bar in range(spec["bars"]):
        _chord(spec, bar)  # an unknown chord is named whatever the tracks do with it
    mix = _Mix(int(round(spec["bars"] * steps * step_samples)))
    kinds = {"melody": _melody, "arp": _arp, "bass": _bass, "pad": _pad, "drums": _drums}
    for name, track in spec["tracks"].items():
        kind = track.get("kind", "melody")
        if kind not in kinds:
            raise AudioToolError("track %s has the unknown kind %r" % (name, kind))
        kinds[kind](spec, mix, name, track, step_samples)
    # A soft limit: loud stacked hits bend over instead of clipping.
    return ([math.tanh(s) for s in mix.left], [math.tanh(s) for s in mix.right])
