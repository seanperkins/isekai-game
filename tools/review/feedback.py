"""The review app's feedback file: notes and flags the reviewer leaves on the page, and the agent's reader for them.

    python3 tools/review/feedback.py [--content DIR] [--peek]

prints what has not been shown yet (and marks it shown, unless --peek).
Files in the content folder: feedback.jsonl (one JSON object per line) and feedback.state ({"read_through": id}).
"""
import argparse
import json
import os
import re
import sys
import threading
from datetime import datetime, timezone
from pathlib import Path

FLAGS = ("ok", "wrong", "change")
MAX_NOTE = 2000
ID_PATTERN = re.compile(r"^[a-z0-9_]+$")
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CONTENT = ROOT / ".tmp" / "review"
_lock = threading.Lock()


def _check_id(value, what):
    if not isinstance(value, str) or not ID_PATTERN.match(value):
        raise ValueError("%s must match %s: %r" % (what, ID_PATTERN.pattern, value))


def _well_formed(entry):
    """What append() writes: an object with an integer id, a creature, a known flag and a text note (and a clip id when it has a clip)."""
    return (isinstance(entry, dict) and isinstance(entry.get("id"), int) and isinstance(entry.get("creature"), str) and bool(ID_PATTERN.match(entry["creature"]))
            and entry.get("flag") in FLAGS and isinstance(entry.get("note", ""), str)
            and (entry.get("clip") is None or (isinstance(entry["clip"], str) and bool(ID_PATTERN.match(entry["clip"])))))


def entries(content):
    """Every well-formed entry in the file, oldest first; a line that is not one (not JSON, an id but no creature or flag...) is skipped, not fatal."""
    path = Path(content) / "feedback.jsonl"
    out = []
    try:
        with open(path) as fh:
            for line in fh:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                if _well_formed(entry):
                    out.append(entry)
    except FileNotFoundError:
        pass
    return out


def append(content, entry):
    """Validate and store one entry {creature, clip?, flag, note}; returns it with its id (1, 2, ...) and a UTC timestamp."""
    _check_id(entry.get("creature"), "creature")
    if entry.get("clip") is not None:
        _check_id(entry["clip"], "clip")
    if entry.get("flag") not in FLAGS:
        raise ValueError("flag must be one of %s: %r" % (", ".join(FLAGS), entry.get("flag")))
    note = entry.get("note", "")
    if not isinstance(note, str) or len(note) > MAX_NOTE:
        raise ValueError("note must be text of at most %d characters" % MAX_NOTE)
    content = Path(content)
    content.mkdir(parents=True, exist_ok=True)
    with _lock:
        stored = {"id": len(entries(content)) + 1, "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "creature": entry["creature"]}
        if entry.get("clip") is not None:
            stored["clip"] = entry["clip"]
        stored.update(flag=entry["flag"], note=note)
        with open(content / "feedback.jsonl", "a") as fh:
            fh.write(json.dumps(stored) + "\n")
    return stored


def unread(content, mark=True):
    """The entries after the state file's read_through, oldest first; with `mark` the state moves past them."""
    content = Path(content)
    state = content / "feedback.state"
    try:
        read_through = json.loads(state.read_text()).get("read_through", 0)
    except (OSError, ValueError):
        read_through = 0
    fresh = [e for e in entries(content) if e["id"] > read_through]
    if mark and fresh:
        tmp = content / "feedback.state.tmp"
        tmp.write_text(json.dumps({"read_through": fresh[-1]["id"]}))
        os.replace(tmp, state)
    return fresh


def latest_flags(content):
    """{creature: the flag of its newest entry}."""
    return {e["creature"]: e["flag"] for e in entries(content)}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--content", type=Path, default=DEFAULT_CONTENT)
    ap.add_argument("--peek", action="store_true", help="do not mark the entries as read")
    args = ap.parse_args(argv)
    fresh = unread(args.content, mark=not args.peek)
    if not fresh:
        print("no new feedback")
    for e in fresh:
        where = e["creature"] + ("/" + e["clip"] if e.get("clip") else "")
        print("#%d %s %s %s: %s" % (e["id"], where, e["flag"].upper(), e["ts"], e["note"]))


if __name__ == "__main__":
    sys.exit(main())
