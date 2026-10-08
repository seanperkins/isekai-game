# Creature Review App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A local live-reload web page on which the agent shows each creature's sprites, 3D model, comparisons, lineups and notes, and on which the reviewer leaves flags and notes the agent reads.

**Architecture:** A stdlib Python server serves a plain-JS page and a content folder, watches both and pushes server-sent events; content is JSON plus media written by `publish.py` and Blender; the page renders a creature's `blocks` and updates in place on an event. 3D is a glTF baked in Blender and played by three.js.

**Tech Stack:** Python 3 standard library, `unittest`; ES modules in the browser (no build); three.js 0.170.0 from jsDelivr; Blender 5.2 (`/Applications/Blender.app`) for the glTF export.

**Spec:** `docs/superpowers/specs/2026-10-08-review-app-design.md`

## Global Constraints

- The server listens on `127.0.0.1` only; its port is the first free one from 8765.
- Python standard library only on the server and tools; no new Python dependency.
- The page is plain JavaScript modules: no build step, no `node_modules`; three.js is imported from a pinned CDN URL (`three@0.170.0`).
- Content defaults to `.tmp/review/` of the checkout (git-ignored); `--content DIR` overrides it everywhere.
- Feedback `flag` is one of `ok`, `wrong`, `change`; creature and clip ids match `^[a-z0-9_]+$`.
- Sprites are drawn with nearest-neighbour scaling at the game's draw scale (`sprite_size`) times the page zoom.
- Code lives in `tools/review/` on branch `feat/review-app`; work in `.worktrees/review-app`.
- No time, effort or schedule estimates in code, docs or commits.

## Review Focus

1. A `page.json` that is half written or invalid while the agent writes it: the page names the file and the parse error where the creature should be (Task 1 `scan_creatures` test, Task 5 smoke).
2. An id or media path with `..`, a slash, capitals or spaces: refused by the server and by `write_creature` (Task 1, Task 4 tests).
3. A burst of writes (images, then `sprites.json`, then `page.json`): one event per path after the settle time, never a flash of broken images (Task 2 test, Task 6 smoke).
4. The server restarting or the Mac sleeping with a tab open: the page reconnects and re-fetches (Task 5 smoke).
5. A clip with one frame, a zero or missing duration, or no clips at all: a still or a "no clips" notice, never a spinning or frozen loop (Task 6 smoke with a crafted listing).

## File Structure

| File | Responsibility |
|---|---|
| `tools/review/feedback.py` | the feedback file: validate, append, list, read-state, CLI |
| `tools/review/watcher.py` | stat-poll roots, settle, emit one event per changed path |
| `tools/review/server.py`, `run.sh` | HTTP routes, SSE, safe paths, creature scan, start and open |
| `tools/review/publish.py` | sprite listings from sheets or render folders; `page.json` writing |
| `tools/review/app/*` | `index.html`, `app.js` (router, loader, events), `player.js` (frame at time), `blocks/*.js`, `viewer.js`, `styles.css` |
| `tools/review/export_gltf.py` | (Blender) bake clips and export a glTF |
| `tools/review/test_*.py` | unittest; the page itself is checked in a real browser |

---

### Task 1: Feedback store and CLI

**Files:** Create `tools/review/feedback.py`, `tools/review/test_feedback.py`

**Interfaces:**
- Produces: `FLAGS = ("ok", "wrong", "change")`; `append(content: Path, entry: dict) -> dict` (entry `{creature, clip?, flag, note}`; returns it with `id: int` (1, 2, ...) and `ts` ISO-8601 UTC; raises `ValueError` on a bad id, flag or a note over 2000 characters); `entries(content: Path) -> list[dict]`; `unread(content: Path, mark: bool = True) -> list[dict]`; `latest_flags(content: Path) -> dict[str, str]`. Files: `<content>/feedback.jsonl`, `<content>/feedback.state` (`{"read_through": id}`).

- [ ] **Step 1: Write the failing tests** (`test_feedback.py`, a temp dir per test): `test_append_returns_an_id_and_timestamp_and_lists_it`; `test_a_flag_outside_the_three_is_refused`; `test_an_id_with_a_slash_capital_or_dots_is_refused` (`"../x"`, `"Hob"`, `"a b"`); `test_a_note_over_2000_characters_is_refused`; `test_unread_returns_each_entry_once_and_peek_does_not_mark` (`unread(mark=False)` twice returns the same, `unread()` then `unread()` returns `[]`); `test_latest_flags_is_the_newest_flag_per_creature`; `test_a_corrupt_line_in_the_file_is_skipped_not_fatal`.
- [ ] **Step 2: Run:** `python3 -m unittest tools/review/test_feedback.py -v`. Expected: ImportError.
- [ ] **Step 3: Implement `feedback.py`.** Append with `open(..., "a")` and one `json.dumps` line per entry; ids are the count of valid lines plus one. CLI: `python3 tools/review/feedback.py [--content DIR] [--peek]` prints `#id creature[/clip] FLAG time: note` per unread entry and `no new feedback` when none.
- [ ] **Step 4: Run the tests.** Expected: 7 passed.
- [ ] **Step 5: Commit:** `git add tools/review/feedback.py tools/review/test_feedback.py && git commit -m "feat: the review app's feedback store and reader"`

### Task 2: Watcher

**Files:** Create `tools/review/watcher.py`, `tools/review/test_watcher.py`

**Interfaces:**
- Produces: `class Watcher(roots: dict[str, Path], settle: float = 0.15, interval: float = 0.25)` with `start()`, `stop()`, `subscribe() -> queue.Queue`; each event is `{"type": "content" | "app", "path": str}` where `type` is the root's key (`"content"`, `"app"`) and `path` is relative to that root with `/` separators.

- [ ] **Step 1: Write the failing tests** (real threads, `settle=0.05, interval=0.02`): `test_a_new_file_produces_one_content_event`; `test_a_burst_of_writes_to_one_file_is_one_event_after_the_settle` (20 writes in 0.1 s, then `get(timeout=1)` returns one event, the queue is then empty after 0.3 s); `test_three_files_written_together_give_three_events_one_each`; `test_a_change_under_the_app_root_is_type_app`; `test_a_deleted_file_is_reported`; `test_a_file_still_being_written_is_not_announced_before_it_settles` (event time minus last write time is at least the settle); `test_stop_ends_the_thread`.
- [ ] **Step 2: Run:** `python3 -m unittest tools/review/test_watcher.py -v`. Expected: ImportError.
- [ ] **Step 3: Implement `Watcher`.** A daemon thread walks each root with `os.scandir`, keeps `{path: (mtime_ns, size)}`, records the time of the last change per path, and emits a path once `now - last_change >= settle`. Ignore `.DS_Store` and names ending `~` or `.tmp`.
- [ ] **Step 4: Run the tests.** Expected: 7 passed.
- [ ] **Step 5: Commit:** `git add tools/review/watcher.py tools/review/test_watcher.py && git commit -m "feat: the review app's file watcher"`

### Task 3: Server and launcher

**Files:** Create `tools/review/server.py`, `tools/review/run.sh`, `tools/review/test_server.py`, `tools/review/README.md`

**Interfaces:**
- Consumes: `feedback.append`, `feedback.entries`, `feedback.latest_flags`; `Watcher`.
- Produces: `resolve_under(root: Path, rel: str) -> Path | None` (None for `..`, absolute, percent-encoded traversal, symlinks out of the root); `scan_creatures(content: Path) -> list[dict]` (each `{id, title, species, stage, parent, updated, flag, error?}`, a page that fails to parse gives `{id, error: "<file>: <message>"}`); `make_server(content: Path, app: Path, port: int = 0, settle: float = 0.15) -> ReviewServer` with `.port`, `.serve_background()`, `.close()`; routes `GET /` (the app's `index.html`), `/app/*`, `/content/*`, `/api/creatures`, `/api/feedback`, `POST /api/feedback`, `/events` (SSE lines `data: {json}\n\n`, a `: keepalive` comment every 15 s). `run.sh [--content DIR] [--no-open]` picks the first free port from 8765, writes `<content>/server.json` (`{port, url, pid}`), prints the URL and runs `open` on it.

- [ ] **Step 1: Write the failing tests** (a real server on port 0, `urllib`): `test_resolve_under_refuses_parent_absolute_encoded_and_symlink_escapes`; `test_serves_app_and_content_with_the_right_types` (`.json`, `.png`, `.glb` is `model/gltf-binary`); `test_a_missing_file_is_404_and_a_traversal_is_404_not_a_leak`; `test_scan_creatures_lists_pages_and_reports_a_broken_one_by_name` (write `{"id":` and expect `error` naming `creatures/<id>/page.json`); `test_post_feedback_validates_appends_and_returns_the_entry` (bad flag 400, over 4096 bytes body 413, wrong content type 415); `test_get_feedback_lists_entries`; `test_a_touched_content_file_arrives_on_the_event_stream` (open `/events`, write a file, read one `data:` line equal to `{"type":"content","path":"creatures/x/page.json"}`); `test_the_server_binds_only_to_localhost`.
- [ ] **Step 2: Run:** `python3 -m unittest tools/review/test_server.py -v`. Expected: ImportError.
- [ ] **Step 3: Implement `server.py` and `run.sh`.** `ThreadingHTTPServer` subclass; one `Watcher` with roots `{"content": content, "app": app}`; each SSE client gets its own `subscribe()` queue; send `Cache-Control: no-store` on everything. `README.md` documents: start (`tools/review/run.sh`), the content layout, the block types, and the agent's routine (publish, then `feedback.py` at the start of each turn).
- [ ] **Step 4: Run the tests.** Expected: 8 passed.
- [ ] **Step 5: Commit:** `git add tools/review && git commit -m "feat: the review app's server and launcher"`

### Task 4: Publish helpers

**Files:** Create `tools/review/publish.py`, `tools/review/test_publish.py`

**Interfaces:**
- Consumes: `tools/art/blender/export_forms.split_id(form_id) -> (species, form)`; `<species>_forms.FORMS[form]` (`stage`, `parent`); `data/form_clips.json[form_id][state] = {frames: [name per 20 ms tick], fps, loop}`; `assets/sheets/anim_<form_id>.json` (`frames[name].rect = [x, y, w, h]`) and `.png`, `_n.png`; `data/creatures/twin_<form_id>.tres` `sprite_size`.
- Produces: `sheet_listing(form_id: str, root: Path = ROOT) -> dict` and `frames_listing(folder: Path) -> dict`, both `{"image": str | None, "normal": str | None, "scale": float, "clips": {name: {"frames": [{"rect": [x, y, w, h]} | {"src": str}], "durations": [float seconds], "loop": bool}}}`; `write_creature(content: Path, creature: str, listing: dict, media: dict[str, Path], **meta) -> Path` (copies each `media` file under `creatures/<creature>/`, writes `sprites.json`, creates or updates `page.json` keeping other blocks, adds one `{"type": "sprites", "sprites": "sprites.json"}` block if absent; `meta` is `title, species, stage, parent`); `set_block(content: Path, creature: str, block: dict, key: str | None = None) -> None` (replaces the block whose `key` equals, else appends); CLI `publish.py sheet <form_id> | frames <creature> <folder>` with `--content`.

- [ ] **Step 1: Write the failing tests:** `test_sheet_listing_for_goblin_hob_matches_the_games_clips` (clips are `idle walk run attack hurt die` and the engine's windup/recover/downed states are skipped; `walk` runs of identical consecutive tick names merge so `sum(durations)` equals `len(ticks) / fps` within 1e-6; every rect is inside the sheet image size; `scale == 1.12` from the twin); `test_sheet_listing_scale_is_one_for_a_form_with_no_twin`; `test_frames_listing_from_a_render_folder` (build a temp folder with `frames/walk_0.png`, `frames/walk_1.png`, `raw/meta.json` holding `anims`, `durations`, `loops`; expect `src` entries in order and the meta's durations); `test_write_creature_copies_media_and_keeps_other_blocks` (a `note` block added earlier survives a republish); `test_write_creature_refuses_a_bad_id_or_media_name`; `test_set_block_replaces_by_key_and_appends_otherwise`; `test_write_is_atomic_page_json_is_never_half_written` (write to a temp name, `os.replace`).
- [ ] **Step 2: Run:** `python3 -m unittest tools/review/test_publish.py -v`. Expected: ImportError.
- [ ] **Step 3: Implement `publish.py`.** Merge runs of equal consecutive tick names into one frame with `count / fps` seconds; read `sprite_size` with the regex `^sprite_size = ([0-9.]+)` (as `sizing.sprite_size_of` does); for stage and parent import `<species>_forms` from `tools/art/blender` via `sys.path`.
- [ ] **Step 4: Run the tests.** Expected: 7 passed.
- [ ] **Step 5: Commit:** `git add tools/review/publish.py tools/review/test_publish.py && git commit -m "feat: publish a creature's sprites to the review app"`

### Task 5: Page shell and index

**Files:** Create `tools/review/app/index.html`, `app.js`, `styles.css`; Modify `.gitignore` only if `.tmp/` is not already ignored there.

**Interfaces:**
- Produces (`app.js`): `registerBlock(type: string, render: (el: HTMLElement, data: object, ctx: Ctx) => void | (() => void))`, where `Ctx = {base: string, creature: string, zoom: () => number, speed: () => number, playing: () => boolean, onEvent: (fn) => void}` and the returned function cleans up; hash routes `#/` and `#/creature/<id>`; events handling: a `content` event for the open creature re-fetches `page.json` and re-renders only blocks whose JSON changed (compare serialised block plus the `mtime` token of files it names); an `app` event does `location.reload()`; `EventSource` reconnect re-fetches the index and the open page.
- `index.html` has the import map (`three`, `three/addons/`) and loads `app.js` as a module.

- [ ] **Step 1: Seed a test content folder:** `python3 tools/review/publish.py sheet goblin_hob --content .tmp/review-test` and the same for `goblin`; write `.tmp/review-test/creatures/broken/page.json` containing `{"id":`.
- [ ] **Step 2: Implement the shell.** The index groups creatures by `species`, ordered by tree (parent before child, children by stage), each card showing the title, stage, the latest flag as a coloured dot and the `error` text for a broken page. A creature page shows the title, a back link, then its blocks in order; an unknown block type renders a boxed "unknown block: <type>"; an `error` page renders the file name and message. Zoom, speed and play/pause controls sit in a sticky bar and persist in `localStorage` inside try/catch.
- [ ] **Step 3: Start the server:** `tools/review/run.sh --content .tmp/review-test --no-open`; open the printed URL with the Chrome tools. Expected: the index lists goblin and hob in one tree and `broken` with its error text; no console errors.
- [ ] **Step 4: Check reload behaviour in the browser:** edit `goblin_hob/page.json`'s title on disk; expected: the card text changes within 1 s with no full reload (a `window.__loaded` marker set at load is still present). Stop and restart the server; expected: the open tab reconnects and re-fetches within 5 s.
- [ ] **Step 5: Commit:** `git add tools/review/app && git commit -m "feat: the review page shell, index and live updates"`

### Task 6: Sprites, note and numbers blocks, feedback controls, first content

**Files:** Create `tools/review/app/player.js`, `app/blocks/sprites.js`, `blocks/note.js`, `blocks/numbers.js`, `blocks/feedback.js`; Modify `app/app.js` (register the blocks, mount the feedback panel on every creature page)

**Interfaces:**
- Produces: `player.js` exports `frameAt(durations: number[], loop: boolean, t: number) -> number` (index; durations under 0.02 count as 0.02; empty list returns -1; a one-frame list returns 0; non-looping clamps to the last frame); `blocks/sprites.js` draws each requested clip on a `<canvas>` with `imageSmoothingEnabled = false`, bottom-centre aligned, scale `listing.scale * ctx.zoom()`; clip name labels with a per-clip flag; a normal-map toggle when `normal` exists; `blocks/note.js` renders a Markdown subset (paragraphs, `-` lists, `**bold**`, `` `code` ``, `[text](url)`) by building DOM nodes, never `innerHTML`; `blocks/numbers.js` renders `{columns, rows, caption}`; `blocks/feedback.js` posts `{creature, clip?, flag, note}` to `/api/feedback`, keeps the text on failure, retries on reconnect.

- [ ] **Step 1: Implement `player.js` and the blocks** per the interfaces; a `frameAt` clip with `durations: [0]` or `[]` must return a valid frame or -1 and the block must show a still or "no clips".
- [ ] **Step 2: Craft the Review Focus fixtures:** in `.tmp/review-test` add a creature `edge` whose listing has a one-frame clip, a clip with `durations: [0]`, a clip with no `durations`, and an empty `clips: {}`; expected: the page shows a still for each of the first three and "no clips" for the last, with no console error and a stable CPU.
- [ ] **Step 3: Check in the browser (Chrome tools):** open `#/creature/goblin_hob`; expected: walk and idle animate (read the canvas's current frame index twice 300 ms apart through the JS tool and see them differ); zoom 2 doubles the canvas size; edit `page.json` to add a `note` block; expected: the note appears with zoom and clip position unchanged. Copy a new image into the creature folder then rewrite `sprites.json`; expected: no broken-image flash.
- [ ] **Step 4: Check the feedback loop:** click `wrong` on the walk clip, type "upper body", save; run `python3 tools/review/feedback.py --content .tmp/review-test`; expected: `#1 goblin_hob/walk WRONG ... upper body`, and the index dot turns red; a second run prints `no new feedback`.
- [ ] **Step 5: First real content, then commit.** In the codex-wolf checkout run `python3 tools/review/publish.py frames goblin_hob .tmp/goblin-lineup-FTJS0w/hob --content <review-app>/.tmp/review` (and `goblin`), add `note` and `numbers` blocks (mocap against goblin measures from `.tmp/walkcheck-FoKsPG/`) with `set_block`; `git add tools/review/app && git commit -m "feat: the review page's sprite, note, numbers and feedback blocks"`

### Task 7: Compare, figure and lineup blocks

**Files:** Create `tools/review/app/blocks/compare.js`, `figure.js`, `lineup.js`; Modify `app/app.js` (register)

**Interfaces:**
- Produces: `compare`: `{type: "compare", clip: string, a: {label, sprites}, b: {label, sprites}}` draws both clips from one shared clock, with a swap button and a blink toggle (alternate a/b in one canvas every 400 ms); `figure`: `{src, caption}` an `<img>` (GIF, PNG, SVG) with the caption, a "missing: <path>" notice on error; `lineup`: `{items: [string | {sprites, scale?, label}], lines: [{label, height}]}` draws each item's first idle frame at on-screen size (`listing.scale` times zoom) on one baseline with dashed reference lines at `height` px (the player goblin 47, Stone Drake 50, Taratect 62); an item given as a creature id loads `/content/creatures/<id>/sprites.json`.

- [ ] **Step 1: Implement the three blocks.**
- [ ] **Step 2: Check in the browser:** a `compare` of the study's walk against the retuned walk animates in lockstep (same frame index) and blink alternates; a `figure` of `.tmp/walkcheck-FoKsPG/stick-compare.gif` shows; a `lineup` of `goblin`, `goblin_hob`, `goblin_paladin` shows the hob 48 by 56 against the goblin's 31 by 47 with the 47 px line at the goblin's head. A `lineup` naming a creature with no content shows "no sprites: <id>" in its slot.
- [ ] **Step 3: Publish the second and third content:** `publish.py sheet` for the wolf and spider base forms; add their notes.
- [ ] **Step 4: Commit:** `git add tools/review/app && git commit -m "feat: the review page's compare, figure and lineup blocks"`

### Task 8: glTF export

**Files:** Create `tools/review/export_gltf.py`, `tools/review/test_export_gltf.py`

**Interfaces:**
- Consumes: `creatures/<species>.build(variant)`, `.setup(rig, variant)` (returns `anims = {name: (count, fn(i, n) -> (rot, root), grounded)}` and `extra["durations"][name]`); `rigkit.Rig.pose/stand`.
- Produces: `python3 tools/review/export_gltf.py <species> <form> --out DIR` (run through Blender: the script re-executes itself under `/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P` when `bpy` is missing) writing `DIR/model.glb`; one animation per clip named `idle walk run attack hurt die` (plus a player's other clips when present), keyframes on a 50 fps grid with each frame held for its duration; every part has a plain Principled material in its rendered colour (the render materials are emission-only); glTF up axis left to the exporter. `DIR/model.json`: `{clips: {name: seconds}, form}`.

- [ ] **Step 1: Spike on the base goblin before writing the test.** Export `goblin` and open `model.glb` in the page's viewer stub or any glTF viewer; accept only if the skin follows the clips and the colours match the sprite; if it does not hold, write the failure and the fallback (turntable stills through the `figure` block) into the spec and stop for review.
- [ ] **Step 2: Write the gated test** (skipped without Blender): `test_the_base_goblin_exports_a_glb_with_every_clip` (parse the glb JSON chunk: `animations` names include the six clips; each animation's input accessor `max` is within 0.02 s of `sum(durations)` for its clip; every material has `pbrMetallicRoughness.baseColorFactor`; the file has at least one skin).
- [ ] **Step 3: Run:** `python3 -m unittest tools/review/test_export_gltf.py -v`. Expected: FAIL before the implementation, PASS after.
- [ ] **Step 4: Implement `export_gltf.py`** from the spike: bake each clip by posing every frame, inserting keyframes on pose bones, naming one action per clip and exporting with `export_animations=True, export_nla_strips=False, export_force_sampling=True`.
- [ ] **Step 5: Commit:** `git add tools/review/export_gltf.py tools/review/test_export_gltf.py && git commit -m "feat: export a form's rig and clips as a glTF"`

### Task 9: Viewer and model block

**Files:** Create `tools/review/app/viewer.js`, `app/blocks/model.js`; Modify `tools/review/publish.py` (`model` command), `app/app.js` (register)

**Interfaces:**
- Produces: `viewer.js` exports `createViewer(container: HTMLElement, url: string, opts?) -> {play(clip: string), clips(): string[], gameCamera(), dispose()}` using `GLTFLoader` and `OrbitControls` from `three/addons/`, an orthographic "game camera" looking along +Y with X to the right; `blocks/model.js`: `{type: "model", gltf: "model.glb"}` with a clip menu, orbit, zoom, a "game camera" button and a play/pause tied to the page controls, reloading only when the file's `mtime` token changes and keeping the camera across reloads; `publish.py model <form_id> --content DIR` runs `export_gltf.py` into `creatures/<id>/` and sets the `model` block.

- [ ] **Step 1: Implement viewer, block and the `model` command;** offline, the block shows "3D unavailable: three.js did not load" and the rest of the page works.
- [ ] **Step 2: Check in the browser:** `python3 tools/review/publish.py model goblin --content .tmp/review-test`; open the page; expected: the goblin loads, `walk` plays, the camera orbits and the game camera button shows the side view; re-export and expect the model to update while the camera stays where it was; block the CDN host and expect the notice.
- [ ] **Step 3: Commit:** `git add tools/review && git commit -m "feat: the review page's 3D viewer"`

### Task 10: Every form of a species

**Files:** Modify `tools/review/publish.py` (`tree <species>` command), `tools/review/README.md`

**Interfaces:**
- Produces: `publish.py tree <species> [--models] --content DIR` runs `sheet` for each form of the species that has a sheet and, with `--models`, `model` for each; forms without a sheet are listed and skipped.

- [ ] **Step 1: Write the failing test:** `test_tree_publishes_every_goblin_form_with_a_sheet_and_lists_the_rest` (uses the real `assets/sheets`; asserts 28 creature folders for goblin and the skipped list is empty).
- [ ] **Step 2: Run it,** expect failure; **implement** the command; **run** and expect pass.
- [ ] **Step 3: Run the goblin tree with models;** open the page; expected: 29 goblin cards, each with sprites and a model.
- [ ] **Step 4: Run all review tests:** `python3 -m unittest discover -s tools/review -p "test_*.py"`; expected: all pass (the glTF test skips without Blender).
- [ ] **Step 5: Commit:** `git add tools/review && git commit -m "feat: publish a whole species tree to the review page"`
