# Enemy Art, Kill-Type Deaths and Shape Hits Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, inline; Sean's standing choice) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every creature is drawn frame by frame (individually generated, assembled into sheets), dies in a way that matches the blow that killed it, and hits are decided by the traced shapes instead of centre distance.

**Architecture:** (Enemy AI is not refactored into a state machine in this pass: its `_charge`, `_swoop`, spit windup and `EnemyStatus` stay; `EnemyState.pick` derives one state name from them, as `SlimeState.pick` does for the slime.) The frame pipeline from Plan 2 is reused unchanged for four more sets (`bat`, `toad`, `lizard`, `spider`), each with its own reference sprite. A `DYING` enemy status plus a `DeathFx` node play a procedural death (tumble, melt, cut) on the creature's own sprite and end in the drawn `downed` frame, which starts the 5 s eat window. `EnemyState` maps creature state to frame names and falls back to the old sprites when a sheet is missing. Contact damage and spit globs test the traced hurt polygons.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`), Python 3.12 + Pillow for `tools/art`, Codex `$imagegen` for frames.

**Spec:** `docs/superpowers/specs/2026-09-28-slime-forms-and-animation-design.md` sections 0.1 (hit model), 2.1 (sprites), 2.2 (death matches the blow). Plan 2 (`2026-09-28-slime-frame-art.md`) built the pipeline and the slime.

## Global Constraints

- Frames: one Codex image per frame, never a whole sheet. Names match `^[a-z0-9_]+$`.
- `receive_hit(raw, damage_type, from = Vector2.INF, cause = "")` on `Enemy`, `Player`, `ShortcutSwitch`. `receive_tackle(atk, from_behind, from = Vector2.INF)` on `Enemy` and `ShortcutSwitch`.
- Causes built: `tackle`, `poison`, `blade`, `other`. `blast` and `shock` stay reserved.
- `EnemyStatus` gains a fifth state `DYING`. `update()` skips it. It is not predatable, ignores `receive_hit`, `receive_tackle`, `receive_thread`, has no AI, contact damage or spit. `downed` fires on entering `DYING`. The 5 s eat window starts when the effect ends (`status.down()`).
- Only the tackle death moves the body: at most 24 px, settled within 28 px of where the tackler stood at the kill, never off a ledge. Other causes leave the body where it is.
- Every death ends in the creature's drawn `downed` frame.
- Movement stays one simple box (`Enemy.BODY_SIZE` 16x12); shapes decide hits only.
- The tackle's `TACKLE_RANGE` selection and the slime's shapes stay as built in Plan 2.
- Do not touch `data/rooms`, `scripts/world/*` (except `shortcut_switch.gd`'s two signatures), `scripts/game.gd`.
- Commit messages carry no attribution lines.

## Review Focus

1. A creature killed while a death effect from another blow could still land (two hits in one frame, a tackle then a blade): the second is ignored, `downed` fires once, XP is paid once.
2. A creature freed (room change) mid-effect: no orphaned halves, tweens or hidden sprites remain.
3. A tackle kill next to a ledge or wall: the body never leaves the ground or ends inside a wall, and stays within eat range.
4. The `downed` signal reaching `game.gd` at the start of `DYING` while the enemy is still not edible: pressing eat during the effect does nothing.
5. A missing or partial sheet for one creature: the game still draws that creature with its old sprites.

---

### Task 1: Frame lists and the resumable generator — DONE (e499eec)

`tools/art/{bat,toad,lizard,spider}_frames.json` (48 frames: bat 10, toad 11, lizard 16, spider 10, each ending in a `downed` pose), `generate_frames.py` resumes, retries a failed frame once, deletes stale output first, takes `canonical` from the set's JSON.

### Task 2: Generate, review and assemble the four sheets

**Files:** `art_source/frames/<set>/*.png`, `assets/sheets/<set>.{png,json}`.

- [ ] Generate all four sets in parallel (one process per set, frames within a set in order): `uv run --python 3.12 python tools/art/generate_frames.py <set>` (unsandboxed, background).
- [ ] Build a raw contact sheet per set; regenerate bad frames alone (`generate_frames.py <set> <frame>` with an explicit name regenerates).
- [ ] `uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py <set>` for each; import; commit sources + sheets.
- [ ] Add `tests/test_enemy_sheets.gd`: each sheet loads, has every frame listed in its JSON at the listed width, every frame's hurt shape has its lowest point on 0, only `charge_*` and `dive` have attack shapes.

### Task 3: `DYING`, `from` and `cause` (TDD)

**Files:** Modify `scripts/enemies/enemy_status.gd`, `scripts/enemies/enemy.gd`, `scripts/player/player.gd` (`do_tackle`, `receive_hit`), `scripts/world/shortcut_switch.gd`, `scripts/abilities/water_blade.gd`, `scripts/abilities/poison_breath.gd`. Test: `tests/test_death_cause.gd`.

**Interfaces — Produces:** `EnemyStatus.DYING := 4`, `EnemyStatus.die()`; `Enemy._cause: String`, `Enemy._killed_from: Vector2`, `Enemy.cause_for(damage_type: String) -> String` (static: `poison` → `"poison"`, else `"other"`).

Tests (write first): status `update()` leaves `DYING` alone for any delta; `DYING` is not `predatable()`; `stun()` does nothing in `DYING`; `down()` moves `DYING` to `DOWNED`. A lethal `receive_hit` puts the enemy in `DYING`, emits `downed` exactly once, and a second lethal hit emits nothing and pays nothing; `receive_hit`/`receive_tackle`/`receive_thread` are ignored while `DYING`; a lethal tackle returns true; `can_be_predated()` is false during `DYING`; `is_touching` contact damage does not fire in `DYING`. Cause: a hit with no cause gets `cause_for(damage_type)`; an explicit cause wins; the cause is stored before `take_hit` (the test reads `_cause` inside a `downed` handler). All three implementors accept the new arguments (`ShortcutSwitch.receive_tackle` with three args opens the shortcut instead of erroring). Water Blade passes `("blade")` and the actor position; Poison Breath passes `("poison")` and the actor position.

Implementation: `EnemyStatus.die()` sets `state = DYING` unless `GONE`; `update()` returns early for `DYING`. `Enemy.receive_hit` ignores `DOWNED`, `GONE`, `DYING`, stores `_killed_from = from` and `_cause`. `_on_died` calls `status.die()` (predatable creatures) then `downed.emit(def)`; non-predatable creatures still `consume()`. `receive_tackle` returns true for `DYING` or `DOWNED` after the hit and passes `"tackle"` and `from`. `do_tackle` passes `global_position` as the third argument.

### Task 4: `DeathFx` (TDD)

**Files:** Create `scripts/enemies/death_fx.gd`, `scripts/enemies/blade_cut.gdshader`. Modify `scripts/enemies/enemy.gd` (start the effect from `_on_died`, let the effect own the body while `DYING`, `down()` on `finished`). Test: `tests/test_death_fx.gd`.

**Interfaces — Produces:** `DeathFx` (`Node2D`), `signal finished`, `begin(enemy: Enemy, cause: String, from: Vector2)`, consts `TACKLE_SECONDS := 0.6`, `POISON_SECONDS := 1.0`, `BLADE_SECONDS := 0.6`, `TACKLE_MAX_TRAVEL := 24.0`, `SETTLE_RANGE := 28.0`, `static duration(cause) -> float`.

Behaviour: `tackle` hops the body away from `from`, spins the sprite to lie on its back, stops at 24 px travel or at a ledge (no ground under the leading foot) or a wall; `poison` tints the sprite green and squashes it toward the floor over 1 s; `blade` hides the sprite and shows two copies clipped by `blade_cut.gdshader` along the blade's direction, sliding apart and falling; `other` waits a beat. Every effect emits `finished`, restores the sprite (rotation, scale, modulate, visibility) and the enemy calls `status.down()` and shows its downed frame.

Tests: each cause ends with the enemy `DOWNED`, the sprite restored (scale 1, rotation 0, modulate white, visible), and no `DeathFx` child left; the eat window (5 s) starts at `finished`, not at death (`status` timer checked); the enemy is not predatable until `finished`; tackle: travel ≤ 24 px and final distance to the recorded tackler position ≤ 28 px on flat ground; a tackle at a ledge stays on the ledge; blade: two half sprites exist mid-effect, their centres separate along the blade normal; freeing the enemy mid-effect leaves nothing behind.

### Task 5: `EnemyState` and the animator — sheet frames with a fallback (TDD)

**Files:** Create `scripts/enemies/enemy_state.gd` (a pure static picker, like `SlimeState`), `data/enemy_clips.json`. Modify `scripts/enemies/enemy.gd` (`_update_visual`, `_build_body`). Test: `tests/test_enemy_state.gd`.

**Interfaces — Produces:** `EnemyState.pick(creature: String, status: int, charge: String, swoop: String, spit_windup: bool, spit_recent: bool, on_ceiling: bool, moving: bool) -> String`, then a clip name → frame via the same `SlimeAnimator` clip player (reuse it; clips come from `data/enemy_clips.json`, keyed `<creature>.<state>`). `Enemy` keeps `frame_name()` returning the OLD sprite name for the fallback path and gains `_sheet: SpriteSheet`, `_animator: SlimeAnimator`, `_shapes: SlimeShapes`, `use_sheet := true`.

States: bat `fly`, `hover`, `dive`, `stunned`, `hurt`, `downed`; toad `idle`, `walk`, `puff`, `spit`, `stunned`, `hurt`, `downed`; lizard `idle`, `walk`, `windup`, `charge`, `rest`, `stunned`, `hurt`, `downed`; spider `hang`, `drop`, `crawl`, `stunned`, `hurt`, `downed`. `hurt` shows for 0.25 s after a non-lethal hit. `DYING` shows the frame the effect is using (the effect owns the sprite).

Tests: the state table for each creature and each behaviour state; every clip references frames that exist on that creature's sheet; an enemy built with `use_sheet = false` (or with no sheet) draws the old sprite; with the sheet, the sprite stands on the floor line and mirrors with `facing`; `downed` shows the drawn `downed` frame and never `flip_v`.

### Task 6: Shape hits (TDD)

**Files:** Create `scripts/actors/shape_hit.gd`. Modify `scripts/enemies/enemy.gd` (`is_touching`), `scripts/enemies/spit_blob.gd`, `scripts/player/player.gd` (`hurt_polygon()`), `tests/test_enemy_contact.gd`, new `tests/test_shape_hit.gd`.

**Interfaces — Produces:** `ShapeHit.overlap(a: PackedVector2Array, at_a: Vector2, b: PackedVector2Array, at_b: Vector2, margin: float = 0.0) -> bool` (global positions of the two shape origins, `margin` grows `a`), `ShapeHit.mirrored(points, left)`; `Player.hurt_polygon() -> PackedVector2Array` (global points, the current frame's traced hurt shape, or the body box when there is no sheet); `Enemy.hurt_polygon()` likewise.

Behaviour: an enemy in contact = its hurt polygon grown by `CONTACT_MARGIN` overlaps the player's hurt polygon (fall back to the box test when either side has no shape); a spit glob hits when its centre is within `HIT_RADIUS` of the player's hurt polygon. Spread: the polygon is flat, so an attack whose polygon passes above it misses; document per attack in `docs/playtest-checklist.md`.

Tests: touching but not overlapping polygons register with the margin, apart ones do not; mirroring works; a stub player with no shape still uses the old distance test; the existing contact tests still pass; a lizard walking over a spread slime does or does not hit as the geometry says (asserted, not assumed).

### Task 7: Review packet, the gate and the merge

- [ ] Contact sheets per creature with traced shapes; GIFs of each creature's main clips; in-game shots of each death cause (`tools/enemy_in_game.gd`), the eat after each death, and a spread slime under each attack.
- [ ] Append the playtest-checklist lines. Show Sean; regenerate disliked frames alone.
- [ ] Final whole-branch review (opus subagent), one fix pass with a failing test first, merge to main, push, message the terrain session, clean the worktree.
