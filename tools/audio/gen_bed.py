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
WORK_PEAK_DB = -6.0  # level a bed is brought to before its loudness is measured


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
    # A raw pad can peak far above full scale, and the WAV used for measuring would clip it, so
    # bring it to a working level first: measure the signal that will really be encoded.
    top = audiolib.lin_to_db(max(audiolib.peak(left), audiolib.peak(right)))
    left, right = audiolib.gain(left, WORK_PEAK_DB - top), audiolib.gain(right, WORK_PEAK_DB - top)
    wanted = audiolib.TARGET_LUFS[kind] - _measure((left, right))
    wanted = min(wanted, HEADROOM_DB - WORK_PEAK_DB)  # loud enough, but never past the ceiling
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
