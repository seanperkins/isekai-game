# Creature review page

A local page that live-reloads when content changes. The agent publishes what it wants shown for a creature (moving sprites at game scale, its 3D model, comparisons, size lineups, notes and numbers); the reviewer opens one URL, looks, and leaves flags and notes the agent reads.
Design: `docs/superpowers/specs/2026-10-08-review-app-design.md`.

## Run it

```
tools/review/run.sh                      # first free port from 8765, opens the browser; content in .tmp/review/
tools/review/run.sh --content DIR --no-open
```

The URL is printed and written to `<content>/server.json`. The server listens on 127.0.0.1 only.

## Content folder

```
<content>/creatures/<id>/page.json    what to show for one creature
<content>/creatures/<id>/*            its media (sheet images, frames, sprites.json, model.glb)
<content>/feedback.jsonl              notes and flags from the page
<content>/feedback.state              how far the agent has read
```

`page.json`: `{"id", "title", "species", "stage", "parent", "updated", "blocks": [ ... ]}`. Blocks render in order:

| `type` | Shows | Data |
|---|---|---|
| `note` | the agent's words (Markdown subset) | `markdown` |
| `numbers` | a table | `columns`, `rows`, `caption?` |
| `sprites` | the creature's clips at game scale | `sprites` (a listing file), `clips?` |
| `compare` | two sprite sets in lockstep | `clip`, `a`, `b` (`{label, sprites}`) |
| `lineup` | creatures to scale beside reference heights | `items`, `lines` |
| `figure` | an image, GIF or SVG | `src`, `caption` |
| `model` | the 3D model with its clips | `gltf` |

Write pages with `publish.py` (`sheet`, `frames`, `model`, `tree`) rather than by hand; it keeps the other blocks when it republishes.

## The agent's routine

1. Publish what you want shown; the open page updates in place.
2. At the start of each turn of review work run `python3 tools/review/feedback.py [--content DIR]`; it prints the notes and flags not yet shown (`--peek` leaves them unread).
3. Tell the reviewer the URL, not a file.

## Tests

`tools/review/BROWSER_CHECKS.md` lists the checks of the page's behaviour in time (with `?debug`, the clock can be stepped by hand).

`python3 -m unittest discover -s tools/review -p "test_*.py"`. The page itself is checked in a real browser (see the plan's smoke steps).
