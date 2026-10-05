#!/usr/bin/env python3
"""Wrap the visual guides in docs/research into standalone pages for GitHub Pages, plus a small index.

The guides are written as fragments (a <title>, <link>s and a <style>, then the body) so they also publish as claude.ai artifacts. A
browser needs a full document, so this adds the doctype, the viewport, a link back to the index, and writes one file per guide.
tools/publish_pages.sh runs it. The guides stay in docs/research; nothing is copied back.

Usage: tools/wrap_guide.py OUT_DIR
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (source, output name, what it is)
GUIDES = [
    ("docs/research/area-level-design-report.html", "area-design.html",
     "Level-design principles checked against the 23 rooms, then the forest, volcano, cathedral, cemetery, crypt, swamp, goblin village, "
     "demon area and traps, the proposed wiring of every area, the Super Metroid size target and the decisions still open."),
    ("docs/research/species-evolution-report.html", "species-evolution.html",
     "Evolution and skill-tree design for the slime, spider, goblin, undead and wolf: where the slime tree stands, shapes of a good fork, "
     "one element read five ways, four new trees, recipes and decisions."),
]

NAV = (
    '<nav style="max-width:1060px;margin:0 auto;padding:14px 0 0;font:12px/1.4 \'DM Mono\',ui-monospace,monospace;color:var(--muted)">'
    '<a href="./" style="color:var(--accent)">All guides</a> &middot; '
    '<a href="../" style="color:var(--accent)">Design review</a></nav>'
)

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>html { color-scheme: light dark; } body { margin: 0; }</style>
%(head)s
</head>
<body>
%(nav)s
%(body)s
</body>
</html>
"""

INDEX = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Isekai Chronicles guides</title>
<style>
:root { --bg: #edf0f1; --surface: #ffffff; --ink: #14202a; --muted: #52626c; --line: #c8d1d6; --accent: #0b7a75; color-scheme: light dark; }
@media (prefers-color-scheme: dark) { :root { --bg: #0f1315; --surface: #171c1f; --ink: #e7eef1; --muted: #9aa9b2; --line: #2b353a; --accent: #3cc4bb; } }
body { margin: 0; padding: 40px 16px 56px; background: var(--bg); color: var(--ink); font: 15px/1.55 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width: 760px; margin: 0 auto; display: grid; gap: 14px; }
h1 { margin: 0; font-size: clamp(1.7rem, 4vw, 2.4rem); line-height: 1.1; }
p { margin: 0; color: var(--muted); }
a.card { display: grid; gap: 4px; padding: 16px; border: 1px solid var(--line); border-radius: 10px; background: var(--surface); color: inherit; text-decoration: none; }
a.card:hover, a.card:focus-visible { border-color: var(--accent); }
a.card b { font-size: 1.1rem; color: var(--accent); }
a.card span { color: var(--muted); font-size: 0.92rem; }
footer a { color: var(--accent); }
</style>
</head>
<body>
<main>
<h1>Isekai Chronicles guides</h1>
<p>Research summaries for the next areas and the species trees. They are working documents: what we have put together, not a plan.</p>
%(cards)s
<footer><a href="../">Design review</a></footer>
</main>
</body>
</html>
"""


def title_of(fragment: str) -> str:
    m = re.search(r"<title>(.*?)</title>", fragment, re.S)
    return m.group(1).strip() if m else "Guide"


def wrap(fragment: str) -> str:
    m = re.search(r"</style>", fragment)
    if not m:
        raise SystemExit("a guide has no </style>: expected a fragment that starts with its <title>, <link>s and <style>")
    return PAGE % {"head": fragment[: m.end()].strip(), "nav": NAV, "body": fragment[m.end():].strip()}


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    cards = []
    for src, name, blurb in GUIDES:
        path = ROOT / src
        if not path.is_file():
            raise SystemExit(f"missing {src}")
        fragment = path.read_text(encoding="utf-8")
        (out / name).write_text(wrap(fragment), encoding="utf-8")
        cards.append(f'<a class="card" href="{name}"><b>{title_of(fragment)}</b><span>{blurb}</span></a>')
    (out / "index.html").write_text(INDEX % {"cards": "\n".join(cards)}, encoding="utf-8")
    print(f"wrote {len(GUIDES)} guides and an index to {out}")


if __name__ == "__main__":
    main()
