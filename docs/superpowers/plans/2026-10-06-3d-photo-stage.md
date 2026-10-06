# The 3D photo stage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One Blender stage that every creature renders through, so the 2D sprites are made the same way every time, and a movement review on that stage where a rig moves over game-like terrain at the game's real speeds before anything is baked to 2D.

**Architecture:** `stage.py` holds the camera, scale and course numbers (pure Python, tested without Blender). The terrain course is data exported from the game's own `MovementSandbox`, so the 3D stage and the 2D game cannot drift. A GDScript recorder drives the real species body through a scripted course and writes its trajectory; a Blender review script poses the rig per recorded tick on the course and renders a preview. The bake path (`rigkit.setup_camera`, `render_set`) reads the same stage numbers.

**Tech Stack:** Python 3 (pure modules, unittest), Blender 4 (`-b -P`, bpy), Godot 4.7 headless (GUT), Pillow.

**Spec:** the user's direction of 2026-10-06 (saved in the project memory, bank blender-spike-3r71thp19526g): a 3D photo stage for consistent 2D models, with terrain like the game's to climb and jump off, motions reviewed there, then converted to 2D.

## Global Constraints

- One source for every number: pixels-per-unit from `sizing.py`, speeds from `sizing.speed_of` and `data/form_clips.json` `_walk_speeds`, course geometry from `MovementSandbox`'s constants. The stage invents none.
- The camera is side-on orthographic, looking along +Y, X right, Z up, a creature faces +X (`rigkit.py`'s convention).
- Scratch output goes under `.tmp/stage/`; nothing generated is committed except the course JSON.
- No time or effort estimates anywhere.

## Review Focus

- A course exported from the game that no longer matches `MovementSandbox` (a changed ledge) must fail a test, not silently differ.
- A recorded run that never lands, or whose body falls out of the course, must be reported, not rendered.
- A creature with no pose for a recorded state (wall cling, mantle) must say so, not render the idle pose.
- Bake output must not change: the stage refactor leaves every existing sprite byte-identical.

---

### Task 1: The stage numbers

**Files:**
- Create: `tools/art/blender/stage.py`, `tools/art/blender/test_stage.py`
- Modify: `tools/art/blender/rigkit.py` (`setup_camera` reads `stage`), `tools/art/blender/render_set.py`

**Interfaces:**
- Produces: `stage.CAMERA` (dict: ortho axis, `y_distance`), `stage.camera_params(canvas, ppu, margin, supersample, center_x) -> dict` (the numbers `setup_camera` now applies), `stage.px_to_units(px, ppu) -> float`, `stage.GRID_PX = 16`.

- [ ] **Step 1: Write the failing test** `test_stage.py`: `camera_params(128, 40, 12, 2, 0.0)` equals what `rigkit.setup_camera` computed before (`ortho_scale == canvas / ppu`), `px_to_units(16, 40) == 0.4`.
- [ ] **Step 2: Run** `python3 -m unittest tools/art/blender/test_stage.py` — Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `stage.py` with those functions and make `rigkit.setup_camera` call `camera_params`.
- [ ] **Step 4: Run** the whole blender suite `python3 -m unittest discover -s tools/art/blender -p "test_*.py"` — Expected: all pass, as before.
- [ ] **Step 5: Render a goblin idle before and after** and compare the PNG bytes (`tools/art/blender/spike.py goblin --anims idle --out .tmp/stage/before`, then after); Expected: identical.
- [ ] **Step 6: Commit** `feat: the stage's camera numbers in one module that the bake reads`.

### Task 2: The course, from the game

**Files:**
- Create: `tools/export_stage_course.gd`, `tools/art/stage_course.json`, `tests/test_stage_course.gd`

**Interfaces:**
- Produces: `stage_course.json` = `{"floor": [x, y, w, h], "walls": [...], "ledges": [...], "tunnel": [...], "shaft_wall": [...], "crawl_pillar": [...], "crawl_slab": [...], "step_low": [...], "oneway_ledge": [...], "start": [x, y]}` in game pixels, y up negative as the sandbox has it.

- [ ] **Step 1: Write the failing GUT test** `test_stage_course.gd`: reads `res://tools/art/stage_course.json` and asserts every rect equals the matching `MovementSandbox` constant (`LEDGES`, `FLOOR`, `WALLS`, `TUNNEL`, ...), and `start` equals `MovementSandbox.START`.
- [ ] **Step 2: Run** `tools/run_tests.sh stage_course` — Expected: FAIL (file missing).
- [ ] **Step 3: Implement** `export_stage_course.gd` (a `-s` script that loads the sandbox script's constants and writes the JSON) and run it once to create the file.
- [ ] **Step 4: Run** the test — Expected: PASS. Changing a ledge in `movement_sandbox.gd` makes it fail.
- [ ] **Step 5: Commit** `feat: the movement course as data, exported from the sandbox`.

### Task 3: Record a run

**Files:**
- Create: `tools/record_movement.gd`, `tests/test_record_movement.gd`

**Interfaces:**
- Consumes: `MovementSandbox.scripted` (`MoveInput`), `MovementProfile.for_species(id)`.
- Produces: `.tmp/stage/<species>_<script>.json` = `{"species", "script", "fps": 60, "ticks": [{"t", "x", "y", "vx", "vy", "facing", "verb", "on_floor", "surface"}]}`; a script is a list of `{"seconds", "dir", "jump", "hold_jump", "down", "signature"}` steps (walk, run, jump the ledges, wall jumps, the pounce).

- [ ] **Step 1: Write the failing test**: record the goblin's `jump_ledges` script; assert `ticks[0]` is at `START`, `t` rises by 1/60, some tick has `y` more than 40 px above the floor, the last tick is `on_floor`, and no tick leaves the course's bounds.
- [ ] **Step 2: Run** `tools/run_tests.sh record_movement` — Expected: FAIL.
- [ ] **Step 3: Implement** `record_movement.gd` (steps the sandbox's physics with the scripted input, one record per physics frame) with the built-in scripts `walk_run`, `jump_ledges`, `wall_shaft` (goblin/slime), `crawl` (spider), `pounce` (wolf).
- [ ] **Step 4: Run** the test — Expected: PASS.
- [ ] **Step 5: Commit** `feat: record a species' movement over the course`.

### Task 4: The review render

**Files:**
- Create: `tools/art/blender/stage_review.py` (Blender side), `tools/art/stage_review.py` (CLI), `tools/art/blender/test_stage_review.py`

**Interfaces:**
- Consumes: the Task 2 course, a Task 3 recording, a creature module's pose functions (`biped_motion`, `quad_motion`, `spider_motion`, `slime_motion`, `player_poses`).
- Produces: `.tmp/stage/<species>_<script>/frame_####.png` and `review.gif`; `pose_for(clips, state, phase)` (pure Python; `clips` is what a creature module's `clips_of` builds, since a pose needs the rig's measured feet) returning the pose the Blender side applies, or raising `NoPose(state)`.

- [ ] **Step 1: Write the failing test** (pure Python, no Blender): `pose_for("goblin", "walk", 0.25, 60.0)` returns the biped walk pose at that phase; `pose_for("goblin", "wall", ...)` returns the wall pose; an unknown state raises `NoPose`; walk phase advances by speed divided by the stride length so feet do not slide (`phase_rate(speed, stride) == speed / stride`).
- [ ] **Step 2: Run** `python3 -m unittest tools/art/blender/test_stage_review.py` — Expected: FAIL.
- [ ] **Step 3: Implement** `pose_for` and `phase_rate` over the existing motion modules; then the Blender script that builds the course boxes (one mesh per rect, `stage.px_to_units`), the ground, a tracking camera on `stage.camera_params`, and per tick poses the rig at `(x, y)` with `pose_for`, rendering a low-resolution preview.
- [ ] **Step 4: Run** `python3 tools/art/stage_review.py goblin --script jump_ledges` — Expected: writes `review.gif` under `.tmp/stage/goblin_jump_ledges/`; open it and check the feet land on the ledges.
- [ ] **Step 5: Commit** `feat: review a species' movement on the 3D stage`.

### Task 5: Reviewing every species and the feel checks

**Files:**
- Modify: `tools/art/stage_review.py` (all species), `tools/art/blender/test_stage_review.py`

- [ ] **Step 1: Write the failing test**: for every species and script the recorder can make, `NoPose` is raised only for states listed in an explicit `KNOWN_MISSING` table (so a missing pose is a visible, named gap).
- [ ] **Step 2: Run** the test — Expected: FAIL until the table is filled from what the species actually lacks.
- [ ] **Step 3: Add the foot-slide check**: from the `walk_run` recording, the rig is posed at each moment the gait goes on to its next pose and where each foot bone's vertices rest on the ground is compared with the pose before (`foot_slide_px`); it stays under 1.5 px for each species with feet (the jelly hops), the same measure with every pose frozen goes over it, and the test fails and names the species when it does not.
- [ ] **Step 4: Run** the whole suite and `python3 tools/art/stage_review.py all` — Expected: a GIF per species and script, and a printed list of the named gaps.
- [ ] **Step 5: Commit** `feat: the stage reviews every species and names what it cannot pose`.

### Task 6: Verb motion archetypes (a separate plan once this lands)

The motions a verb plays are derived from its spec (`kind` and keys): about fifteen archetypes per rig family, authored on this stage and reviewed here before baking, with each verb row in `tools/form_verbs.json` tagged `anim`. Written as its own plan after Task 5, from what the stage shows.
