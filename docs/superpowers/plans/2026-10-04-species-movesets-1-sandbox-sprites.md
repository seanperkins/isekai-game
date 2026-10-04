# Species Movesets, Part 1: Sandbox With Real Sprites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The movement sandbox shows the slime, a spider and a wolf as their real animated sprites (the biped stays a labeled placeholder), with a fourth profile for the spider and a fourth key to pick it.

**Architecture:** A spider profile joins the three from the movement model, with its numbers from the spec. `SpeciesLook` (pure statics) says which sheet and clips a species is drawn with and which clip fits the movement. The sandbox swaps its colour rect for a `Sprite2D` driven by the existing `SlimeAnimator` and `SpriteSheet`, falling back to the rect when a sheet is missing. No verbs yet: this plan is only about seeing the characters.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`).

**Spec:** `docs/superpowers/specs/2026-10-04-species-movesets-design.md` (build step 1). Read it with this plan.

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. Every new `class_name` script needs `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and its `.uid` file committed. A SCRIPT ERROR or Parse Error fails the whole run; so does a warning treated as an error (the project does that: type every `var` that a Variant would infer). Success prints `PASS: N tests`.
- Edits are limited to `scripts/movement/*`, `data/movement/*`, `tests/test_movement_*.gd` and `tests/test_species_look.gd`. Do not edit `scripts/player/`, `scripts/enemies/`, `scripts/world/room_lint.gd`, `scripts/ui/` or any art.
- Work in `.worktrees/species-movesets` on `feat/species-movesets` (continue its commits).
- Sprites: sheets face right (flip when facing left); frames are drawn at scale 1 on the 28x24 body box, feet at `BodyConfig.BOTTOM` below the body origin; the slime keeps the `SquashSpring` scale, the spider and wolf stay at scale 1.
- The spider profile: top 140, ground accel 0.03 s, stop 0.02 s, turn 0.02 s, air accel 0.6, air stop 0.1 s, no momentum keeping, jump 330 / gravity 900 / fall 1.0 (exactly the base jump), release `CUT` with factor 1.0 (a fixed hop, no variable height), coyote and buffer 0.1, no float, no rebound.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`.

## Review Focus

1. **A sheet that is not imported or missing.** Expect: the sandbox falls back to the colour rect with no error and `look()` says `"placeholder"` (Task 3).
2. **A clip name the data does not have.** Expect: every clip `SpeciesLook` can return exists in that species' clips (Task 2).
3. **Gear and idle boundaries.** The wolf at 149.9 and 150 px/s; a standing spider and slime (Task 2).
4. **Feet planted for every species, and a switch mid-run.** Expect: the sprite's bottom sits on the body's bottom for each sheet, and switching species mid-air or mid-run raises no error and starts a fresh animator (Task 3).
5. **The spider's hop is not variable.** Expect: a tap and a held jump rise the same (Task 1).

---

## File map

- `data/movement/spider.tres` the fourth profile; `scripts/movement/movement_profile.gd` gains the id.
- `scripts/movement/species_look.gd` which sheet, clips and clip a species uses.
- `scripts/movement/movement_sandbox.gd` draws sprites; `tests/test_species_look.gd` and the existing movement tests grow.

### Task 1: The spider profile

**Files:**
- Create: `data/movement/spider.tres`
- Modify: `scripts/movement/movement_profile.gd` (`IDS`), `tests/test_movement_profile.gd`, `tests/test_movement_envelope.gd`, `tests/test_movement_release.gd`, `tests/test_movement_ground.gd`

**Interfaces:**
- Produces: `MovementProfile.IDS == ["biped", "slime", "wolf", "spider"]` (the order keeps the sandbox keys 1 to 3 as they are; key 4 is the spider) and `MovementProfile.of("spider")` with the spider numbers above.

- [ ] **Step 1: Write the failing tests.**
  - `tests/test_movement_profile.gd`: the `IDS` assertion becomes `["biped", "slime", "wolf", "spider"]`; add to the first test: `var sp := MovementProfile.of("spider")`, `assert_eq([sp.top_speed, sp.ground_accel_time, sp.ground_stop_time, sp.ground_turn_time, sp.jump_velocity, sp.gravity, sp.fall_mult], [140.0, 0.03, 0.02, 0.02, 330.0, 900.0, 1.0])`, `assert_eq(sp.release_style, MovementProfile.ReleaseStyle.CUT)`, `assert_eq(sp.release_factor, 1.0)`.
  - `tests/test_movement_envelope.gd`: add `var spider: MovementProfile` loaded in `before_each` (`MovementProfile.of("spider")`) and add `spider` to the lists in `test_every_profile_keeps_the_base_rise`, `test_biped_and_slime_keep_the_standstill_gap` (rename to `..._biped_slime_and_spider_...`) and `test_the_jump_height_stat_still_scales_rise`; add `test_the_spider_is_the_base_held_jump`: every key of `MovementSim.flat_jump(spider)` is within 0.0001 of `MovementSim.flat_jump(MovementSim.base_profile())`.
  - `tests/test_movement_release.gd`: add `var spider`, loaded in `before_each`, and `test_the_spider_has_no_variable_jump`: `MovementSim.flat_jump(spider, 1.0, 0.0)["rise"]` equals `MovementSim.flat_jump(spider)["rise"]` within 0.01.
  - `tests/test_movement_ground.gd`: add `var spider`, loaded in `before_each`, and `test_the_spider_skitters`: from rest with `dir = 1` on the floor it is at 140 after 2 ticks (`assert_eq`), and from 140 with no input it is at 0 after 2 ticks.
- [ ] **Step 2: Run** `tools/run_tests.sh movement_`. Expected: FAIL (`MovementProfile.of("spider")` is null, so the new assertions error or fail).
- [ ] **Step 3: Implement.** Add `"spider"` to `IDS` (last); write `data/movement/spider.tres` in the shape of `slime.tres` with the spider numbers (`release_style = 0`, `release_factor = 1.0`, `apex_band = 0.0`, `rebound_rise = 0.0`, `air_keeps_momentum = false`). Run `godot --headless --import`.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git add data/movement scripts/movement tests` then `git commit -m "feat: spider movement profile"`.

### Task 2: SpeciesLook

**Files:**
- Create: `scripts/movement/species_look.gd`
- Test: `tests/test_species_look.gd`

**Interfaces:**
- Consumes: `SpriteSheet.load_set(name) -> SpriteSheet` (null when missing), `SlimeAnimator.load_clips(path) -> Dictionary`, `SlimeState.pick(...)`.
- Produces: `class_name SpeciesLook extends RefCounted` with `const LOOKS := {"slime": {"sheet": "slime", "clips": "res://data/slime_clips.json", "key": ""}, "spider": {"sheet": "spider", "clips": "res://data/enemy_clips.json", "key": "spider"}, "wolf": {"sheet": "gloom_wolf", "clips": "res://data/enemy_clips.json", "key": "gloom_wolf"}}`, `const GALLOP_SPEED := 150.0`, `const MOVING_SPEED := 8.0`, `static func has_look(species: String) -> bool`, `static func sheet_for(species: String) -> SpriteSheet` (null for no look or a missing sheet), `static func clips_for(species: String) -> Dictionary` (the species' clips; `{}` for no look), `static func clip_for(species: String, on_floor: bool, vy: float, vx: float, land_timer: float) -> String` (`""` for no look).

- [ ] **Step 1: Write the failing test** `tests/test_species_look.gd` (starts `extends GutTest`):

```gdscript
func test_which_species_have_a_look() -> void:
	assert_false(SpeciesLook.has_look("biped"))
	for id in ["slime", "spider", "wolf"]:
		assert_true(SpeciesLook.has_look(id), id)
	assert_eq(SpeciesLook.clip_for("biped", true, 0.0, 0.0, 0.0), "")
	assert_eq(SpeciesLook.clips_for("biped"), {})
	assert_null(SpeciesLook.sheet_for("biped"))

func test_the_slime_uses_its_state_picker() -> void:
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.0), "idle")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 100.0, 0.0), "run")
	assert_eq(SpeciesLook.clip_for("slime", false, -50.0, 0.0, 0.0), "rise")
	assert_eq(SpeciesLook.clip_for("slime", false, 50.0, 0.0, 0.0), "fall")
	assert_eq(SpeciesLook.clip_for("slime", true, 0.0, 0.0, 0.1), "land")

func test_the_spider_hangs_still_crawls_moving_and_drops_in_the_air() -> void:
	assert_eq(SpeciesLook.clip_for("spider", true, 0.0, 0.0, 0.0), "hang")
	assert_eq(SpeciesLook.clip_for("spider", true, 0.0, 100.0, 0.0), "crawl")
	assert_eq(SpeciesLook.clip_for("spider", false, -50.0, 0.0, 0.0), "drop")
	assert_eq(SpeciesLook.clip_for("spider", false, 50.0, 100.0, 0.0), "drop")

func test_the_wolf_has_two_gears_and_a_windup_in_the_air() -> void:
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 0.0, 0.0), "idle")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 100.0, 0.0), "walk")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 149.9, 0.0), "walk")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, 150.0, 0.0), "charge")
	assert_eq(SpeciesLook.clip_for("wolf", true, 0.0, -230.0, 0.0), "charge", "the sign of the speed does not matter")
	assert_eq(SpeciesLook.clip_for("wolf", false, -50.0, 230.0, 0.0), "windup")

func test_every_clip_it_names_exists_in_the_data() -> void:
	for id in ["slime", "spider", "wolf"]:
		var clips := SpeciesLook.clips_for(id)
		assert_false(clips.is_empty(), id)
		for on_floor in [true, false]:
			for vy in [-50.0, 0.0, 50.0]:
				for vx in [0.0, 100.0, -200.0]:
					for land in [0.0, 0.1]:
						var clip := SpeciesLook.clip_for(id, on_floor, vy, vx, land)
						assert_true(clips.has(clip), "%s %s" % [id, clip])
```

- [ ] **Step 2: Run** `tools/run_tests.sh species_look`. Expected: FAIL (class missing).
- [ ] **Step 3: Implement** `SpeciesLook`. The slime's clip is `SlimeState.pick(false, false, false, false, false, false, on_floor, vy, land_timer, vx)` (nothing but movement for now); the spider's is `"drop"` when airborne, else `"crawl"` when `absf(vx) > MOVING_SPEED`, else `"hang"`; the wolf's is `"windup"` when airborne, else `"charge"` at `absf(vx) >= GALLOP_SPEED`, `"walk"` above `MOVING_SPEED`, else `"idle"`. `clips_for` loads `SlimeAnimator.load_clips(path)` and takes `[key]` when the key is not empty. Run `godot --headless --import`.
- [ ] **Step 4: Run** `tools/run_tests.sh species_look`. Expected: `PASS`.
- [ ] **Step 5: Commit**: `git add scripts/movement tests/test_species_look.gd` (with the `.uid` files), then `git commit -m "feat: SpeciesLook says how each species is drawn"`.

### Task 3: The sandbox draws the characters

**Files:**
- Modify: `scripts/movement/movement_sandbox.gd`, `tests/test_movement_sandbox.gd`

**Interfaces:**
- Consumes: `SpeciesLook`, `SpriteSheet`, `SlimeAnimator` (`new(clips)`, `play(name)`, `advance(dt)`, `frame() -> String`), `SquashSpring`, `BodyConfig.BOTTOM`.
- Produces: `MovementSandbox.look() -> String` (the species id while its sprite shows, `"placeholder"` while the colour rect shows) and `MovementSandbox.clip() -> String` (the clip playing, `""` for the placeholder). Key `4` picks the spider (the existing key handler already maps `KEY_1..KEY_3` to `IDS[n]`; extend it to `KEY_4`).

- [ ] **Step 1: Write the failing tests** in `tests/test_movement_sandbox.gd`:

```gdscript
func _has_art(id: String) -> bool:
	return SpeciesLook.has_look(id) and SpeciesLook.sheet_for(id) != null

func test_each_species_with_art_shows_its_sprite_and_the_biped_a_placeholder() -> void:
	for id in ["slime", "spider", "wolf"]:
		sb.set_profile(id)
		assert_eq(sb.look(), id if _has_art(id) else "placeholder", id)
	sb.set_profile("biped")
	assert_eq(sb.look(), "placeholder")
	assert_eq(sb.clip(), "")

func test_the_clip_follows_the_movement() -> void:
	if not _has_art("wolf"):
		pending("the wolf sheet is not imported")
		return
	sb.set_profile("wolf")
	await _frames(3)
	assert_eq(sb.clip(), "idle")
	sb.scripted.dir = 1.0
	await _frames(40)
	assert_eq(sb.clip(), "charge")
	sb.scripted.jump_pressed = true
	sb.scripted.jump_held = true
	await _frames(6)
	assert_eq(sb.clip(), "windup")

func test_the_feet_stay_on_the_floor_for_every_sheet_and_a_switch_mid_run_is_clean() -> void:
	sb.scripted.dir = 1.0
	for id in ["slime", "spider", "wolf", "biped", "spider"]:
		sb.set_profile(id)  # switching while running
		await _frames(30)
		sb.scripted.dir = 0.0
		await _frames(30)
		if sb.look() != "placeholder":
			var sprite := sb.get_node("Sprite") as Sprite2D
			var half := sprite.texture.get_size().y * sprite.scale.y / 2.0
			assert_almost_eq(sprite.global_position.y + half, sb.body.global_position.y + BodyConfig.BOTTOM, 1.0, id)
		sb.scripted.dir = 1.0

func test_key_four_picks_the_spider() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_4
	ev.pressed = true
	sb._unhandled_key_input(ev)
	assert_eq(sb.profile.id, "spider")
```

- [ ] **Step 2: Run** `tools/run_tests.sh movement_sandbox`. Expected: FAIL (`look` and `clip` are not defined).
- [ ] **Step 3: Implement** in the sandbox. A `Sprite2D` child named `"Sprite"` (centered, scale 1, added after the colour rect so it draws over it). `_set_look(id)`, called at the end of `_ready` and from `set_profile` once the nodes exist: `_sheet = SpeciesLook.sheet_for(id)`; when it is not null, `_animator = SlimeAnimator.new(SpeciesLook.clips_for(id))` started on `SpeciesLook.clip_for(id, true, 0.0, 0.0, 0.0)` (a fresh animator on every switch), the sprite shows and the rect hides; otherwise the sprite hides, the rect shows and `_animator` is null. Each physics frame, after the move: track `_facing` from the sign of `state.velocity.x` when `absf(state.velocity.x) > 1.0`; `_land_timer` is set to 0.12 on a landing (`not was_on_floor and body.is_on_floor()`) and counts down by `delta`; with a sheet, the clip is `SpeciesLook.clip_for(profile.id, body.is_on_floor(), state.velocity.y, state.velocity.x, _land_timer)`, played and advanced, `sprite.texture = _sheet.frame_texture(_animator.frame())`, `sprite.scale` is `_spring.sprite_scale()` for the slime and `Vector2.ONE` otherwise, `sprite.flip_h = _facing < 0`, and `sprite.position = body.position + Vector2(0.0, BodyConfig.BOTTOM - _sheet.frame_size(frame).y * sprite.scale.y / 2.0)`. The HUD adds `4 spider` to its key line and `(placeholder, no art yet)` after the profile id while the rect shows. Extend the key match to `KEY_1, KEY_2, KEY_3, KEY_4`.
- [ ] **Step 4: Run** `tools/run_tests.sh movement_sandbox`, then the whole suite with `TEST_TIMEOUT=900 tools/run_tests.sh`. Expected: `PASS` for both. Then take screenshots (`godot --path . -s <a throwaway script under .tmp/>` with a real renderer: the slime mid-jump, the spider crawling, the wolf galloping) and look at them: report what each looks like, and hand the feel to Sean.
- [ ] **Step 5: Commit**: `git commit -m "feat: the sandbox draws the slime, spider and wolf with their real sprites"`.
