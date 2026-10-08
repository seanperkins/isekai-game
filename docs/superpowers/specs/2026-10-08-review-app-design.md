# Creature review app: design

A local web page that live-reloads when the agent updates it, so art review stops being "I send you a GIF". The agent decides what each creature's page shows; the page shows it: moving sprites at game scale, the real 3D model with its clips, before and after, size lineups, notes and numbers. The reviewer marks things up on the page and the agent reads the marks.

## What I understood

You review the 3D to 2D pipeline's output by looking at it: wolf ears, goblin walks, an ironboot that kneels, a hobgoblin that is smaller than a goblin. Today that means the agent renders frames, builds a GIF and sends it, one file at a time. Success means:

- One URL on this Mac. It stays open. When the agent finishes a render, a note or a model, the page updates in place, without a manual refresh and without losing where you were (creature, zoom, 3D camera angle).
- A creature page shows what the agent chose to show for that creature, and that includes the real 3D model: orbit it, play its clips.
- Sprites are shown the way the game shows them: the real frames, at the size the game draws them, with a zoom control and nearest-neighbour scaling.
- You can leave a note or a flag on a creature or one of its clips ("upper body wrong on walk"), and the agent reads it without being told.
- The agent never has to attach a file to a message to show something.

Assumed, not said: it runs on this Mac only (no sharing, no accounts); it covers the five species trees (goblin, wolf, spider, undead, slime) and the base creatures; the agent, not the page, decides what each creature shows.

## Decisions

| Question | Decision |
|---|---|
| Where it runs | A local server on `127.0.0.1`, started by `tools/review/run.sh`, which prints the URL and opens it. No hosted copy, no snapshots in v1. |
| Stack | Python standard library on the server, plain JavaScript modules in the page, three.js pinned from a CDN for the 3D view. No `node_modules`, no build step, no new Python dependency. |
| Content | Files, not a database: JSON and media in a content folder (`.tmp/review/` by default, git-ignored). The agent writes them; the server only serves them. |
| Reload | The server watches the content folder and the page's own code and pushes events (server-sent events). Content changes update the page in place; code changes reload it. |
| 3D | Blender bakes each form's clips into a glTF; the page plays it with three.js. The motion is the same motion code the sprites are rendered from, so what you see in 3D is what the sprites show. |
| Feedback | The page posts notes and flags to the server, which appends them to a file the agent reads. |
| Where the code lives | `tools/review/` on branch `feat/review-app`, cut from `main` so it does not depend on any uncommitted art work. |

Rejected: a Node dev server with a bundler (hot-module reload we do not need, a toolchain the project does not have); static files with a polling script (cannot save feedback); publishing to a claude.ai page (no live reload, the agent would republish for every change).

## Architecture

```
tools/review/
  run.sh              start the server and open the page
  server.py           static files + content + events + feedback API (stdlib)
  feedback.py         print the notes not read yet, mark them read
  publish.py          write a creature's page.json and its media from the game's sheets or a render folder
  export_gltf.py      (runs in Blender) bake a form's clips and export a glTF
  app/
    index.html        shell and import map
    app.js            router, data loading, reload handling
    blocks/           one module per block type: sprites, model, compare, lineup, note, figure, numbers
    viewer.js         the three.js viewer
    styles.css
  test_server.py  test_publish.py  test_export_gltf.py   (see Testing; the page itself is checked in a real browser)
.tmp/review/          the content folder (--content to change)
  creatures/<id>/page.json   what to show for one creature, and its media
  feedback.jsonl             notes and flags from the page
  feedback.state             how far the agent has read
```

### Server

- `GET /` and `/app/*` serve the page; `GET /content/*` serves the content folder. Paths are resolved and refused if they leave their root. It listens on `127.0.0.1` only.
- `GET /api/creatures` scans `creatures/*/page.json` and returns `{id, title, species, stage, parent, updated, flag}` for the index.
- `GET /events` is a server-sent event stream. A watcher thread stats the content folder and `app/` about four times a second and, after a short settle time so half-written files are not announced, sends `{"type":"content","path":"creatures/goblin_hob/sprites.json"}` or `{"type":"app"}`. The page reconnects by itself; on reconnect it re-fetches everything.
- `POST /api/feedback` takes `{creature, clip?, flag, note}` with `flag` one of `ok`, `wrong`, `change`; it is size-capped, validated and appended to `feedback.jsonl` with an id and a timestamp. `GET /api/feedback` lists it. Nothing else is writable.
- `run.sh` picks the first free port from 8765 and records it, so the agent can print the real URL.

### Page

- Hash routes: `#/` (index) and `#/creature/<id>`. The index lists each species as its tree (parent to child), each creature a card with its thumbnail and the latest flag. State that must survive a reload is kept in the URL (creature) and `localStorage` (zoom, speed, panel layout), each in a try/catch.
- A creature page renders `page.json`'s `blocks` in order. Unknown block types render a visible "unknown block" notice, never a blank.
- A content event for the open creature re-fetches that page and re-renders only blocks whose data changed. Sprite players keep their clock and zoom. The 3D viewer keeps its camera and reloads its glTF only when that file's modification time changed (the URL carries it).
- Reviewer controls on every creature: flag buttons and a note box (per creature, and per clip on `sprites` and `model`); a play/pause, a speed control and a zoom control shared by the blocks on the page.

### Content: `page.json` and blocks

```json
{"id": "goblin_hob", "title": "Hob", "species": "goblin", "stage": 2, "parent": "goblin", "updated": "2026-10-08T17:30:00Z",
 "blocks": [ {"type": "note", "markdown": "The hob is now larger than the goblin: 48x56 against 31x47."},
             {"type": "sprites", "sprites": "sprites.json", "clips": ["idle", "walk"]},
             {"type": "model", "gltf": "model.glb"},
             {"type": "lineup", "items": ["goblin", "goblin_hob", "goblin_paladin"]} ]}
```

| Block | Shows | Data |
|---|---|---|
| `note` | The agent's words (Markdown subset: paragraphs, lists, bold, code, links). | `markdown` |
| `sprites` | The creature's clips animated at game scale. | `sprites`: a file listing, per clip, its frames (a rectangle in a sheet image, or a frame image), per-frame durations, loop flag, the game's draw scale (the twin's `sprite_size`) and optional normal-map image |
| `model` | The 3D model with a clip menu, orbit and zoom, a "game camera" button that snaps to the side view. | `gltf`, optional `camera` |
| `compare` | Two sprite sets side by side, frame-synced, with a swap and a blink toggle. | `a`, `b`: each `{label, sprites}`; `clip` |
| `lineup` | Creatures to scale in a row, with reference height lines (the player goblin, the Stone Drake, the Taratect). | `items` (creature ids or `{sprites, scale, label}`), `lines` |
| `figure` | An image or an animated GIF or SVG with a caption (a reference such as a mocap stick figure). | `src`, `caption` |
| `numbers` | A table (measurements against a reference). | `columns`, `rows`, optional `caption` |

`publish.py` builds the sprite listings so the agent does not hand-write them:
`publish.py sheet <id>` from `assets/sheets/anim_<id>.{json,png}` and the form's clips in `data/form_clips.json` (what the game plays);
`publish.py frames <id> <folder>` from a render folder (`frames/<clip>_<n>.png` and `raw/meta.json`, as `species_tree.py` and `spike.process` leave them), which is how work that is not in the game yet is shown.
Both copy or link the images into the creature's folder, set the draw scale from the twin resource, and update the creature's `page.json` without touching its other blocks.

### 3D: the glTF path

`export_gltf.py <species> <form> --out <folder>` runs in Blender. It builds the form's rig (the same `build` and `setup` the sprite render uses), poses it frame by frame with the clip functions, bakes each clip into an action at the engine's 20 ms grid (the same per-frame durations as the sprites), assigns each part a material with the colour it is rendered with, and exports a glTF with every clip as a named animation. The page's viewer loads it, plays a clip by name, and keeps the game's conventions on screen: creatures face right in the game camera; the glTF's up axis is converted by the exporter.

Risk and how it is handled: the rig's materials are emission-only (it is made to be rendered flat), so the exporter swaps in plain colour materials for the export; skinning and the baked clips are verified on the base goblin first. The build order puts this last and starts it with that spike. If it does not hold, the fallback is turntable renders shown by the same `model` block as an image strip, and the spec is amended before more is built on it.

### Feedback loop

`feedback.py` prints entries it has not shown yet (creature, clip, flag, note, time) and records that it has. The agent runs it at the start of each turn of review work. The index shows each creature's latest flag. Nothing in the page edits art or code.

## Error handling

- The server never crashes the page: a malformed `page.json` is served as is and the page shows the file name and the parse error in place of the creature, so a half-written file is visible, not silent.
- A missing image or glTF shows the block with the path that failed.
- A POST that fails (server stopped) keeps the note in the box and says so; it retries when the event stream reconnects.
- three.js comes from a pinned CDN URL. Offline, the `model` block says so and the rest of the page still works.

## Testing

- `test_server.py` (unittest, real server on a free port): a touched file produces one content event after the settle time; a change in `app/` produces an app event; a path outside the roots is refused (`..`, absolute, encoded); a feedback POST is validated, size-capped and appended; unread feedback is printed once.
- `test_publish.py`: the sprite listing from a real sheet and a real clip table equals the game's frames and timings for a chosen creature; a render folder produces the same shape; republishing keeps the creature's other blocks.
- A page smoke check in a real browser (Chrome tools): the index lists the trees, a creature page animates a clip (the frame index advances), a content change appears without a reload and without resetting zoom, a flag posts and is read by `feedback.py`.
- The glTF export has a gated test (skipped without Blender): the file loads, has the form's clip names and the expected frame count and duration for each.

## Build order

1. **Shell:** server, events, page shell, index, `sprites` and `note` blocks, flags and notes, `publish.py sheet` and `frames`. First content: the goblin walk review (the mocap measures as `numbers`, the lineup of the heavy goblins, the sprites).
2. **More blocks:** `compare`, `lineup`, `figure`; the wolf and spider as the second and third content.
3. **3D:** the glTF spike on the base goblin, then `export_gltf.py`, `viewer.js` and the `model` block, then every form.

Each step ends with the page open and the agent's own content on it.

## Out of scope

Sharing or hosting the page, accounts, editing art or code from the page, a database, annotating on top of an image, and bundling three.js into the repository.
