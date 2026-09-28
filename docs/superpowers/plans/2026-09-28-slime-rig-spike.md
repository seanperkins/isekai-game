# Slime Rig Spike (Plan 1 of the forms plans) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a rigged slime (separately drawn parts on a skeleton, a deforming body, bone-driven
hurt and attack shapes, and every animation from the spec) and hand you real screenshots to
decide whether rigging replaces per-frame art. **This plan ends at that decision. It does not
rig any enemy.**

**Architecture:**
- **Art:** three parts (body, eye, pod) are generated individually with Codex and fitted to
  pixel-crisp sizes by a small tool.
- **Rig:** a `SlimeRig` node draws a skinned `Polygon2D` body on a `Skeleton2D` with eyes and
  pods riding the bones. It renders into a small `SubViewport` with no smoothing, and a
  `Sprite2D` shows that texture in the world.
- **Animation:** animations are JSON keyframe tables sampled by a pure `RigAnim`. A pure
  `SlimeState.pick` chooses the state.
- **Hit shapes:** `RigShapes` builds hurt and attack shapes from the skinned mesh, in the main
  world (a SubViewport has its own physics world, so shapes cannot live inside it).
- **Player:** the `Player` uses the rig behind one switch, and gains Spread and the eating
  cover.

**Tech Stack:** Godot 4.7 (GDScript), GUT 9.7.1, `tools/run_tests.sh`, Python 3 + Pillow (via
`uv`), Codex image generation.

**Spec:** `docs/superpowers/specs/2026-09-28-slime-forms-and-animation-design.md`, sections 0.1–0.4
and 1.1–1.3. The spec's Sub-project 1 continues in a later plan after your decision.

## Global Constraints

- Godot 4.7 and GDScript. Add explicit types wherever inference fails (the project treats
  Variant inference as an error).
- Tests run with `tools/run_tests.sh [file-substring]`. After adding any new `class_name` or
  asset, run `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1`
  first.
- The internal resolution is 640×360. Pixels must stay crisp: no smoothing anywhere on the rig.
- **Every image is generated individually** (a part, never a whole sheet), then assembled by a tool.
- **The rig scale is one constant**, `RigConfig.SCALE`, default **2** (the slime is twice
  today's 22×18 px, because "we can make things bigger if we want"). Part sizes, the collision
  box, the spread box and the viewport all derive from it. Animation tables are written in
  scale-1 pixels and multiplied by `SCALE` when applied.
- **Hit shapes are inert in this spike** (collision layers 0): the spike proves shapes follow the
  skin. It does not switch the game's damage checks over (that is a later plan).
- A SubViewport has its own physics world (`world_2d` differs from the main one), so no
  `Area2D` may live inside the rig's viewport.
- Only the slime is rigged. Enemies, forms, and the rebirth work are out of scope.
- Work in `.worktrees/rig-spike` on branch `feat/rig-spike`. Git commands need the sandbox
  disabled, because the worktree's gitdir is outside the sandbox. `uv` and `codex` must be the
  **entire** Bash command (no `cd`, no pipes) and run with the sandbox disabled.
- Windowed Godot runs (contact sheet, captures) need the sandbox disabled too; a headless
  renderer draws nothing.

## Review Focus

1. **A bigger slime in today's rooms.** A 28×24 body must fit every room exit (Task 8 test
   `test_every_room_exit_fits_the_rigged_slime`).
2. **Standing up under a low ceiling.** A spread slime must stay spread, and not jump, when
   something solid is close overhead (Task 8 test `test_no_jump_or_stand_under_a_low_ceiling`).
3. **Clinging to a wall.** The grip must be drawn on the wall side, from the wall's normal and
   not from `facing` (Task 8 test `test_the_wall_grip_faces_the_wall`).
4. **Shapes must follow the skin, and stay inert and outside the viewport.** (Task 7 tests
   `test_shapes_live_in_the_player_tree_and_are_inert` and
   `test_spread_flattens_the_hurt_shape`).
5. **Missing art must not crash the game.** With no rig assets, the Player falls back to the
   old sprite (Task 8 test `test_the_player_falls_back_to_the_sprite_without_rig_assets`).

## File Structure

| File | Responsibility |
|---|---|
| `scripts/rig/rig_config.gd` (new) | One place for scale, part sizes, bone rest fractions, viewport geometry |
| `tools/art/rig/parts.json` (new) | Part names and their target sizes (input to the assembler) |
| `tools/art/assemble_parts.py` (new) | Key, fit, and crisp the generated parts into `assets/rigs/slime/` |
| `art_source/rig/*.png` (generated) | Raw Codex output, one part per image |
| `assets/rigs/slime/{body,eye,pod}.png`, `parts.json` (generated) | Game-ready parts |
| `scripts/rig/slime_state.gd` (new) | Pure: which animation to play |
| `scripts/rig/rig_anim.gd` (new) | Pure: sample a keyframe table into bone poses |
| `data/rigs/slime_anims.json` (new) | The eleven animations as data |
| `scripts/rig/rig_geometry.gd` (new) | Pure: outline, interior points, weights, deformation |
| `scripts/rig/slime_rig.gd` (new) | The rig: viewport, skeleton, skinned body, eyes, pods, playback |
| `scripts/rig/rig_shapes.gd` (new) | Hurt and attack shapes that follow the rig |
| `scripts/rig/eat_cover.gd` (new) | Covers the prey while eating |
| `scripts/player/predation_hold.gd` (modify) | `progress()` |
| `scripts/player/player.gd` (modify) | Rig display, Spread, tackle timer, eat cover |
| `tools/rig/*.gd`, `tools/rig/make_gif.py` (new) | Contact sheet, clips, in-game shots, cost probe |
| `tests/test_rig_*.gd`, `tests/test_slime_state.gd`, `tests/test_player_spread.gd`, `tests/test_eat_cover.gd` (new) | Tests |

---

### Task 0: Worktree and baseline

**Files:** none.

- [ ] **Step 1: Create the worktree from the design branch**

```bash
cd /Users/sean/sites/isekai-game && git worktree add .worktrees/rig-spike -b feat/rig-spike docs/forms-spec
```
Expected: `Preparing worktree ... HEAD is now at <sha>`. (The spec and this plan travel with it.)

- [ ] **Step 2: Import and get the baseline**

```bash
cd /Users/sean/sites/isekai-game/.worktrees/rig-spike && mkdir -p .tmp/gdhome .tmp/test-logs && gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1; tools/run_tests.sh | tail -1
```
Expected: `PASS: 389 tests`. All later "full suite" checks add to this number.

---

### Task 1: Rig config and the slime's parts (art)

**Files:**
- Create: `scripts/rig/rig_config.gd`, `tools/art/rig/parts.json`, `tools/art/assemble_parts.py`
- Create (generated): `art_source/rig/{body,eye,pod}.png`, `assets/rigs/slime/{body,eye,pod}.png` (+ `.import`), `assets/rigs/slime/parts.json`
- Test: `tests/test_rig_assets.gd`

**Interfaces:**
- Produces:
  - `RigConfig.SCALE := 2`
  - `RigConfig.BODY`, `EYE`, `POD` (`Vector2i`, scale-1 sizes), `COLLISION`, `SPREAD_COLLISION` (`Vector2`)
  - `RigConfig.VIEW`, `ORIGIN` (`Vector2i`), `BONE_FRACTIONS` (`Dictionary`), `EYES` (`Array` of `Vector2`)
  - `RigConfig.part_size(part: String) -> Vector2i` (scaled)
  - `RigConfig.body_size() -> Vector2`
  - `RigConfig.bone_rest(bone: String) -> Vector2` (rig space: origin at the body's bottom centre, y up is negative)
  - `RigConfig.fraction_to_rig(f: Vector2) -> Vector2` (the same fractions as `BONE_FRACTIONS`, for any point on the body)
  - `RigConfig.view_size() -> Vector2i`, `origin() -> Vector2`, `display_offset() -> Vector2`
  - `assets/rigs/slime/parts.json`: `{"set": "slime", "parts": {"body": {"size": [w, h]}, ...}}`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_rig_assets.gd
extends GutTest
## The slime's generated parts: present, at the rig scale, crisp, keyed clear of magenta.

const DIR := "res://assets/rigs/slime/"

func _parts() -> Dictionary:
	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(DIR + "parts.json")), OK)
	return json.data["parts"]

func _image(part: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(DIR + part + ".png"))

func test_config_sizes_scale_with_the_rig_scale() -> void:
	assert_eq(RigConfig.part_size("body"), RigConfig.BODY * RigConfig.SCALE)
	assert_eq(RigConfig.part_size("eye"), RigConfig.EYE * RigConfig.SCALE)
	assert_eq(RigConfig.part_size("pod"), RigConfig.POD * RigConfig.SCALE)
	assert_eq(RigConfig.body_size(), Vector2(RigConfig.BODY * RigConfig.SCALE))

func test_bone_rests_sit_on_the_body() -> void:
	var size := RigConfig.body_size()
	assert_eq(RigConfig.bone_rest("core"), Vector2(0.0, -size.y * 0.5))
	assert_lt(RigConfig.bone_rest("top").y, RigConfig.bone_rest("core").y)
	assert_gt(RigConfig.bone_rest("belly").y, RigConfig.bone_rest("core").y)
	assert_gt(RigConfig.bone_rest("front").x, 0.0)
	assert_lt(RigConfig.bone_rest("back").x, 0.0)

func test_the_display_is_centred_over_the_rig_origin() -> void:
	# the rig origin sits 18 px (scale 1) below the viewport's centre, so the sprite is lifted by that
	assert_eq(RigConfig.display_offset(), Vector2(0.0, -18.0 * RigConfig.SCALE))

func test_parts_json_matches_the_config() -> void:
	var parts := _parts()
	for part in ["body", "eye", "pod"]:
		assert_true(parts.has(part), part)
		assert_eq(Vector2i(int(parts[part]["size"][0]), int(parts[part]["size"][1])), RigConfig.part_size(part), part)

func test_every_part_image_matches_its_size_and_is_clean() -> void:
	for part in ["body", "eye", "pod"]:
		var img := _image(part)
		assert_not_null(img, part)
		assert_eq(img.get_size(), Vector2i(RigConfig.part_size(part)), part)
		assert_eq(img.get_pixel(0, 0).a, 0.0, part + " corner is transparent")
		var opaque := 0
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				assert_true(c.a == 0.0 or c.a == 1.0, "%s (%d,%d) alpha is crisp" % [part, x, y])
				if c.a == 1.0:
					opaque += 1
					assert_false(c.r > 0.6 and c.b > 0.6 and c.g < 0.47, "%s (%d,%d) magenta fringe" % [part, x, y])
		assert_gt(opaque, img.get_width() * img.get_height() / 5, part + " has substance")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_rig_assets`
Expected: FAIL with `Identifier "RigConfig" not declared` (a SCRIPT ERROR line).

- [ ] **Step 3: Write the config and the assembler**

```gdscript
# scripts/rig/rig_config.gd
class_name RigConfig
extends RefCounted
## Sizes for the rigged slime. Everything scales with SCALE: 1 keeps today's 22x18 px slime, 2
## (the spike's default) makes it twice as big in the world. Animation tables are written in
## SCALE 1 pixels and multiplied by SCALE when applied.

const SCALE := 2
## Part image sizes and the collision boxes at SCALE 1.
const BODY := Vector2i(24, 20)
const EYE := Vector2i(4, 5)
const POD := Vector2i(7, 6)
const COLLISION := Vector2(14, 12)
const SPREAD_COLLISION := Vector2(14, 5)
## The rig is drawn into a viewport this big (at SCALE 1). Its origin, the body's bottom centre,
## sits at ORIGIN inside it. The margins leave room for a spread puddle and a stretched body.
const VIEW := Vector2i(64, 44)
const ORIGIN := Vector2i(32, 40)
## Bone rest positions as fractions of the body: x from the centre (fraction of the width), y up
## from the bottom (fraction of the height).
const BONE_FRACTIONS := {
	"core": Vector2(0.0, 0.5), "top": Vector2(0.0, 0.95), "belly": Vector2(0.0, 0.05),
	"front": Vector2(0.42, 0.5), "back": Vector2(-0.42, 0.5)}
## Eye positions, in the same fractions. The slime faces right, so both eyes sit forward.
const EYES := [Vector2(0.10, 0.62), Vector2(0.30, 0.62)]

static func part_size(part: String) -> Vector2i:
	match part:
		"body":
			return BODY * SCALE
		"eye":
			return EYE * SCALE
		"pod":
			return POD * SCALE
	return Vector2i.ZERO

static func body_size() -> Vector2:
	return Vector2(BODY * SCALE)

## Rig space: origin at the body's bottom centre, negative y is up.
static func bone_rest(bone: String) -> Vector2:
	var f: Vector2 = BONE_FRACTIONS[bone]
	var size := body_size()
	return Vector2(f.x * size.x, -f.y * size.y)

static func fraction_to_rig(f: Vector2) -> Vector2:
	var size := body_size()
	return Vector2(f.x * size.x, -f.y * size.y)

static func view_size() -> Vector2i:
	return VIEW * SCALE

static func origin() -> Vector2:
	return Vector2(ORIGIN * SCALE)

## Where the displayed viewport sprite sits, relative to the rig's origin, so the origin lands
## on the body's bottom centre: the viewport's centre is (ORIGIN.y - VIEW.y / 2) above it.
static func display_offset() -> Vector2:
	return Vector2(0.0, -(ORIGIN.y - VIEW.y / 2.0) * SCALE)
```

`tools/art/rig/parts.json` (plain JSON; the sizes are at the default `RigConfig.SCALE` of 2):
```json
{
  "slime": {"body": [48, 40], "eye": [8, 10], "pod": [14, 12]}
}
```

```python
# tools/art/assemble_parts.py
"""Fit individually generated rig parts into game-ready, pixel-crisp part images.

Each part is one Codex image on a magenta key, saved as art_source/rig/<part>.png. This crops to
the drawn pixels, box-downscales to the exact size in tools/art/rig/parts.json, and thresholds the
alpha so edges stay crisp (the same look as tools/art/slice_sheets.py). It writes
assets/rigs/<set>/<part>.png and assets/rigs/<set>/parts.json.

Run from the project root (the whole command, no cd or pipes):
  uv run --python 3.12 --with Pillow python tools/art/assemble_parts.py slime
"""
import json
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_sheets import crisp_alpha, keyed  # noqa: E402

SRC = "art_source/rig"
OUT = "assets/rigs"
NAME = re.compile(r"^[a-z0-9_]+$")


def fit(im, size):
    """Key out magenta, crop to the drawn pixels, box-resize to exactly `size`, crisp the alpha."""
    im = keyed(im.convert("RGBA"))
    box = im.split()[3].getbbox()
    if box is None:
        raise SystemExit("part is empty after keying")
    im = im.crop(box).resize(tuple(size), Image.BOX)
    return crisp_alpha(im)


def main():
    if len(sys.argv) != 2 or not NAME.match(sys.argv[1]):
        raise SystemExit("usage: assemble_parts.py <set>")
    rig_set = sys.argv[1]
    sizes = json.load(open("tools/art/rig/parts.json"))[rig_set]
    out_dir = os.path.join(OUT, rig_set)
    os.makedirs(out_dir, exist_ok=True)
    parts = {}
    for part, size in sizes.items():
        if not NAME.match(part):
            raise SystemExit("bad part name: %r" % part)
        src = os.path.join(SRC, part + ".png")
        if not os.path.exists(src):
            raise SystemExit("missing %s (generate it first)" % src)
        fit(Image.open(src), size).save(os.path.join(out_dir, part + ".png"))
        parts[part] = {"size": list(size)}
        print("wrote", os.path.join(out_dir, part + ".png"), tuple(size))
    with open(os.path.join(out_dir, "parts.json"), "w") as f:
        json.dump({"set": rig_set, "parts": parts}, f, indent=2)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Generate the three parts, one at a time**

Each is its own Bash call with the sandbox disabled, and is the entire command. Create the folder first:
`mkdir -p /Users/sean/sites/isekai-game/.worktrees/rig-spike/art_source/rig`

Body:
```
codex exec --skip-git-repo-check -s workspace-write -C /Users/sean/sites/isekai-game/.worktrees/rig-spike/art_source/rig -o /Users/sean/sites/isekai-game/.worktrees/rig-spike/art_source/rig/.last.txt -i /Users/sean/sites/isekai-game/.worktrees/rig-spike/assets/sprites/slime_idle.png - <<'EOF'
$imagegen Generate one image (square): the BODY of a small slime creature, alone. Modern pixel art with soft lighting: a translucent glowing blue jelly dome, flat-ish underside, slightly wider than tall (about 6:5), soft inner glow, gentle highlights, a clean dark-blue outline, chunky readable pixels. Match the style and colours of the reference image. NO eyes, NO face, NO arms, NO shadow, NO text. Side view. Fill the whole background with flat solid magenta #FF00FF. Save the PNG into the current working directory as body.png. Reply with the absolute path of the saved file only.
EOF
```
Eye (same command shape, its own call):
```
$imagegen Generate one image (square): a single slime EYE, alone. Modern pixel art: a small glossy dark blue-black oval, taller than wide (about 4:5), with one tiny white highlight near the top. Clean, chunky pixels. Match the reference image's style. NO face, NO body, NO shadow, NO text. Fill the whole background with flat solid magenta #FF00FF. Save the PNG into the current working directory as eye.png. Reply with the absolute path of the saved file only.
```
Pod:
```
$imagegen Generate one image (square): a single short jelly PSEUDOPOD, alone: a small stubby rounded translucent blue blob, like a tiny hand or arm tip pointing right, same glowing jelly material as the reference slime. Modern pixel art, chunky readable pixels, soft highlight, clean dark-blue outline. NO body, NO eyes, NO shadow, NO text. Fill the whole background with flat solid magenta #FF00FF. Save the PNG into the current working directory as pod.png. Reply with the absolute path of the saved file only.
```
After each, **Read the resulting `art_source/rig/<part>.png`** and check it: one clear subject, on flat magenta, in the reference's style, and (for the body) no face. If it is wrong, regenerate that part alone with a corrected prompt. Do not proceed until all three look right.

- [ ] **Step 5: Assemble, import, and run the test**

```
uv run --python 3.12 --with Pillow python tools/art/assemble_parts.py slime
```
(whole command, sandbox disabled). Expected: three `wrote assets/rigs/slime/<part>.png (w, h)` lines.
Then:
```bash
gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1; tools/run_tests.sh test_rig_assets | tail -1
```
Expected: `PASS: 5 tests`.
Also **Read the three assembled PNGs** at `assets/rigs/slime/` (they are tiny; note whether the body still reads as a jelly dome at 48×40).

- [ ] **Step 6: Commit**

```bash
git add scripts/rig tools/art/rig tools/art/assemble_parts.py art_source/rig assets/rigs tests/test_rig_assets.gd tests/*.uid
git commit -m "feat: rig config and the slime's individually generated parts"
```

---

### Task 2: SlimeState (which animation plays)

**Files:**
- Create: `scripts/rig/slime_state.gd`
- Test: `tests/test_slime_state.gd`

**Interfaces:**
- Produces: `SlimeState.ALL: Array` (the eleven names, in priority order), `SlimeState.RUN_SPEED := 8.0`,
  `SlimeState.pick(eating, hurt, roped, wall, dashing, spread, on_floor, vy, land_timer, speed) -> String`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slime_state.gd
extends GutTest
## First match wins, in the order of the spec's table (1.1).

func _pick(over: Dictionary = {}) -> String:
	var a := {"eating": false, "hurt": false, "roped": false, "wall": false, "dashing": false,
		"spread": false, "on_floor": true, "vy": 0.0, "land": 0.0, "speed": 0.0}
	a.merge(over, true)
	return SlimeState.pick(a["eating"], a["hurt"], a["roped"], a["wall"], a["dashing"], a["spread"],
		a["on_floor"], a["vy"], a["land"], a["speed"])

func test_each_row_of_the_table() -> void:
	assert_eq(_pick(), "idle")
	assert_eq(_pick({"speed": 60.0}), "run")
	assert_eq(_pick({"speed": -60.0}), "run")
	assert_eq(_pick({"speed": 2.0}), "idle")
	assert_eq(_pick({"land": 0.05}), "land")
	assert_eq(_pick({"on_floor": false, "vy": -100.0}), "rise")
	assert_eq(_pick({"on_floor": false, "vy": 100.0}), "fall")
	assert_eq(_pick({"spread": true}), "spread")
	assert_eq(_pick({"dashing": true}), "tackle")
	assert_eq(_pick({"wall": true, "on_floor": false}), "wall")
	assert_eq(_pick({"roped": true, "on_floor": false}), "rope")
	assert_eq(_pick({"hurt": true}), "hurt")
	assert_eq(_pick({"eating": true}), "cover")

func test_earlier_rows_beat_later_ones() -> void:
	var everything := {"eating": true, "hurt": true, "roped": true, "wall": true, "dashing": true,
		"spread": true, "on_floor": false, "vy": -1.0, "land": 0.1, "speed": 99.0}
	assert_eq(_pick(everything), "cover")
	everything["eating"] = false
	assert_eq(_pick(everything), "hurt")
	everything["hurt"] = false
	assert_eq(_pick(everything), "rope")
	everything["roped"] = false
	assert_eq(_pick(everything), "wall")
	everything["wall"] = false
	assert_eq(_pick(everything), "tackle")
	everything["dashing"] = false
	assert_eq(_pick(everything), "spread")
	everything["spread"] = false
	assert_eq(_pick(everything), "rise")

func test_all_lists_every_state_once() -> void:
	assert_eq(SlimeState.ALL.size(), 11)
	var seen := {}
	for s in SlimeState.ALL:
		assert_false(seen.has(s))
		seen[s] = true
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_slime_state`
Expected: FAIL with `Identifier "SlimeState" not declared`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/rig/slime_state.gd
class_name SlimeState
extends RefCounted
## Which animation the slime plays. The first match wins, in the order of the spec's table.

const ALL := ["cover", "hurt", "rope", "wall", "tackle", "spread", "rise", "fall", "land", "run", "idle"]
## Horizontal speed (px/s) above which the slime counts as running.
const RUN_SPEED := 8.0

static func pick(eating: bool, hurt: bool, roped: bool, wall: bool, dashing: bool, spread: bool,
		on_floor: bool, vy: float, land_timer: float, speed: float) -> String:
	if eating:
		return "cover"
	if hurt:
		return "hurt"
	if roped:
		return "rope"
	if wall:
		return "wall"
	if dashing:
		return "tackle"
	if spread:
		return "spread"
	if not on_floor:
		return "rise" if vy < 0.0 else "fall"
	if land_timer > 0.0:
		return "land"
	if absf(speed) > RUN_SPEED:
		return "run"
	return "idle"
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_slime_state | tail -1`. Expected: `PASS: 3 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/rig/slime_state.gd scripts/rig/*.uid tests/test_slime_state.gd tests/*.uid
git commit -m "feat: SlimeState picks the slime's animation"
```

---

### Task 3: RigAnim and the animation tables

**Files:**
- Create: `scripts/rig/rig_anim.gd`, `data/rigs/slime_anims.json`
- Test: `tests/test_rig_anim.gd`

**Interfaces:**
- Consumes: `SlimeState.ALL` (Task 2).
- Produces:
  - `RigAnim.BONES: Array` = `["core", "top", "belly", "front", "back"]`
  - `RigAnim.load_table(path: String) -> Dictionary` (animation name → table)
  - `RigAnim.sample(anim: Dictionary, t: float) -> Dictionary` (bone → `{"pos": Vector2, "scale": Vector2, "rot": float}`)
  - `RigAnim.blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary`
  - `RigAnim.rest_pose() -> Dictionary`
  - Table format: `{"length": float, "loop": bool, "pods": bool, "bones": {bone: {"pos": [[t, x, y], ...], "scale": [[t, sx, sy], ...], "rot": [[t, r], ...]}}}`; values are scale-1 pixels.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_rig_anim.gd
extends GutTest
## Keyframe sampling and the shipped tables.

const TABLE := "res://data/rigs/slime_anims.json"

func _anim(loop: bool = false) -> Dictionary:
	return {"length": 1.0, "loop": loop, "bones": {
		"top": {"pos": [[0.0, 0.0, 0.0], [1.0, 10.0, -4.0]], "scale": [[0.0, 1.0, 1.0], [1.0, 2.0, 0.5]]}}}

func test_sampling_interpolates_between_keys() -> void:
	var pose := RigAnim.sample(_anim(), 0.5)
	assert_eq(pose["top"]["pos"], Vector2(5.0, -2.0))
	assert_eq(pose["top"]["scale"], Vector2(1.5, 0.75))

func test_missing_tracks_use_the_rest_values() -> void:
	var pose := RigAnim.sample(_anim(), 0.5)
	assert_eq(pose["core"]["pos"], Vector2.ZERO)
	assert_eq(pose["core"]["scale"], Vector2.ONE)
	assert_eq(pose["core"]["rot"], 0.0)

func test_a_loop_wraps_and_a_one_shot_holds_its_last_key() -> void:
	assert_eq(RigAnim.sample(_anim(true), 1.5)["top"]["pos"], Vector2(5.0, -2.0))
	assert_eq(RigAnim.sample(_anim(false), 5.0)["top"]["pos"], Vector2(10.0, -4.0))
	assert_eq(RigAnim.sample(_anim(false), -1.0)["top"]["pos"], Vector2.ZERO)

func test_blend_mixes_two_poses() -> void:
	var a := RigAnim.rest_pose()
	var b := RigAnim.sample(_anim(), 1.0)
	var mid := RigAnim.blend(a, b, 0.5)
	assert_eq(mid["top"]["pos"], Vector2(5.0, -2.0))
	assert_eq(RigAnim.blend(a, b, 0.0)["top"]["pos"], Vector2.ZERO)
	assert_eq(RigAnim.blend(a, b, 1.0)["top"]["pos"], Vector2(10.0, -4.0))

func test_every_state_has_a_valid_table() -> void:
	var table := RigAnim.load_table(TABLE)
	for state in SlimeState.ALL:
		assert_true(table.has(state), state)
		var anim: Dictionary = table[state]
		assert_gt(float(anim["length"]), 0.0, state)
		assert_true(anim.has("loop"), state)
		for bone in anim["bones"]:
			assert_true(RigAnim.BONES.has(bone), "%s: unknown bone %s" % [state, bone])
			for track in anim["bones"][bone]:
				var keys: Array = anim["bones"][bone][track]
				assert_false(keys.is_empty(), "%s.%s" % [state, bone])
				var last := -1.0
				for k in keys:
					assert_gt(float(k[0]), last - 0.0001, "%s.%s keys are in time order" % [state, bone])
					last = float(k[0])
					assert_lte(float(k[0]), float(anim["length"]) + 0.0001, "%s.%s key past the end" % [state, bone])

func test_spread_is_flat_and_wide_and_idle_is_near_rest() -> void:
	var table := RigAnim.load_table(TABLE)
	var spread := RigAnim.sample(table["spread"], float(table["spread"]["length"]))
	assert_lt(spread["core"]["scale"].y, 0.5)
	assert_gt(spread["core"]["scale"].x, 1.3)
	var idle := RigAnim.sample(table["idle"], 0.0)
	assert_lt(idle["top"]["pos"].length(), 0.5)

func test_pods_show_only_where_they_are_used() -> void:
	var table := RigAnim.load_table(TABLE)
	for state in ["wall", "tackle", "cover"]:
		assert_true(bool(table[state]["pods"]), state)
	for state in ["idle", "run", "rise", "fall"]:
		assert_false(bool(table[state].get("pods", false)), state)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_rig_anim`
Expected: FAIL with `Identifier "RigAnim" not declared`.

- [ ] **Step 3: Implement the sampler and the tables**

```gdscript
# scripts/rig/rig_anim.gd
class_name RigAnim
extends RefCounted
## Turns keyframe tables (data/rigs/slime_anims.json) into bone poses. Pure, so it is unit
## tested. Values are in scale-1 pixels; the rig multiplies positions by RigConfig.SCALE.

const BONES := ["core", "top", "belly", "front", "back"]

static func load_table(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("RigAnim: cannot read %s" % path)
		return {}
	return json.data

static func rest_pose() -> Dictionary:
	var pose := {}
	for bone in BONES:
		pose[bone] = {"pos": Vector2.ZERO, "scale": Vector2.ONE, "rot": 0.0}
	return pose

## The pose at time `t`. A loop wraps; a one-shot holds its first and last keys.
static func sample(anim: Dictionary, t: float) -> Dictionary:
	var length := float(anim.get("length", 1.0))
	var time := fposmod(t, length) if bool(anim.get("loop", false)) else clampf(t, 0.0, length)
	var tracks: Dictionary = anim.get("bones", {})
	var pose := {}
	for bone in BONES:
		var track: Dictionary = tracks.get(bone, {})
		pose[bone] = {
			"pos": _vec(track.get("pos", []), time, Vector2.ZERO),
			"scale": _vec(track.get("scale", []), time, Vector2.ONE),
			"rot": _num(track.get("rot", []), time, 0.0)}
	return pose

static func blend(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for bone in BONES:
		var pa: Dictionary = a[bone]
		var pb: Dictionary = b[bone]
		out[bone] = {
			"pos": Vector2(pa["pos"]).lerp(Vector2(pb["pos"]), k),
			"scale": Vector2(pa["scale"]).lerp(Vector2(pb["scale"]), k),
			"rot": lerpf(float(pa["rot"]), float(pb["rot"]), k)}
	return out

static func _vec(keys: Array, t: float, default: Vector2) -> Vector2:
	if keys.is_empty():
		return default
	var first: Array = keys[0]
	if t <= float(first[0]):
		return Vector2(float(first[1]), float(first[2]))
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= float(b[0]):
			var a: Array = keys[i - 1]
			var k := inverse_lerp(float(a[0]), float(b[0]), t)
			return Vector2(float(a[1]), float(a[2])).lerp(Vector2(float(b[1]), float(b[2])), k)
	var last: Array = keys[keys.size() - 1]
	return Vector2(float(last[1]), float(last[2]))

static func _num(keys: Array, t: float, default: float) -> float:
	if keys.is_empty():
		return default
	var first: Array = keys[0]
	if t <= float(first[0]):
		return float(first[1])
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= float(b[0]):
			var a: Array = keys[i - 1]
			return lerpf(float(a[1]), float(b[1]), inverse_lerp(float(a[0]), float(b[0]), t))
	var last: Array = keys[keys.size() - 1]
	return float(last[1])
```

`data/rigs/slime_anims.json` (units are scale-1 px; `pos` is an offset from the bone's rest, negative y is up):

```json
{
  "idle": {"length": 1.6, "loop": true, "pods": false, "bones": {
    "top": {"pos": [[0.0, 0, 0], [0.8, 0, 1.2], [1.6, 0, 0]]},
    "core": {"scale": [[0.0, 1, 1], [0.8, 1.04, 0.96], [1.6, 1, 1]]},
    "front": {"pos": [[0.0, 0, 0], [0.8, 0.6, 0], [1.6, 0, 0]]},
    "back": {"pos": [[0.0, 0, 0], [0.8, -0.6, 0], [1.6, 0, 0]]}}},
  "run": {"length": 0.4, "loop": true, "pods": false, "bones": {
    "top": {"pos": [[0.0, 2, 1], [0.1, 3, -1], [0.2, 2, 1], [0.3, 3, -1], [0.4, 2, 1]]},
    "front": {"pos": [[0.0, 2, 0], [0.1, 4, -1], [0.2, 2, 0], [0.3, 4, -1], [0.4, 2, 0]]},
    "back": {"pos": [[0.0, 1, 0], [0.1, -2, 0], [0.2, 1, 0], [0.3, -2, 0], [0.4, 1, 0]]},
    "core": {"scale": [[0.0, 1.08, 0.92], [0.1, 0.96, 1.06], [0.2, 1.08, 0.92], [0.3, 0.96, 1.06], [0.4, 1.08, 0.92]]}}},
  "rise": {"length": 0.15, "loop": false, "pods": false, "bones": {
    "top": {"pos": [[0.0, 0, 0], [0.15, 0, -4]]},
    "core": {"scale": [[0.0, 1, 1], [0.15, 0.85, 1.2]]}}},
  "fall": {"length": 0.15, "loop": false, "pods": false, "bones": {
    "top": {"pos": [[0.0, 0, 0], [0.15, 0, -2]]},
    "core": {"scale": [[0.0, 1, 1], [0.15, 0.9, 1.12]]},
    "front": {"pos": [[0.0, 0, 0], [0.15, 2, 0]]},
    "back": {"pos": [[0.0, 0, 0], [0.15, -2, 0]]}}},
  "land": {"length": 0.12, "loop": false, "pods": false, "bones": {
    "top": {"pos": [[0.0, 0, 5], [0.12, 0, 3]]},
    "core": {"scale": [[0.0, 1.25, 0.7], [0.12, 1.15, 0.8]]},
    "front": {"pos": [[0.0, 3, 0], [0.12, 2, 0]]},
    "back": {"pos": [[0.0, -3, 0], [0.12, -2, 0]]}}},
  "wall": {"length": 0.6, "loop": true, "pods": true, "bones": {
    "top": {"pos": [[0.0, 1.5, -1], [0.3, 1.5, -0.5], [0.6, 1.5, -1]]},
    "front": {"pos": [[0.0, 2, 0], [0.3, 2, 1], [0.6, 2, 0]]},
    "belly": {"pos": [[0.0, 0, 0], [0.3, 0, 1], [0.6, 0, 0]]},
    "core": {"scale": [[0.0, 0.9, 1.1], [0.6, 0.9, 1.1]]}}},
  "spread": {"length": 0.16, "loop": false, "pods": false, "bones": {
    "top": {"pos": [[0.0, 0, 0], [0.16, 0, 8]]},
    "core": {"scale": [[0.0, 1, 1], [0.16, 1.6, 0.35]]},
    "front": {"pos": [[0.0, 0, 0], [0.16, 7, 0]]},
    "back": {"pos": [[0.0, 0, 0], [0.16, -7, 0]]}}},
  "tackle": {"length": 0.15, "loop": false, "pods": true, "bones": {
    "top": {"pos": [[0.0, 0, 0], [0.15, 3, 2]]},
    "front": {"pos": [[0.0, 0, 0], [0.15, 6, 0]]},
    "back": {"pos": [[0.0, 0, 0], [0.15, -3, 0]]},
    "core": {"scale": [[0.0, 1, 1], [0.15, 1.3, 0.8]]}}},
  "cover": {"length": 0.5, "loop": true, "pods": true, "bones": {
    "top": {"pos": [[0.0, 0, 5], [0.25, 0, 3], [0.5, 0, 5]]},
    "core": {"scale": [[0.0, 1.7, 0.7], [0.25, 1.8, 0.62], [0.5, 1.7, 0.7]]},
    "front": {"pos": [[0.0, 6, 1], [0.25, 7, 1], [0.5, 6, 1]]},
    "back": {"pos": [[0.0, -6, 1], [0.25, -7, 1], [0.5, -6, 1]]}}},
  "hurt": {"length": 0.2, "loop": false, "pods": false, "bones": {
    "top": {"pos": [[0.0, -1, 3], [0.2, 0, 1]]},
    "core": {"scale": [[0.0, 1.2, 0.8], [0.2, 1, 1]]}}},
  "rope": {"length": 1.2, "loop": true, "pods": false, "bones": {
    "top": {"pos": [[0.0, 0, -5], [0.6, 1, -5], [1.2, 0, -5]]},
    "core": {"scale": [[0.0, 0.85, 1.25], [1.2, 0.85, 1.25]]},
    "belly": {"pos": [[0.0, -1, 0], [0.6, 1, 0], [1.2, -1, 0]]}}}
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_rig_anim | tail -1`. Expected: `PASS: 7 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/rig/rig_anim.gd scripts/rig/*.uid data/rigs tests/test_rig_anim.gd tests/*.uid
git commit -m "feat: RigAnim samples keyframe tables; the slime's eleven animations as data"
```

---

### Task 4: RigGeometry (outline, interior points, weights, deformation)

**Files:**
- Create: `scripts/rig/rig_geometry.gd`
- Test: `tests/test_rig_geometry.gd`

**Interfaces:**
- Produces (all `static`):
  - `outline(img: Image, epsilon: float = 1.0) -> PackedVector2Array` (the largest opaque polygon, texture pixels)
  - `interior(poly: PackedVector2Array, step: float, margin: float) -> PackedVector2Array`
  - `weights(points: PackedVector2Array, rests: Array) -> Array` (one `PackedFloat32Array` per rest, each entry per point; the entries for a point sum to 1)
  - `delta(transform: Transform2D, rest: Transform2D) -> Transform2D`
  - `deform(points: PackedVector2Array, weights: Array, deltas: Array) -> PackedVector2Array`
  - `hull(points: PackedVector2Array, flip: float = 1.0) -> PackedVector2Array`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_rig_geometry.gd
extends GutTest
## The pure maths behind the skinned body and its hit shapes.

func _blob() -> Image:
	var img := Image.create(20, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(2, 14):
		for x in range(2, 18):
			img.set_pixel(x, y, Color(0.3, 0.6, 1.0, 1.0))
	return img

func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

func test_outline_traces_the_opaque_pixels() -> void:
	var poly := RigGeometry.outline(_blob())
	assert_gte(poly.size(), 4)
	var b := _bounds(poly)
	assert_almost_eq(b.position, Vector2(2, 2), Vector2(1.01, 1.01))
	assert_almost_eq(b.end, Vector2(18, 14), Vector2(1.01, 1.01))

func test_outline_of_an_empty_image_is_empty() -> void:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	assert_eq(RigGeometry.outline(img).size(), 0)

func test_interior_points_lie_inside_and_clear_of_the_edge() -> void:
	var poly := RigGeometry.outline(_blob())
	var pts := RigGeometry.interior(poly, 3.0, 2.0)
	assert_gt(pts.size(), 4)
	for p in pts:
		assert_true(Geometry2D.is_point_in_polygon(p, poly))
		assert_gte(p.x, 4.0 - 0.01)
		assert_lte(p.x, 16.0 + 0.01)

func test_weights_sum_to_one_and_favour_the_nearest_bone() -> void:
	var rests := [Vector2(0, 0), Vector2(20, 0)]
	var pts := PackedVector2Array([Vector2(1, 0), Vector2(19, 0), Vector2(10, 0)])
	var w := RigGeometry.weights(pts, rests)
	assert_eq(w.size(), 2)
	for i in pts.size():
		assert_almost_eq(w[0][i] + w[1][i], 1.0, 0.0001)
	assert_gt(w[0][0], 0.8)
	assert_gt(w[1][1], 0.8)
	assert_almost_eq(w[0][2], 0.5, 0.0001)

func test_identity_deltas_leave_the_points_alone() -> void:
	var rests := [Vector2(0, 0), Vector2(20, 0)]
	var pts := PackedVector2Array([Vector2(3, 4), Vector2(17, -2)])
	var w := RigGeometry.weights(pts, rests)
	var deformed := RigGeometry.deform(pts, w, [Transform2D.IDENTITY, Transform2D.IDENTITY])
	assert_eq(deformed, pts)

func test_moving_one_bone_moves_the_points_near_it_most() -> void:
	var rests := [Vector2(0, 0), Vector2(20, 0)]
	var pts := PackedVector2Array([Vector2(1, 0), Vector2(19, 0)])
	var w := RigGeometry.weights(pts, rests)
	var up := Transform2D(0.0, Vector2(0, -10))
	var deformed := RigGeometry.deform(pts, w, [up, Transform2D.IDENTITY])
	assert_lt(deformed[0].y, -7.0)
	assert_gt(deformed[1].y, -2.0)

func test_delta_is_the_change_from_rest() -> void:
	var rest := Transform2D(0.0, Vector2(5, 5))
	assert_eq(RigGeometry.delta(rest, rest), Transform2D.IDENTITY)
	var moved := Transform2D(0.0, Vector2(8, 5))
	assert_eq(RigGeometry.delta(moved, rest) * Vector2(1, 1), Vector2(4, 1))

func test_hull_is_a_closed_free_convex_polygon_and_can_mirror() -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 5), Vector2(0, 5), Vector2(5, 2)])
	var h := RigGeometry.hull(pts)
	assert_eq(h.size(), 4)
	var m := RigGeometry.hull(pts, -1.0)
	assert_eq(_bounds(m), Rect2(-10, 0, 10, 5))
	assert_eq(RigGeometry.hull(PackedVector2Array([Vector2(1, 1)])).size(), 0)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_rig_geometry`
Expected: FAIL with `Identifier "RigGeometry" not declared`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/rig/rig_geometry.gd
class_name RigGeometry
extends RefCounted
## Pure maths for the skinned body and its hit shapes.

## The outline of the opaque pixels as one polygon (the largest), in texture pixels.
static func outline(img: Image, epsilon: float = 1.0) -> PackedVector2Array:
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.5)
	var best := PackedVector2Array()
	var best_area := 0.0
	var polys := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, bm.get_size()), epsilon)
	for poly in polys:
		var area := _area(poly)
		if area > best_area:
			best = poly
			best_area = area
	return best

## A grid of points inside `poly`, at least `margin` px from its edge, for a smoother skin.
static func interior(poly: PackedVector2Array, step: float, margin: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if poly.size() < 3:
		return out
	var inset := Geometry2D.offset_polygon(poly, -margin)
	if inset.is_empty():
		return out
	var core: PackedVector2Array = inset[0]
	var lo := core[0]
	var hi := core[0]
	for p in core:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var y := lo.y
	while y <= hi.y:
		var x := lo.x
		while x <= hi.x:
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, core):
				out.append(p)
			x += step
		y += step
	return out

## Inverse-square-distance weights: one array per rest position, each entry per point.
static func weights(points: PackedVector2Array, rests: Array) -> Array:
	var out: Array = []
	for _bone in rests:
		out.append(PackedFloat32Array())
	for p in points:
		var raw: Array = []
		var total := 0.0
		for r in rests:
			var w := 1.0 / (p.distance_squared_to(Vector2(r)) + 4.0)
			raw.append(w)
			total += w
		for i in rests.size():
			out[i].append(float(raw[i]) / total)
	return out

## The change a bone makes from its rest, in the skeleton's space.
static func delta(transform: Transform2D, rest: Transform2D) -> Transform2D:
	return transform * rest.affine_inverse()

## CPU skinning: each point becomes the weighted sum of itself moved by every bone's delta.
static func deform(points: PackedVector2Array, weights_by_bone: Array, deltas: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(points.size())
	for i in points.size():
		var v := Vector2.ZERO
		for b in deltas.size():
			var d: Transform2D = deltas[b]
			var w: PackedFloat32Array = weights_by_bone[b]
			v += (d * points[i]) * w[i]
		out[i] = v
	return out

## The convex hull as an open polygon (no repeated last point), optionally mirrored in x
## (`flip` -1). Fewer than three distinct points give an empty polygon.
static func hull(points: PackedVector2Array, flip: float = 1.0) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array()
	var h := Geometry2D.convex_hull(points)
	if h.size() > 1 and h[0] == h[h.size() - 1]:
		h.resize(h.size() - 1)
	if h.size() < 3:
		return PackedVector2Array()
	if flip < 0.0:
		for i in h.size():
			h[i] = Vector2(-h[i].x, h[i].y)
	return h

static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_rig_geometry | tail -1`. Expected: `PASS: 8 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/rig/rig_geometry.gd scripts/rig/*.uid tests/test_rig_geometry.gd tests/*.uid
git commit -m "feat: RigGeometry outline, weights and CPU skinning"
```

---

### Task 5: SlimeRig (the rig node)

**Files:**
- Create: `scripts/rig/slime_rig.gd`
- Test: `tests/test_slime_rig.gd`

**Interfaces:**
- Consumes: `RigConfig`, `RigAnim`, `RigGeometry`, the parts and `data/rigs/slime_anims.json`.
- Produces `SlimeRig` (a `Node2D`; its origin is the body's bottom centre):
  - `SlimeRig.available() -> bool`
  - `play(state: String) -> void`, `snap(state: String) -> void` (jump straight to the state's first pose, no blend), `advance(delta: float) -> void`
  - `state() -> String`, `pose_of(bone: String) -> Dictionary`
  - `flip(left: bool) -> void`, var `facing_left: bool`
  - `deformed_points() -> PackedVector2Array` (rig space), `points_for(bone: String, min_weight: float) -> PackedVector2Array`
  - `viewport_image() -> Image`
  - Nodes and vars: `viewport: SubViewport`, `display: Sprite2D`, `skeleton: Skeleton2D`, `body: Polygon2D`, `bones: Dictionary` (name → `Bone2D`), `eyes`, `pods` (`Array`), `points: PackedVector2Array`, `weights: Array`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_slime_rig.gd
extends GutTest
## The rig node: a skinned body on a skeleton, eyes and pods on bones, drawn at native size.

var rig: SlimeRig

func before_each() -> void:
	rig = SlimeRig.new()
	add_child_autofree(rig)

func test_the_rig_assets_are_available() -> void:
	assert_true(SlimeRig.available())

func test_it_builds_a_skeleton_and_a_skinned_body() -> void:
	assert_eq(rig.bones.size(), RigAnim.BONES.size())
	assert_eq(rig.skeleton.get_bone_count(), RigAnim.BONES.size())
	assert_eq(rig.body.get_bone_count(), RigAnim.BONES.size())
	assert_gte(rig.body.polygon.size(), 8)
	assert_eq(rig.body.uv.size(), rig.body.polygon.size())
	assert_gt(rig.body.internal_vertex_count, 0)
	assert_eq(rig.points.size(), rig.body.polygon.size())
	for b in rig.body.get_bone_count():
		assert_eq(rig.body.get_bone_weights(b).size(), rig.body.polygon.size())
	for i in rig.points.size():
		var total := 0.0
		for b in rig.weights.size():
			total += rig.weights[b][i]
		assert_almost_eq(total, 1.0, 0.001)

func test_it_draws_into_a_small_viewport_with_no_smoothing() -> void:
	assert_eq(rig.viewport.size, RigConfig.view_size())
	assert_true(rig.viewport.transparent_bg)
	assert_eq(rig.viewport.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	assert_eq(rig.display.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(rig.display.position, RigConfig.display_offset())

func test_eyes_and_pods_ride_the_bones() -> void:
	assert_eq(rig.eyes.size(), 2)
	for e in rig.eyes:
		assert_eq(e.get_parent(), rig.bones["core"])
	assert_eq(rig.pods.size(), 2)
	assert_eq(rig.pods[0].get_parent(), rig.bones["front"])
	assert_eq(rig.pods[1].get_parent(), rig.bones["back"])

func test_playing_a_state_poses_the_bones() -> void:
	rig.snap("idle")
	assert_eq(rig.state(), "idle")
	rig.snap("spread")
	rig.advance(1.0)
	assert_eq(rig.state(), "spread")
	assert_almost_eq(rig.pose_of("core")["scale"].y, 0.35, 0.02)
	assert_almost_eq(rig.pose_of("core")["scale"].x, 1.6, 0.02)
	var core: Bone2D = rig.bones["core"]
	assert_almost_eq(core.scale.y, 0.35, 0.02)

func test_a_new_state_blends_in_instead_of_snapping() -> void:
	rig.snap("idle")
	rig.play("spread")
	rig.advance(0.01)
	var mid := float(rig.pose_of("core")["scale"].y)
	assert_gt(mid, 0.5)
	rig.advance(1.0)
	assert_almost_eq(float(rig.pose_of("core")["scale"].y), 0.35, 0.02)

func test_pods_show_only_in_states_that_use_them() -> void:
	rig.snap("idle")
	assert_false(rig.pods[0].visible)
	rig.snap("wall")
	assert_true(rig.pods[0].visible)
	assert_true(rig.pods[1].visible)

func test_deformation_follows_the_pose() -> void:
	rig.snap("idle")
	rig.advance(0.0)
	var rest := rig.deformed_points()
	rig.snap("spread")
	rig.advance(1.0)
	var flat := rig.deformed_points()
	assert_eq(rest.size(), flat.size())
	assert_lt(_height(flat), _height(rest) * 0.7)
	assert_gt(_width(flat), _width(rest))

func test_points_for_a_bone_selects_the_nearby_skin() -> void:
	rig.snap("idle")
	var front := rig.points_for("front", 0.4)
	assert_gt(front.size(), 0)
	assert_lt(front.size(), rig.points.size())
	for p in front:
		assert_gt(p.x, 0.0)

func test_flip_mirrors_the_display() -> void:
	rig.flip(true)
	assert_true(rig.display.flip_h)
	assert_true(rig.facing_left)
	rig.flip(false)
	assert_false(rig.display.flip_h)

func _height(pts: PackedVector2Array) -> float:
	var lo := pts[0].y
	var hi := pts[0].y
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	return hi - lo

func _width(pts: PackedVector2Array) -> float:
	var lo := pts[0].x
	var hi := pts[0].x
	for p in pts:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return hi - lo
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_slime_rig`
Expected: FAIL with `Identifier "SlimeRig" not declared`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/rig/slime_rig.gd
class_name SlimeRig
extends Node2D
## The rigged slime. A skinned Polygon2D body on a Skeleton2D, with eyes and pods riding the
## bones, drawn into a small SubViewport with no smoothing and shown by a Sprite2D, so bent
## parts snap to the pixel grid. The node's origin is the body's bottom centre.

const DIR := "res://assets/rigs/slime/"
const ANIMS := "res://data/rigs/slime_anims.json"
const BLEND_SECONDS := 0.08
const INTERIOR_STEP := 6.0
const INTERIOR_MARGIN := 3.0

var viewport := SubViewport.new()
var display := Sprite2D.new()
var skeleton := Skeleton2D.new()
var body := Polygon2D.new()
var bones := {}
var eyes: Array[Sprite2D] = []
var pods: Array[Sprite2D] = []
var points := PackedVector2Array()   # outline + interior, in rig space
var weights: Array = []              # one PackedFloat32Array per bone (RigAnim.BONES order)
var facing_left := false
var _anims := {}
var _state := ""
var _time := 0.0
var _blend_left := 0.0
var _from := {}
var _pose := {}

static func available() -> bool:
	return ResourceLoader.exists(DIR + "body.png") and ResourceLoader.exists(DIR + "eye.png") \
		and ResourceLoader.exists(DIR + "pod.png") and FileAccess.file_exists(ANIMS)

func _init() -> void:
	if not available():
		return
	_anims = RigAnim.load_table(ANIMS)
	_build()
	_pose = RigAnim.rest_pose()
	snap("idle")

func state() -> String:
	return _state

func pose_of(bone: String) -> Dictionary:
	return _pose[bone]

func flip(left: bool) -> void:
	facing_left = left
	display.flip_h = left

## Start playing `state`, blending from the current pose.
func play(state_name: String) -> void:
	if state_name == _state or not _anims.has(state_name):
		return
	_from = _pose
	_blend_left = BLEND_SECONDS
	_enter(state_name)

## Jump straight to the first pose of `state`, with no blend.
func snap(state_name: String) -> void:
	if not _anims.has(state_name):
		return
	_blend_left = 0.0
	_enter(state_name)
	_apply(RigAnim.sample(_anims[_state], 0.0))

func advance(delta: float) -> void:
	if _state == "":
		return
	_time += delta
	var target := RigAnim.sample(_anims[_state], _time)
	if _blend_left > 0.0:
		_blend_left = maxf(0.0, _blend_left - delta)
		target = RigAnim.blend(_from, target, 1.0 - _blend_left / BLEND_SECONDS)
	_apply(target)

## The body's skin in rig space, deformed by the current bone poses.
func deformed_points() -> PackedVector2Array:
	var deltas: Array = []
	for bone_name in RigAnim.BONES:
		var b: Bone2D = bones[bone_name]
		deltas.append(RigGeometry.delta(b.transform, b.rest))
	return RigGeometry.deform(points, weights, deltas)

## The deformed skin points that `bone` moves at least `min_weight` of the way.
func points_for(bone: String, min_weight: float) -> PackedVector2Array:
	var idx := RigAnim.BONES.find(bone)
	var deformed := deformed_points()
	var out := PackedVector2Array()
	var w: PackedFloat32Array = weights[idx]
	for i in deformed.size():
		if w[i] >= min_weight:
			out.append(deformed[i])
	return out

func viewport_image() -> Image:
	return viewport.get_texture().get_image()

func _enter(state_name: String) -> void:
	_state = state_name
	_time = 0.0
	var show_pods := bool(_anims[state_name].get("pods", false))
	for p in pods:
		p.visible = show_pods

func _apply(pose: Dictionary) -> void:
	var s := float(RigConfig.SCALE)
	for bone_name in RigAnim.BONES:
		var p: Dictionary = pose[bone_name]
		var b: Bone2D = bones[bone_name]
		b.transform = Transform2D(float(p["rot"]), Vector2(p["scale"]), 0.0,
			RigConfig.bone_rest(bone_name) + Vector2(p["pos"]) * s)
	_pose = pose

func _build() -> void:
	viewport.size = RigConfig.view_size()
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var origin := Node2D.new()
	origin.name = "Origin"
	origin.position = RigConfig.origin()
	viewport.add_child(origin)

	var body_tex: Texture2D = load(DIR + "body.png")
	var img := body_tex.get_image()
	var size := Vector2(img.get_size())
	var offset := Vector2(-size.x / 2.0, -size.y)  # texture pixels -> rig space
	var outline := RigGeometry.outline(img)
	var inner := RigGeometry.interior(outline, INTERIOR_STEP, INTERIOR_MARGIN)
	var poly := PackedVector2Array(outline)
	poly.append_array(inner)
	body.texture = body_tex
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.polygon = poly
	body.uv = poly
	body.internal_vertex_count = inner.size()
	body.offset = offset
	origin.add_child(body)
	origin.add_child(skeleton)

	var rests: Array = []
	for bone_name in RigAnim.BONES:
		var b := Bone2D.new()
		b.name = bone_name
		b.set_autocalculate_length_and_angle(false)
		skeleton.add_child(b)
		b.transform = Transform2D(0.0, RigConfig.bone_rest(bone_name))
		b.rest = b.transform
		bones[bone_name] = b
		rests.append(RigConfig.bone_rest(bone_name))
	body.skeleton = body.get_path_to(skeleton)
	points = PackedVector2Array()
	for p in poly:
		points.append(p + offset)
	weights = RigGeometry.weights(points, rests)
	for i in RigAnim.BONES.size():
		body.add_bone(body.get_path_to(bones[RigAnim.BONES[i]]), weights[i])

	var eye_tex: Texture2D = load(DIR + "eye.png")
	for f in RigConfig.EYES:
		var e := Sprite2D.new()
		e.texture = eye_tex
		e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		e.position = RigConfig.fraction_to_rig(f) - RigConfig.bone_rest("core")
		bones["core"].add_child(e)
		eyes.append(e)
	var pod_tex: Texture2D = load(DIR + "pod.png")
	for bone_name in ["front", "back"]:
		var pod := Sprite2D.new()
		pod.texture = pod_tex
		pod.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pod.flip_h = bone_name == "back"
		pod.position = Vector2(pod_tex.get_width() * (0.4 if bone_name == "front" else -0.4), 0.0)
		pod.visible = false
		bones[bone_name].add_child(pod)
		pods.append(pod)

	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = RigConfig.display_offset()
	add_child(display)
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_slime_rig | tail -1`. Expected: `PASS: 10 tests`.
If a Godot API call errors (for example a `Bone2D` or `Polygon2D` property), read the SCRIPT ERROR line, fix that call, and rerun. Do not weaken a test.

- [ ] **Step 5: Commit**

```bash
git add scripts/rig/slime_rig.gd scripts/rig/*.uid tests/test_slime_rig.gd tests/*.uid
git commit -m "feat: SlimeRig, a skinned slime body on a skeleton drawn at native pixel size"
```

---

### Task 6: First look: contact sheet, and tuning the animations

This is where you see whether the rig works. It produces no new production code, but it is the
first real check that the skinned mesh renders and deforms.

**Files:**
- Create: `tools/rig/contact_sheet.gd`
- Modify (only if the look needs it): `data/rigs/slime_anims.json`, `scripts/rig/rig_config.gd` (bone fractions and eye positions), `tools/art/rig/parts.json`

**Interfaces:**
- Consumes: `SlimeRig`, `SlimeState.ALL`, `Art.texture`.
- Produces: `.tmp/rig-spike/contact_sheet.png` (one row per animation, six samples across, then the old sprite at 1× and at the rig's scale for comparison).

- [ ] **Step 1: Write the tool**

```gdscript
# tools/rig/contact_sheet.gd
extends SceneTree
## Renders every slime animation into a contact sheet: one row per animation in SlimeState.ALL
## order, SAMPLES frames across, then today's sprite at 1x and at the rig's scale.
## Needs a real renderer (a headless one draws nothing). Run from the project root:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/contact_sheet.gd

const OUT := "res://.tmp/rig-spike/contact_sheet.png"
const SAMPLES := 6
const STEP := 0.06
const OLD := {"idle": "slime_idle", "run": "slime_idle", "rise": "slime_jump", "fall": "slime_jump",
	"land": "slime_land", "cover": "slime_eat", "hurt": "slime_land", "rope": "slime_jump",
	"wall": "slime_idle", "tackle": "slime_idle", "spread": "slime_land"}

var rig: SlimeRig
var sheet: Image
var cell := Vector2i.ZERO
var row := 0
var col := 0
var phase := 0
var _started := false

func _initialize() -> void:
	rig = SlimeRig.new()
	root.add_child(rig)
	cell = RigConfig.view_size()
	sheet = Image.create(cell.x * (SAMPLES + 2), cell.y * SlimeState.ALL.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.07, 0.07, 0.13, 1.0))

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		rig.snap(SlimeState.ALL[0])
		return false
	var state: String = SlimeState.ALL[row]
	if phase == 0:
		rig.advance(STEP)
		phase = 1
		return false
	var img := rig.viewport_image()
	sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(col * cell.x, row * cell.y))
	col += 1
	phase = 0
	if col == SAMPLES:
		_old_sprites(state)
		col = 0
		row += 1
		if row == SlimeState.ALL.size():
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp/rig-spike"))
			sheet.save_png(ProjectSettings.globalize_path(OUT))
			print("rows (top to bottom): ", SlimeState.ALL)
			print("wrote ", ProjectSettings.globalize_path(OUT))
			quit()
		else:
			rig.snap(SlimeState.ALL[row])
	return false

## Today's sprite for this state, bottom-aligned on the rig's origin, at 1x and at the rig scale.
func _old_sprites(state: String) -> void:
	var tex := Art.texture(OLD[state])
	if tex == null:
		return
	var src := tex.get_image()
	var origin := RigConfig.origin()
	for k in 2:
		var scale_px := 1 if k == 0 else RigConfig.SCALE
		var scaled := Image.new()
		scaled.copy_from(src)
		scaled.resize(src.get_width() * scale_px, src.get_height() * scale_px, Image.INTERPOLATE_NEAREST)
		var base := Vector2i((SAMPLES + k) * cell.x, row * cell.y)
		sheet.blend_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()),
			base + Vector2i(int(origin.x) - scaled.get_width() / 2, int(origin.y) - scaled.get_height()))
```

- [ ] **Step 2: Run it (windowed, sandbox disabled) and read the result**

```bash
mkdir -p .tmp/rig-spike && gtimeout -k 5 90 env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/contact_sheet.gd 2>&1 | grep -E "rows|wrote|ERROR"
```
Expected: `rows (top to bottom): [...]` and `wrote .../.tmp/rig-spike/contact_sheet.png`.
**Read `.tmp/rig-spike/contact_sheet.png`.** Check, row by row, against the legend printed above:
- the body renders (not blank), the eyes sit on it, and it stays crisp;
- the body deforms with each pose (spread flat and wide, rise tall, land squashed);
- the pods appear on wall, tackle and cover only;
- nothing is clipped by the viewport edge.

- [ ] **Step 3: Fix what is wrong, and re-render, until it reads**

The likely fixes, in order:
- **Blank or unskinned body:** re-check `body.skeleton`, the bone paths, and `Bone2D.rest`. Run the probe of the bone transforms in a scratch script and compare with the test values.
- **Poses too strong or too weak:** edit the numbers in `data/rigs/slime_anims.json` only.
- **Eyes or pods misplaced:** edit `RigConfig.EYES` or the pod offset in `SlimeRig._build`.
- **Body too coarse when deformed:** lower `INTERIOR_STEP` in `SlimeRig`.
Re-run `tools/run_tests.sh test_slime_rig test_rig_anim` after each change (no test may be weakened), and re-render.
Keep iterating until you would show the sheet to Sean. Record in the commit message what you changed.

- [ ] **Step 4: Commit**

```bash
git add tools/rig data/rigs scripts/rig tools/art/rig tests
git commit -m "feat: rig contact sheet, and first tuning of the slime's animations"
```

---

### Task 7: RigShapes (hurt and attack shapes that follow the skin)

**Files:**
- Create: `scripts/rig/rig_shapes.gd`
- Test: `tests/test_rig_shapes.gd`

**Interfaces:**
- Consumes: `SlimeRig` (`deformed_points`, `points_for`, `state`, `facing_left`), `RigGeometry.hull`.
- Produces `RigShapes` (a `Node2D`): `bind(rig: SlimeRig)`, `refresh()`, vars `hurt: Area2D`, `attack: Area2D`, `hurt_poly: CollisionPolygon2D`, `attack_poly: CollisionPolygon2D`; `const ATTACK_WEIGHT := 0.4`.
  The shapes are in rig space (origin at the body's bottom centre), mirrored when the rig faces left.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_rig_shapes.gd
extends GutTest
## Hurt and attack shapes follow the skinned body. They live in the main world (a SubViewport has
## its own physics), and are inert in the spike.

var rig: SlimeRig
var shapes: RigShapes

func before_each() -> void:
	var holder := Node2D.new()
	add_child_autofree(holder)
	rig = SlimeRig.new()
	holder.add_child(rig)
	shapes = RigShapes.new()
	holder.add_child(shapes)
	shapes.bind(rig)

func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r

func test_the_hurt_shape_wraps_the_body() -> void:
	rig.snap("idle")
	shapes.refresh()
	assert_gte(shapes.hurt_poly.polygon.size(), 3)
	var b := _bounds(shapes.hurt_poly.polygon)
	var size := RigConfig.body_size()
	assert_almost_eq(b.size.x, size.x, size.x * 0.25)
	assert_almost_eq(b.size.y, size.y, size.y * 0.25)
	assert_lte(b.end.y, 1.0)  # nothing below the floor line (the origin is the body's bottom)

func test_spread_flattens_the_hurt_shape() -> void:
	rig.snap("idle")
	shapes.refresh()
	var idle := _bounds(shapes.hurt_poly.polygon)
	rig.snap("spread")
	rig.advance(1.0)
	shapes.refresh()
	var flat := _bounds(shapes.hurt_poly.polygon)
	assert_lt(flat.size.y, idle.size.y * 0.7)
	assert_gt(flat.size.x, idle.size.x)

func test_the_attack_shape_exists_only_while_tackling_and_sits_at_the_front() -> void:
	rig.snap("idle")
	shapes.refresh()
	assert_eq(shapes.attack_poly.polygon.size(), 0)
	assert_true(shapes.attack_poly.disabled)
	rig.snap("tackle")
	rig.advance(1.0)
	shapes.refresh()
	assert_gte(shapes.attack_poly.polygon.size(), 3)
	assert_false(shapes.attack_poly.disabled)
	var b := _bounds(shapes.attack_poly.polygon)
	assert_gt(b.get_center().x, 0.0)

func test_shapes_mirror_when_the_rig_faces_left() -> void:
	rig.snap("tackle")
	rig.advance(1.0)
	shapes.refresh()
	var right := _bounds(shapes.attack_poly.polygon)
	rig.flip(true)
	shapes.refresh()
	var left := _bounds(shapes.attack_poly.polygon)
	assert_almost_eq(left.get_center().x, -right.get_center().x, 0.01)

func test_shapes_live_in_the_player_tree_and_are_inert() -> void:
	assert_eq(shapes.hurt.collision_layer, 0)
	assert_eq(shapes.hurt.collision_mask, 0)
	assert_eq(shapes.attack.collision_layer, 0)
	assert_eq(shapes.attack.collision_mask, 0)
	assert_false(rig.viewport.is_ancestor_of(shapes.hurt))
	assert_false(shapes.is_ancestor_of(rig.viewport))

func test_shapes_stay_inside_the_drawn_area() -> void:
	for state in SlimeState.ALL:
		rig.snap(state)
		rig.advance(1.0)
		shapes.refresh()
		var view := Rect2(-RigConfig.origin(), Vector2(RigConfig.view_size()))
		for p in shapes.hurt_poly.polygon:
			assert_true(view.grow(0.5).has_point(p), "%s hurt point %s" % [state, p])
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_rig_shapes`
Expected: FAIL with `Identifier "RigShapes" not declared`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/rig/rig_shapes.gd
class_name RigShapes
extends Node2D
## Hurt and attack shapes that follow the rigged body's skin, built from the same deformation as
## the drawn mesh. They live in the main world (the rig draws inside a SubViewport, which has its
## own physics world) and are inert in the spike (collision layers 0): the spike proves they
## follow the skin, and a later plan switches the game's hit checks over to them.
## Positions are in rig space: the origin is the body's bottom centre.

## A skin point belongs to the attack shape when the front bone moves it at least this much.
const ATTACK_WEIGHT := 0.4

var hurt := Area2D.new()
var attack := Area2D.new()
var hurt_poly := CollisionPolygon2D.new()
var attack_poly := CollisionPolygon2D.new()
var _rig: SlimeRig

func _init() -> void:
	hurt.name = "Hurt"
	attack.name = "Attack"
	for a in [hurt, attack]:
		a.collision_layer = 0
		a.collision_mask = 0
	hurt.add_child(hurt_poly)
	attack.add_child(attack_poly)
	add_child(hurt)
	add_child(attack)
	attack_poly.disabled = true

func bind(rig: SlimeRig) -> void:
	_rig = rig
	refresh()

## Rebuild both shapes from the rig's current pose. Call once per frame after the rig advances.
func refresh() -> void:
	if _rig == null:
		return
	var flip := -1.0 if _rig.facing_left else 1.0
	hurt_poly.polygon = RigGeometry.hull(_rig.deformed_points(), flip)
	var attacking := _rig.state() == "tackle"
	attack_poly.polygon = RigGeometry.hull(_rig.points_for("front", ATTACK_WEIGHT), flip) if attacking \
		else PackedVector2Array()
	attack_poly.disabled = not attacking or attack_poly.polygon.size() < 3
```

- [ ] **Step 4: Run it to verify it passes**

Run: import, then `tools/run_tests.sh test_rig_shapes | tail -1`. Expected: `PASS: 6 tests`.
If `test_shapes_stay_inside_the_drawn_area` fails, a pose pushes the skin outside the viewport:
enlarge `RigConfig.VIEW`/`ORIGIN` margins (and update `test_display_is_centred_over_the_rig_origin`'s
expected number), or soften that pose. Do not weaken the test.

- [ ] **Step 5: Commit**

```bash
git add scripts/rig/rig_shapes.gd scripts/rig/*.uid tests/test_rig_shapes.gd tests/*.uid
git commit -m "feat: RigShapes, hurt and attack shapes that follow the skinned body"
```

---

### Task 8: Player uses the rig, and Spread

**Files:**
- Modify: `scripts/player/player.gd`
- Test: `tests/test_player_spread.gd`

**Interfaces:**
- Consumes: `SlimeRig`, `SlimeState`, `RigShapes`, `RigConfig`.
- Produces on `Player`:
  - `const USE_RIG := true`, `const SPREAD_HOLD := 0.6`, `const SPREAD_SPEED := 0.5`, `const HURT_FLASH := 0.25`
  - `BODY_BOTTOM := 6.0 * RigConfig.SCALE` (changed)
  - `static wants_spread(on_floor: bool, snapped: Vector2, raw_y: float, was_spread: bool) -> bool`
  - `set_spread(v: bool) -> void`, var `spreading: bool`, `_can_stand() -> bool`, `_walk_speed() -> float`
  - `_clinging() -> bool`, `_rig_faces_left(state: String, wall_normal: Vector2) -> bool`
  - vars `_rig: SlimeRig`, `_shapes: RigShapes`, `_shape: CollisionShape2D`, `_rect: RectangleShape2D`, `_tackle_time: float`

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_player_spread.gd
extends GutTest
## The Player wears the rig, and Spread: flatten on the floor with the aim straight down.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _solid(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = r.position + r.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	return body

func _floor() -> void:
	_solid(Rect2(-300, Player.BODY_BOTTOM, 600, 20))

func test_spread_wants_the_floor_and_a_straight_down_aim() -> void:
	assert_true(Player.wants_spread(true, Vector2.DOWN, 1.0, false))
	assert_false(Player.wants_spread(false, Vector2.DOWN, 1.0, false))
	assert_false(Player.wants_spread(true, Vector2(1, 1).normalized(), 0.7, false))
	assert_false(Player.wants_spread(true, Vector2.DOWN, 0.4, false))

func test_once_spread_it_holds_while_down_stays_pressed() -> void:
	assert_true(Player.wants_spread(true, Vector2(1, 1).normalized(), 0.7, true))
	assert_false(Player.wants_spread(true, Vector2.RIGHT, 0.1, true))
	assert_false(Player.wants_spread(false, Vector2.DOWN, 1.0, true))

func test_spread_shrinks_the_collision_box_and_keeps_its_bottom_on_the_floor() -> void:
	var s := float(RigConfig.SCALE)
	assert_eq(player._rect.size, RigConfig.COLLISION * s)
	assert_almost_eq(player._shape.position.y + player._rect.size.y / 2.0, Player.BODY_BOTTOM, 0.001)
	player.set_spread(true)
	assert_true(player.spreading)
	assert_eq(player._rect.size, RigConfig.SPREAD_COLLISION * s)
	assert_almost_eq(player._shape.position.y + player._rect.size.y / 2.0, Player.BODY_BOTTOM, 0.001)
	player.set_spread(false)
	assert_eq(player._rect.size, RigConfig.COLLISION * s)

func test_spread_halves_the_walking_speed() -> void:
	var normal := player._walk_speed()
	player.set_spread(true)
	assert_almost_eq(player._walk_speed(), normal * Player.SPREAD_SPEED, 0.001)

func test_the_rig_shows_spread_and_idle() -> void:
	_floor()
	await wait_physics_frames(6)
	assert_true(player.is_on_floor())
	player._update_visual(0.016)
	assert_eq(player._rig.state(), "idle")
	player.set_spread(true)
	player._update_visual(0.016)
	assert_eq(player._rig.state(), "spread")

func test_no_jump_or_stand_under_a_low_ceiling() -> void:
	_floor()
	await wait_physics_frames(6)
	player.set_spread(true)
	var rise := (RigConfig.COLLISION.y - RigConfig.SPREAD_COLLISION.y) * RigConfig.SCALE
	var top := Player.BODY_BOTTOM - RigConfig.SPREAD_COLLISION.y * RigConfig.SCALE
	var ceiling := _solid(Rect2(-40, top - rise / 2.0 - 4.0, 80, 4.0))
	await wait_physics_frames(2)
	assert_false(player._can_stand())
	player.do_jump()
	assert_true(player.spreading)
	assert_eq(player.velocity.y, 0.0)
	ceiling.free()
	await wait_physics_frames(2)
	assert_true(player._can_stand())
	player.do_jump()
	assert_false(player.spreading)
	assert_lt(player.velocity.y, 0.0)

func test_the_wall_grip_faces_the_wall() -> void:
	# a wall on the left has its normal pointing right, so the slime (facing right) must flip
	assert_true(player._rig_faces_left("wall", Vector2.RIGHT))
	assert_false(player._rig_faces_left("wall", Vector2.LEFT))
	player.facing = -1
	assert_true(player._rig_faces_left("idle", Vector2.ZERO))
	player.facing = 1
	assert_false(player._rig_faces_left("idle", Vector2.ZERO))

func test_every_room_exit_fits_the_rigged_slime() -> void:
	var rooms := World.load_rooms("res://data/rooms")
	var body := RigConfig.COLLISION * float(RigConfig.SCALE)
	for id in rooms:
		for e in (rooms[id] as RoomDef).exits:
			var span := float(e["to"]) - float(e["from"])
			var needed := body.y if e["edge"] == "left" or e["edge"] == "right" else body.x
			assert_gte(span, needed + 8.0, "%s %s exit" % [id, e["edge"]])

func test_the_player_falls_back_to_the_sprite_without_rig_assets() -> void:
	assert_true(SlimeRig.available())
	assert_not_null(player._rig)
	assert_true(player.get_node("Sprite") is Sprite2D)
	assert_false(player.get_node("Sprite").visible)
	var bare := Player.new()
	bare.use_rig = false
	bare.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(bare)
	assert_null(bare._rig)
	assert_true(bare.get_node("Sprite").visible)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_player_spread`
Expected: FAIL: `Nonexistent function 'wants_spread'` / no member `_rect` (SCRIPT ERROR lines).

- [ ] **Step 3: Implement it in `scripts/player/player.gd`**

Apply these edits.

Constants (replace the `BODY_BOTTOM` line, and add the others beside it):
```gdscript
const BODY_BOTTOM := 6.0 * RigConfig.SCALE  # collision box bottom, where the body stands
## Hold down (aim snapped straight down) on the floor and the slime flattens into a puddle.
const SPREAD_HOLD := 0.6
const SPREAD_SPEED := 0.5
const HURT_FLASH := 0.25
```
Vars (beside `var _sprite: Sprite2D`):
```gdscript
## Set false before adding to the tree to use the old sprite instead of the rig.
var use_rig := true
var spreading := false
var _rig: SlimeRig
var _shapes: RigShapes
var _shape: CollisionShape2D
var _rect: RectangleShape2D
var _tackle_time := 0.0
```
In `_physics_process`, right after `var dir := Input.get_axis(...)` and the predation line, add:
```gdscript
	set_spread(wants_spread(is_on_floor(), aim_vector(), raw_aim().y, spreading))
	_tackle_time = maxf(0.0, _tackle_time - delta)
```
Replace both `dir * SPEED * stats.get_stat("spd") / 100.0` occurrences (the walking assignment and the `move_toward` target) with `dir * _walk_speed()`.

Add these methods (near `do_jump`):
```gdscript
## Spread starts on the floor with the aim snapped straight down and the stick (or keys) held at
## least SPREAD_HOLD; once spread, it holds while `raw_y` stays at or above SPREAD_HOLD.
static func wants_spread(on_floor: bool, snapped: Vector2, raw_y: float, was_spread: bool) -> bool:
	if not on_floor:
		return false
	if was_spread:
		return raw_y >= SPREAD_HOLD
	return snapped == Vector2.DOWN and raw_y >= SPREAD_HOLD

func _walk_speed() -> float:
	return SPEED * stats.get_stat("spd") / 100.0 * (SPREAD_SPEED if spreading else 1.0)

## Flattens or stands the slime. The collision box keeps its bottom on the floor, and standing
## needs room above.
func set_spread(value: bool) -> void:
	if value == spreading:
		return
	if not value and not _can_stand():
		return
	spreading = value
	var size := (RigConfig.SPREAD_COLLISION if value else RigConfig.COLLISION) * float(RigConfig.SCALE)
	_rect.size = size
	_shape.position.y = BODY_BOTTOM - size.y / 2.0

## True when nothing solid sits within the extra height a standing slime needs.
func _can_stand() -> bool:
	var rise := (RigConfig.COLLISION.y - RigConfig.SPREAD_COLLISION.y) * float(RigConfig.SCALE)
	return not test_move(global_transform, Vector2(0.0, -rise))

func _clinging() -> bool:
	return skillset.has("wall_cling") and is_on_wall() and not is_on_floor() and velocity.y > 0.0

## The wall grip is drawn on the wall's side, from the wall normal (a wall on the left has a
## normal pointing right). Every other state follows `facing`.
func _rig_faces_left(state: String, wall_normal: Vector2) -> bool:
	if state == "wall":
		return wall_normal.x > 0.0
	return facing < 0
```
At the top of `do_jump()` (after the dead/predating guard):
```gdscript
	if spreading:
		if not _can_stand():
			return
		set_spread(false)
```
In `do_tackle()`, after `_dash = TACKLE_SECONDS`: `	_tackle_time = TACKLE_SECONDS`.

`_build_body()`: keep a handle on the shape and box, size them from the scale, and add the rig:
```gdscript
func _build_body() -> void:
	_shape = CollisionShape2D.new()
	_rect = RectangleShape2D.new()
	_rect.size = RigConfig.COLLISION * float(RigConfig.SCALE)
	_shape.shape = _rect
	add_child(_shape)
	_sprite = Art.sprite("slime_idle", BODY_BOTTOM)
	add_child(_sprite)
	if use_rig and SlimeRig.available():
		_rig = SlimeRig.new()
		_rig.position = Vector2(0.0, BODY_BOTTOM)
		add_child(_rig)
		_shapes = RigShapes.new()
		_shapes.position = Vector2(0.0, BODY_BOTTOM)
		add_child(_shapes)
		_shapes.bind(_rig)
		_sprite.visible = false
	add_child(Art.light(Color(0.4, 0.75, 1.0), 0.8, 1.2))  # the slime's soft inner glow
	# ... the rest of the existing function (eat_prompt setup) is unchanged
```
Remove the old `var shape := CollisionShape2D.new()` / `var rect := RectangleShape2D.new()` / `rect.size = Vector2(14, 12)` / `shape.shape = rect` / `add_child(shape)` lines that this replaces.

`_update_visual`: keep the old sprite update (so the old tests still hold), then drive the rig:
```gdscript
	Art.set_frame(_sprite, pick_frame(predation.active(), on_floor, _land_timer), BODY_BOTTOM)
	_sprite.flip_h = facing < 0
	if _rig != null:
		var state := SlimeState.pick(predation.active(), _invuln > INVULN_SECONDS - HURT_FLASH, rope != null,
			_clinging(), _tackle_time > 0.0, spreading, on_floor, velocity.y, _land_timer, velocity.x)
		_rig.play(state)
		_rig.advance(delta)
		_rig.flip(_rig_faces_left(state, get_wall_normal() if is_on_wall() else Vector2.ZERO))
		_shapes.refresh()
```
(The `Art.set_frame` line already exists; place the rig block after the `_sprite.flip_h` line.)

The old `_sprite` is at `res://assets/sprites/slime_idle.png` scale; it is hidden when the rig is on, so it does not matter that it is now smaller than the box.

- [ ] **Step 4: Run it to verify it passes, then the full suite**

Run: `tools/run_tests.sh test_player_spread | tail -2` then `tools/run_tests.sh | tail -1`.
Expected: `PASS: 9 tests` for the first; the full suite green (existing tests such as
`test_art_visuals` still pass because the old sprite is still updated). If an existing test broke
because the collision box is now 28×24, read it and fix the *test's* assumption only when it
encodes the old 14×12 size; record the change in the commit message.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player.gd tests/test_player_spread.gd tests/*.uid
git commit -m "feat: the Player wears the rig; Spread, at twice the slime's size"
```

---

### Task 9: Eating by covering

**Files:**
- Create: `scripts/rig/eat_cover.gd`
- Modify: `scripts/player/predation_hold.gd` (add `progress()`), `scripts/player/player.gd` (start, tick and end the cover)
- Test: `tests/test_eat_cover.gd`

**Interfaces:**
- Consumes: `SlimeRig`, `PredationHold`, `Art.sprite`.
- Produces:
  - `PredationHold.progress() -> float` (0..1)
  - `EatCover` (a `Node2D`): `const PREY_MIN_SCALE := 0.2`, `const BODY_ALPHA := 0.8`, `begin(target: Node2D) -> void`, `tick(delta: float, progress: float) -> void`, `finish() -> void`, vars `rig: SlimeRig`, `prey_copy: Sprite2D`.

- [ ] **Step 1: Write the failing test**

```gdscript
# tests/test_eat_cover.gd
extends GutTest
## Eating covers the prey: the slime drapes over it, the prey shrinks inside, and nothing is left
## hidden afterwards.

func _prey() -> Node2D:
	var prey := Node2D.new()
	prey.position = Vector2(100, 50)
	prey.add_child(Art.sprite("bat_1", 6.0))
	add_child_autofree(prey)
	return prey

func test_progress_runs_from_zero_to_one() -> void:
	var hold := PredationHold.new()
	assert_eq(hold.progress(), 0.0)
	hold.start(Node2D.new(), 100)
	assert_eq(hold.progress(), 0.0)
	hold.update(0.5)
	assert_almost_eq(hold.progress(), 0.5, 0.001)
	hold.update(2.0)
	assert_eq(hold.progress(), 1.0)
	hold.cancel()
	assert_eq(hold.progress(), 0.0)

func test_the_cover_hides_the_prey_and_draws_a_shrinking_copy_inside_the_slime() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey)
	assert_false(prey.get_node("Sprite").visible)
	assert_eq(cover.rig.state(), "cover")
	assert_almost_eq(cover.rig.modulate.a, EatCover.BODY_ALPHA, 0.001)
	assert_eq(cover.prey_copy.texture, prey.get_node("Sprite").texture)
	cover.tick(0.016, 0.0)
	assert_almost_eq(cover.prey_copy.scale.x, 1.0, 0.001)
	cover.tick(0.016, 1.0)
	assert_almost_eq(cover.prey_copy.scale.x, EatCover.PREY_MIN_SCALE, 0.001)
	assert_lt(cover.prey_copy.z_index, cover.rig.z_index)

func test_the_cover_sits_on_the_prey_and_the_body_stays_put() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey)
	var bottom := prey.get_node("Sprite").position.y + prey.get_node("Sprite").texture.get_height() / 2.0
	assert_almost_eq(cover.global_position.x, prey.global_position.x, 0.001)
	assert_almost_eq(cover.global_position.y, prey.global_position.y + bottom, 0.001)

func test_finishing_or_cancelling_restores_the_prey() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child(cover)
	cover.begin(prey)
	cover.finish()
	assert_true(prey.get_node("Sprite").visible)
	await wait_process_frames(2)
	assert_false(is_instance_valid(cover))

func test_a_freed_prey_does_not_break_the_cover() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey)
	prey.free()
	cover.tick(0.016, 0.5)
	cover.finish()
	pass_test("no crash")

func test_the_player_covers_prey_while_eating_and_uncovers_on_cancel() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var player := Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(player)
	rules.start_run()
	var enemy := Enemy.new()
	var creatures := DefLoader.load_dir("res://data/creatures")
	var skills := {}
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d
	for c in creatures:
		if c.id == "toad":
			enemy.setup(c, skills)
	enemy.position = Vector2(20, 0)
	add_child_autofree(enemy)
	enemy.status.stun()
	player.begin_predate()
	assert_true(player.predation.active())
	assert_not_null(player._cover)
	assert_false(player._rig.visible)
	assert_false(enemy.get_node("Sprite").visible)
	player.cancel_predate()
	assert_null(player._cover)
	assert_true(player._rig.visible)
	assert_true(enemy.get_node("Sprite").visible)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_eat_cover`
Expected: FAIL with `Identifier "EatCover" not declared`.

- [ ] **Step 3: Implement it**

```gdscript
# scripts/rig/eat_cover.gd
class_name EatCover
extends Node2D
## Eating by covering. The slime's body does not move: this node sits on the prey, hides the
## prey's own sprite, draws a copy that shrinks as the eat bar fills, and lays the translucent,
## draped slime rig over it. Finishing or cancelling shows the prey's sprite again.

const PREY_MIN_SCALE := 0.2
const BODY_ALPHA := 0.8

var rig: SlimeRig
var prey_copy := Sprite2D.new()
var _target: Node2D
var _prey_sprite: Sprite2D
var _tex_height := 0.0

func begin(target: Node2D) -> void:
	_target = target
	top_level = true
	_prey_sprite = target.get_node_or_null("Sprite")
	var bottom := 0.0
	if _prey_sprite != null and _prey_sprite.texture != null:
		_tex_height = float(_prey_sprite.texture.get_height())
		bottom = _prey_sprite.position.y + _tex_height / 2.0
		prey_copy.texture = _prey_sprite.texture
		prey_copy.flip_h = _prey_sprite.flip_h
		_prey_sprite.visible = false
	global_position = target.global_position + Vector2(0.0, bottom)
	prey_copy.z_index = 0
	prey_copy.position = Vector2(0.0, -_tex_height / 2.0)
	add_child(prey_copy)
	rig = SlimeRig.new()
	rig.z_index = 1
	rig.modulate.a = BODY_ALPHA
	add_child(rig)
	rig.snap("cover")

func tick(delta: float, progress: float) -> void:
	var s := lerpf(1.0, PREY_MIN_SCALE, clampf(progress, 0.0, 1.0))
	prey_copy.scale = Vector2(s, s)
	prey_copy.position.y = -_tex_height * s / 2.0
	rig.advance(delta)

func finish() -> void:
	if is_instance_valid(_prey_sprite):
		_prey_sprite.visible = true
	queue_free()
```

`scripts/player/predation_hold.gd` — add:
```gdscript
## How far through the hold we are, 0 to 1.
func progress() -> float:
	if target == null or _required <= 0.0:
		return 0.0
	return clampf(_elapsed / _required, 0.0, 1.0)
```

`scripts/player/player.gd`: add `var _cover: EatCover`. In `begin_predate()`, after `predation.start(...)`:
```gdscript
	_start_cover(target)
```
In `process_predate(delta)`, before `if predation.update(delta):`:
```gdscript
	if _cover != null:
		_cover.tick(delta, predation.progress())
```
In `cancel_predate()`, after `predation.cancel()`: `	_end_cover()`. In `_complete_predation(t)`, after `predation.cancel()`: `	_end_cover()`. Add:
```gdscript
func _start_cover(target: Node2D) -> void:
	if _rig == null:
		return
	_cover = EatCover.new()
	get_parent().add_child(_cover)
	_cover.begin(target)
	_rig.visible = false

func _end_cover() -> void:
	if _cover != null and is_instance_valid(_cover):
		_cover.finish()
	_cover = null
	if _rig != null:
		_rig.visible = true
```
In `_complete_predation`, `_end_cover()` must run **before** `t.consume()` frees the prey, so put it as the first line (before `var c: CreatureDef = t.consume()`).

- [ ] **Step 4: Run it to verify it passes, then the full suite**

Run: import, then `tools/run_tests.sh test_eat_cover | tail -1` (expected `PASS: 6 tests`), then `tools/run_tests.sh | tail -1`.

- [ ] **Step 5: Commit**

```bash
git add scripts/rig/eat_cover.gd scripts/rig/*.uid scripts/player tests/test_eat_cover.gd tests/*.uid
git commit -m "feat: eating by covering: the slime drapes over the prey while it shrinks inside"
```

---

### Task 10: Real-game captures, clips, and the cost probe

**Files:**
- Create: `tools/rig/clip.gd`, `tools/rig/in_game.gd`, `tools/rig/perf.gd`, `tools/rig/make_gif.py`

**Interfaces:**
- Produces in `.tmp/rig-spike/`: `clip_*.png` (rig-only frames, scaled up) and `run.gif`, `spread.gif`, `cover.gif`; `game_*.png` (full frames from the real Cave); a printed frame-time for 30 rigs.

- [ ] **Step 1: Write the clip tool**

```gdscript
# tools/rig/clip.gd
extends SceneTree
## Captures the rig alone as numbered frames, at 20 fps, for the states in SEQUENCE. Needs a real
## renderer. Run:  env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/clip.gd

const OUT := "res://.tmp/rig-spike/"
const SEQUENCE := [["run", 1.0, "run"], ["spread", 1.2, "spread"], ["cover", 1.0, "cover"], ["wall", 1.0, "wall"]]
const FPS := 20.0

var rig: SlimeRig
var seq := 0
var frame := 0
var phase := 0
var _started := false

func _initialize() -> void:
	rig = SlimeRig.new()
	root.add_child(rig)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		rig.snap(SEQUENCE[0][0])
		return false
	var item: Array = SEQUENCE[seq]
	if phase == 0:
		rig.advance(1.0 / FPS)
		phase = 1
		return false
	var img := rig.viewport_image()
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("%sclip_%s_%02d.png" % [OUT, item[2], frame]))
	frame += 1
	phase = 0
	if frame >= int(float(item[1]) * FPS):
		frame = 0
		seq += 1
		if seq >= SEQUENCE.size():
			quit()
		else:
			rig.snap(SEQUENCE[seq][0])
	return false
```

```python
# tools/rig/make_gif.py
"""Turn clip_<name>_NN.png frames into <name>.gif (20 fps). Run from the project root:
  uv run --python 3.12 --with Pillow python tools/rig/make_gif.py
"""
import glob
import os
import re

from PIL import Image

DIR = ".tmp/rig-spike"

names = sorted({re.match(r"clip_(.+)_\d+\.png", os.path.basename(p)).group(1)
                for p in glob.glob(os.path.join(DIR, "clip_*_*.png"))})
for name in names:
    frames = [Image.open(p).convert("RGBA") for p in sorted(glob.glob(os.path.join(DIR, "clip_%s_*.png" % name)))]
    bg = Image.new("RGBA", frames[0].size, (18, 18, 32, 255))
    flat = [Image.alpha_composite(bg, f).convert("P", palette=Image.ADAPTIVE) for f in frames]
    flat[0].save(os.path.join(DIR, name + ".gif"), save_all=True, append_images=flat[1:], duration=50, loop=0)
    print("wrote", os.path.join(DIR, name + ".gif"), len(frames), "frames")
```

- [ ] **Step 2: Write the in-game shots and the cost probe**

```gdscript
# tools/rig/in_game.gd
extends SceneTree
## Full frames of the rigged slime in the real Cave: idle, running, jumping, wall cling, spread,
## and covering a stunned toad. Needs a real renderer. Run:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/in_game.gd

const OUT := "res://.tmp/rig-spike/"
var game
var frame := 0
var enemy: Enemy

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("%sgame_%s.png" % [OUT, n]))

func _process(_delta: float) -> bool:
	frame += 1
	var p: Player = game.player
	match frame:
		30:
			_shot("idle")
			Input.action_press("move_right")
		50:
			_shot("run")
			Input.action_release("move_right")
			Input.action_press("jump")
		56:
			Input.action_release("jump")
		62:
			_shot("jump")
		120:
			p.skillset.capabilities["wall_cling"] = 1
			p.global_position = Vector2(770, 1000)  # beside the wall-cling column in C1
			p.velocity = Vector2(0, 40)
			Input.action_press("move_right")
		135:
			_shot("wall")
			Input.action_release("move_right")
			p.global_position = Vector2(150, 1030)
			p.velocity = Vector2.ZERO
		180:
			Input.action_press("aim_down")
		200:
			_shot("spread")
			Input.action_release("aim_down")
			enemy = game._spawn("toad", Vector2(p.global_position.x + 30.0, p.global_position.y))
			game.world.room.add_child(enemy)
			enemy.global_position = Vector2(p.global_position.x + 30.0, p.global_position.y)
			enemy.status.stun()
		230:
			Input.action_press("predate")
		255:
			_shot("cover")
			Input.action_release("predate")
		270:
			quit()
	return false
```

```gdscript
# tools/rig/perf.gd
extends SceneTree
## The cost of 30 rigs on screen at once. Run windowed:
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/perf.gd

const COUNT := 30
var frame := 0
var start_us := 0

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in COUNT:
		var rig := SlimeRig.new()
		rig.position = Vector2(30 + (i % 10) * 60, 60 + (i / 10) * 100)
		root.add_child(rig)
		rig.snap("run" if i % 2 == 0 else "cover")

func _process(delta: float) -> bool:
	frame += 1
	for n in root.get_children():
		if n is SlimeRig:
			n.advance(delta)
	if frame == 30:
		start_us = Time.get_ticks_usec()
	if frame == 150:
		var ms := float(Time.get_ticks_usec() - start_us) / 1000.0 / 120.0
		print("30 rigs: %.2f ms per frame (%.0f fps)" % [ms, 1000.0 / ms])
		quit()
	return false
```

- [ ] **Step 3: Run all three (windowed, sandbox disabled), then build the GIFs**

```bash
gtimeout -k 5 90 env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/clip.gd 2>&1 | grep -E "ERROR|SCRIPT"
gtimeout -k 5 120 env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/in_game.gd 2>&1 | grep -E "ERROR|SCRIPT"
gtimeout -k 5 90 env HOME="$PWD/.tmp/gdhome" godot --path . -s res://tools/rig/perf.gd 2>&1 | grep -E "rigs|ERROR|SCRIPT"
```
Then (whole command): `uv run --python 3.12 --with Pillow python tools/rig/make_gif.py`
Expected: no SCRIPT ERROR lines; `30 rigs: <n> ms per frame (<n> fps)`; `wrote .tmp/rig-spike/<name>.gif` for run, spread, cover and wall.

- [ ] **Step 4: Read the results and fix real problems**

**Read** `.tmp/rig-spike/game_idle.png`, `game_run.png`, `game_jump.png`, `game_wall.png`,
`game_spread.png`, `game_cover.png`, and a few of the `clip_*` frames. Confirm: the slime is
visibly bigger than before and still crisp; the wall grip is on the wall side; spread is a puddle;
cover drapes over the toad and the toad shrinks inside. If the slime is stuck, blocked, or
clipped in the Cave, note where (this feeds the size decision). Fix genuine bugs with a failing
test first; tuning the look goes in `data/rigs/slime_anims.json`.

- [ ] **Step 5: Run the full suite and commit**

```bash
tools/run_tests.sh | tail -1
git add tools/rig tests data/rigs scripts
git commit -m "feat: rig clips, in-game captures and the cost probe"
```

---

### Task 11: The decision

This task is a conversation with Sean, not code. Do not start Sub-project 1's next steps or rig any
enemy before it is answered.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-28-slime-forms-and-animation-design.md` (record the outcome under 0.4)

- [ ] **Step 1: Assemble the review packet**

Copy these into `/Users/sean/sites/isekai-game/.tmp/rig-spike-shots/` (the main checkout's
ignored scratch, which outlives the worktree): `contact_sheet.png`, `game_*.png`, `run.gif`,
`spread.gif`, `cover.gif`, `wall.gif`. Note the printed cost line from Task 10.

- [ ] **Step 2: Show it, and say plainly what you saw**

Send `contact_sheet.png` and the GIFs to Sean (SendUserFile), and describe in a few lines, honestly:
does it stay pixel-crisp; where the deformation looks good or rubbery; how it feels next to the old
sprite at 1× and at 2×; the cost for 30 rigs; anything that broke in the Cave at the bigger size.
Do not oversell. Report failures as failures.

- [ ] **Step 3: Ask for the decision (AskUserQuestion)**

Ask three things: (1) **Adopt the rig, or fall back to per-frame art?** (spec 0.4). (2) **How big?**
The slime is 2× today's now; options: keep 2×, go back to 1×, or larger (and, if bigger, whether
the rest of the world's creatures and rooms should scale with it or the camera should zoom).
(3) **What to redo before moving on** (the look of specific animations).

- [ ] **Step 4: Record the outcome**

Write the answer into the spec under 0.4 (one short paragraph: date, pass or fail, chosen scale, what
was said). Commit:
```bash
git add docs
git commit -m "docs: record the rig spike outcome"
```
Then stop. The next plan (the rest of Sub-project 1, or the frame-path fallback) is written from
the spec after the answer, and goes through the review panel first if the spec changes.

---

## Self-Review Notes

- **Spec coverage (0.1–0.4, 1.1–1.3):**
  - Rig with a skinned soft body, bones, eyes and pods → Tasks 3–5.
  - Native-pixel render → Task 5.
  - Hurt shape and tackle attack shape following the skin → Task 7. The spec's collision layers
    and Area2D hits are deliberately **not** switched on (inert in the spike), and a later plan
    does that.
  - All the spec's animations → Tasks 2–3, plus `hurt` and `rope` from the state table.
  - Spread rules (1.2), minus "solid within 7 px" being a test-move rather than a shape query → Task 8.
  - Eating by covering (1.3) → Task 9.
  - The pass/fail gate (0.4) → Task 11.
- **Not in the spike:** the torch replacement, the frame-path pipeline, enemy rigs, damage-check
  changes, and forms. Sub-project 1's remaining parts follow the decision.
- **Rulings made in this plan:**
  1. The rig scale defaults to 2× (your "we can make things bigger"), as one constant, with the
     collision box scaled with it. Enemies and rooms are not scaled in the spike, and a bigger
     slime beside 16×12 enemies is one of the things you will judge.
  2. The Player keeps updating the old sprite (hidden) so the existing tests hold.
  3. Bone poses are CPU-mirrored for the hit shapes rather than read back from the GPU skin.
