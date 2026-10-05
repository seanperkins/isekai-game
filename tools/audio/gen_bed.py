"""Build the looping music and ambience beds, one Ogg per biome and kind.

A bed spec (art_source/audio/beds/<biome>.json) holds the provider prompt and, per kind, which
provider makes the raw audio:
  "synth": a built-in pad (music) or noise wash (ambience). Placeholder that works offline.
  "score": a chiptune score (art_source/audio/scores/<name>.json, see score.py) rendered in-repo. It is a
           bar-exact loop already, so it skips the trim and the crossfade a recorded bed gets.
  "local": decode a file Sean or a provider dropped at art_source/audio/raw/ (gitignored).
Every bed is trimmed, made loop-safe with a crossfade, set to its LUFS target and encoded.
Run from the project root:
  TMPDIR="$PWD/.tmp/audio-work" python3 tools/audio/gen_bed.py [biome ...]
"""
import glob
import http.client
import json
import os
import random
import sys
import tempfile
import urllib.error
import urllib.request
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audiolib  # noqa: E402
import dsp  # noqa: E402
import score  # noqa: E402

BEDS = "art_source/audio/beds"
OUT = "assets/audio"
KINDS = ("music", "ambience")
XFADE = 2.0
RAW_DIR = "art_source/audio/raw"
ELEVENLABS = {"music": "https://api.elevenlabs.io/v1/music",
              "ambience": "https://api.elevenlabs.io/v1/sound-generation"}
# The API's documented length limits, in seconds: music 3 to 600, sound generation 0.5 to 30.
ELEVENLABS_SECONDS = {"music": (3.0, 600.0), "ambience": (0.5, 30.0)}
HEADROOM_DB = -1.5  # a bed's peak may never rise above this while it is being made loud enough
WORK_PEAK_DB = -6.0  # level a bed is brought to before its loudness is measured
EDGE_FADE = 0.01  # Vorbis zero-pads a stream's end: both ends go to silence so the wrap stays continuous


def _fetch(url, headers, body):
    request = urllib.request.Request(url, data=body.encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            data = bytearray()
            try:
                while True:
                    chunk = response.read(65536)
                    if not chunk:
                        break
                    data += chunk
            except (http.client.IncompleteRead, ConnectionResetError) as e:
                # The connection dropped mid-download. What arrived is kept; the caller checks that
                # the decoded audio is about as long as it asked for, so a real truncation is refused.
                data += getattr(e, "partial", b"")
                print("warning: response from %s was cut off after %d bytes" % (url, len(data)), file=sys.stderr)
            return bytes(data)
    except urllib.error.HTTPError as e:  # keep the body: it says why (a plan limit, a bad field)
        detail = e.read()[:300].decode(errors="replace")
        raise audiolib.AudioToolError("request to %s failed: HTTP %s %s" % (url, e.code, detail)) from e
    except OSError as e:
        raise audiolib.AudioToolError("request to %s failed: %s" % (url, e)) from e


def _elevenlabs(spec, biome, kind, raw_dir, fetch):
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        raise audiolib.AudioToolError("%s/%s: set ELEVENLABS_API_KEY in the environment" % (biome, kind))
    seconds = float(spec["seconds"])
    low, high = ELEVENLABS_SECONDS[kind]
    if not low <= seconds <= high:
        raise audiolib.AudioToolError("%s/%s: %s s is outside the API's %s to %s s" % (biome, kind, seconds, low, high))
    if kind == "music":
        payload = {"prompt": spec["prompt"], "music_length_ms": int(seconds * 1000), "force_instrumental": True}
    else:
        payload = {"text": spec["prompt"], "duration_seconds": seconds, "loop": True}
    data = fetch(ELEVENLABS[kind], {"xi-api-key": key, "Content-Type": "application/json"}, json.dumps(payload))
    os.makedirs(raw_dir, exist_ok=True)
    raw_path = os.path.join(raw_dir, "%s_%s.mp3" % (biome, kind))
    with open(raw_path, "wb") as f:
        f.write(data)
    samples = audiolib.decode_pcm(raw_path)
    got = len(samples[0]) / audiolib.RATE
    if got < 0.9 * seconds:
        raise audiolib.AudioToolError("%s/%s: got %.1f s of audio, shorter than the %s s requested (the response was cut off; raw file kept at %s)"
                                      % (biome, kind, got, seconds, raw_path))
    return samples


def raw_samples(spec, biome, kind, raw_dir=RAW_DIR, fetch=_fetch):
    provider = spec.get("provider")
    if provider == "elevenlabs":
        return _elevenlabs(spec, biome, kind, raw_dir, fetch)
    if provider == "score":
        with open(spec["file"]) as f:
            return score.render(json.load(f))
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


def process(raw, kind, seamless=False):
    if seamless:
        left, right = audiolib.to_stereo(raw)  # already a bar-exact loop: trimming or blending would move it off the beat
    else:
        left, right = dsp.trim_silence(audiolib.to_stereo(raw))
        left = dsp.make_loop(left, XFADE)
        right = dsp.make_loop(right, XFADE)
    # A raw pad can peak far above full scale, and the WAV used for measuring would clip it, so
    # bring it to a working level first: measure the signal that will really be encoded.
    top = audiolib.lin_to_db(max(audiolib.peak(left), audiolib.peak(right)))
    left, right = audiolib.gain(left, WORK_PEAK_DB - top), audiolib.gain(right, WORK_PEAK_DB - top)
    target = audiolib.TARGET_LUFS[kind]
    measured = _measure((left, right))
    cap = HEADROOM_DB - WORK_PEAK_DB  # the most it may be raised before its peak passes the ceiling
    if target - measured > cap + audiolib.LUFS_TOLERANCE:
        raise audiolib.AudioToolError(
            "too peaky to reach %.1f LUFS under the %.1f dBFS peak cap (it would land at %.1f LUFS): "
            "use a steadier source, without sudden loud sounds" % (target, HEADROOM_DB, measured + cap))
    wanted = min(target - measured, cap)  # loud enough, but never past the ceiling
    return (dsp.fade_ends(audiolib.gain(left, wanted), EDGE_FADE),
            dsp.fade_ends(audiolib.gain(right, wanted), EDGE_FADE))


def build(biome, kind, spec, out_root=OUT):
    seamless = spec.get("provider") == "score"
    audiolib.write_ogg(process(raw_samples(spec, biome, kind), kind, seamless), os.path.join(out_root, kind, biome + ".ogg"))


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
                    kind_spec = dict(spec[kind])
                    kind_spec.setdefault("prompt", spec.get("prompt", ""))
                    build(biome, kind, kind_spec)
                    print("built", kind, biome)
    except audiolib.AudioToolError as e:
        print("error:", e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
