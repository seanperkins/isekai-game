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


def fade_ends(x, seconds=EDGE_FADE, rate=RATE):
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
    return fade_ends(mix, rate=rate) if fade_edges else mix


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
