# Per-Room Set Dressing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, inline; Sean's standing choice) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every Cave room is dressed by hand with props at different depths (roots, arches, pillars, crystals, mushrooms, waterfalls) that parallax on both axes, so tall rooms have real depth instead of one stretched backdrop.

**Architecture:** This is Hollow Knight's authoring model in 2D. A room lists `dressing` entries `{piece, pos, factor}`. `SetDressing` builds one sprite per entry behind the terrain and actors, and each frame places it with `camera + factor * (pos - camera)`: factor 1 is the world, 0 is glued to the screen, so a prop sits exactly at its authored position when the camera is centred on it and drifts with depth elsewhere, on both axes. Distance is sold by a per-depth haze tint and darkening. A piece library (`assets/dressing/<biome>/`) holds individually generated art, reused at several depths.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`), Python 3.12 + Pillow for `tools/art`, Codex `$imagegen` (one image per piece).

**Spec:** the exploration world spec `docs/superpowers/specs/2026-09-28-exploration-world-design.md` (rooms as data) and the terrain art spec `docs/superpowers/specs/2026-09-28-terrain-art-design.md` (the depth stack). Research behind it: Hollow Knight places layers on a real Z axis under a perspective camera, hand-composes each room, fogs distant layers and darkens near ones.

## Global Constraints

- Props draw behind terrain, decor and actors (z below 0) and never over the play plane. Foreground (factor above 1) is out of scope.
- Factor is in `[0.1, 0.9]`: 0.1 is far, 0.9 nearly the world.
- A prop's `pos` is local room pixels like `decor`. It appears at `pos` when the camera centre is on `pos`.
- Room data is generated: authoring happens in `tools/build_world.gd`, rooms are regenerated, never hand-edited.
- One image per piece, generated individually on magenta. Names match `^[a-z0-9_]+$`.
- Props ignore the game's 2D lights (the far layers' `UNLIT_MASK`), so crystals and fungus do not wash them out.
- Do not touch creatures, the player or `scripts/enemies/*`. Commit messages carry no attribution lines.

## Review Focus

1. A prop at factor 1 must behave exactly like a world object, and factor 0 exactly like a screen-glued one. Off-by-one in the follow formula shows as props sliding against the terrain.
2. A tall room must never have an empty screen: every screen-height band of a room two or more screens tall carries dressing.
3. A dressed room must cost little: a cap on props per room, and props far outside the view are not processed.
4. A room whose biome has no piece library, or an unknown piece name, must not crash the game: it draws no dressing and the validator names the mistake.
5. Rebuilding a room (they are rebuilt on every entry) must not leak the previous room's props.

---

### Task 1: Piece list and assembler

**Files:** Create `tools/art/dressing_cave_frames.json` (done, d36956d), `tools/art/assemble_pieces.py`, `tools/art/test_assemble_pieces.py`.

**Produces:** `assets/dressing/<biome>/<piece>.png` (keyed, cropped, scaled to the piece's width, crisp alpha) and `assets/dressing/<biome>/pieces.json`: `{"pieces": {name: {"size": [w, h], "anchor": "top"|"bottom"|"center"}}}`.

- [ ] Test first: a piece is scaled to its width keeping aspect, keyed, cropped; `pieces.json` records the final size and the anchor from the list; an unknown anchor or a missing source image is an error.
- [ ] Implement by reusing `assemble_frames.fit_frame`.

### Task 2: Generate, review, assemble the Cave pieces

- [ ] Generate all eight pieces in parallel (one process each): `uv run --python 3.12 python tools/art/generate_frames.py dressing_cave <piece>`.
- [ ] Contact sheet; regenerate weak pieces alone; assemble; import; commit sources and pieces.

### Task 3: `RoomDef.dressing`, `DressingLib`, `SetDressing`

**Files:** Modify `scripts/world/room_def.gd`, `scripts/world/world_validator.gd`, `scripts/world/room_builder.gd`. Create `scripts/world/dressing_lib.gd`, `scripts/world/set_dressing.gd`. Tests `tests/test_set_dressing.gd`.

**Interfaces — Produces:**
- `RoomDef.dressing: Array` of `{"piece": String, "pos": Vector2, "factor": float, optional "flip": bool}`.
- `DressingLib.has_biome(biome) -> bool`, `piece_names(biome) -> Array`, `texture(biome, piece) -> Texture2D` (null if unknown), `anchor(biome, piece) -> String`, `size(biome, piece) -> Vector2`.
- `SetDressing.prop_position(pos: Vector2, camera: Vector2, factor: float) -> Vector2` (static, `camera + factor * (pos - camera)`), `SetDressing.tint(factor: float, biome_haze: Color) -> Color`, `SetDressing.z_for(factor: float) -> int` (behind everything: `-25` to `-6`, nearer factors draw later), `SetDressing.build(room: Node2D, biome: String, dressing: Array, room_origin: Vector2) -> Node2D` (a node named `Dressing` under the room; one `DressingProp` child per valid entry), `MAX_PROPS := 40`.
- `WorldValidator` errors: unknown piece, factor outside `[0.1, 0.9]`, `pos` outside the room grown by 200 px, more than `MAX_PROPS` entries.

Tests (write first): the follow formula at factor 1 (equals `pos`, so it moves with the world), factor 0 (equals the camera), and 0.5 (halfway); a prop is exactly at `pos` when the camera is on it; the sprite is offset by its anchor (a `top` piece hangs from `pos`, a `bottom` piece stands on it, a `center` piece is centred); z is below 0 for every factor and increases with factor; tint gets hazier as factor drops; a room with an unknown piece or no biome library builds without props and without error; rebuilding a room leaves no old `Dressing` node; a `flip` prop is mirrored; validator cases above; props beyond `MAX_PROPS` are ignored by the builder too.

### Task 4: Author the Cave rooms

**Files:** Modify `tools/build_world.gd` (a `dressing` list per room), regenerate `data/rooms/C1-C6.tres`. Tests `tests/test_room_dressing.gd`.

- [ ] Author dressing for C1-C6: distant arches and pillars at low factors, roots and stalactites from the ceiling, mushroom groves and crystals on the far ground, waterfalls in the tall rooms, at varied depths, never crowding the play plane.
- [ ] Tests: every Cave room has dressing; every piece is known, every factor and position valid (the validator passes); every screen-height band of a room two or more screens tall has at least two props; no room exceeds `MAX_PROPS`; the world still validates.

### Task 5: Review, the gate and the merge

- [ ] Strip screenshots of the tall room C5 (top, middle, bottom) and a one-screen room, a piece contact sheet, playtest-checklist lines.
- [ ] Show Sean; regenerate or re-place what he dislikes. Final whole-branch review (opus subagent), one fix pass with a failing test first, merge (after `feat/enemy-art`), push, clean the worktree.
