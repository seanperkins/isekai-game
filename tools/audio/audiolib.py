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
TARGET_LUFS = {"music": -23.0, "ambience": -27.0}  # 3 dB under the first pass: Sean found the beds a little loud
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
