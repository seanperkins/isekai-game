# Fungal Grotto Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, inline; Sean's standing choice) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Grotto: four core rooms (G1–G4) below the Cave's Drop Shaft with a two-way climb back, three new creatures (moth, crab, snake) drawn and animated like the Cave's, two essences and two skills, G1's rebirth pool with a real kit, the thin `ReincarnationMenu`, and pacing that lands the first evolution in G4; then, as a droppable slice, the rare Pale Moth and its wall-cling room G5.

**Architecture:** New creatures are data plus branches in the existing `Enemy` dispatch, keyed on two data flags (`armored_charger`, `drifter`) and `def.id`; no framework. Sheets come from the individually generated frame pipeline. Rooms are authored in `tools/build_world.gd` with a `Prefabs.ledge_chain` helper so every floor hole has a tested climb back. Hardened Shell's knockback rides a new `knockback_taken` modifier target read by `SkillEffects.knockback_factor`. The menu is a `CanvasLayer` driven by `Run.choice_needed`.

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`), the Codex `$imagegen` frame pipeline (`tools/art/*`, `uv run --python 3.12`).

**Spec:** `docs/superpowers/specs/2026-09-29-fungal-grotto-design.md` (revised through three debate rounds and two verification passes). Read it before Task 1; it is the authority for every number below.

## Global Constraints

- Ids: `spore_moth`, `mushroom_crab`, `vine_snake`, `pale_moth` (slice); essences `spore`, `shell`; skills `spore_cloud`, `hardened_shell`; pool `G1` (area `grotto`); rooms `G1`..`G5`.
- Creature numbers (HP/ATK/DEF/SPD/XP): moth 3/1/0/90/2 (spore 1, flight 1); crab 8/2/2/70/4 (shell 2, earth 1); snake 5/3/0/150/3 (poison 1, thread 1); pale moth 6/1/0/110/8 (spore 3, flight 2). First-time value per spawn is twice the XP.
- `def.id` stays the single key for sheets, clips, `frame_name`, `EnemyState.pick`, XP, essences, Appraisal and `Sources`; behaviour is chosen by `armored_charger` (lizard, crab), `drifter` (moth, pale moth) and, for the snake only, its id.
- A hole splits the upper floor in two; the climb chain's top ledge stands at local y ≤ 15 flush with the span's WEST edge, every ledge above local y 105 takes off from under the span, and only the west piece connects onward.
- Pacing (computed from room data, summing spawn `xp` directly, ungated semantics of `_reach(true)`): Cave ungated (108) + G1..G4 ≥ 270; Cave ungated + G1..G3 < 270; the Cave alone (all rooms) < 270. G5 never counts.
- Puff: group `hazards`, 2 s, radius 20, one hit per puff. Spore Cloud: group `player_clouds`, enemies only, 2 s. Never one system for both.
- `knockback_taken` values are absolute per level `[-8, -16, ..., -64]`; the factor is `maxf(0.36, 1.0 + sum / 100.0)`.
- Every emitted world event has an audio cue (`data/audio/cues.json`, `test_audio_boundary`).
- Commit messages carry no attribution lines. Glow Pools stay rest-only. Screenshots are real (windowed), never inferred.

## Review Focus

1. A chain whose second hop bonks the lower room's ceiling band: the directed test's headroom term must fail it (Task 6).
2. A creature with no `EnemyState.pick` arm silently plays `idle`: the per-creature mapping test (Task 2).
3. A stunned moth or snake falling with the ceiling flag still set, and a corpse that floats and cannot be eaten (Task 3).
4. A player with no Hardened Shell taking zero knockback because a missing key reads 0, not 100 (Task 4).
5. A typo'd spawn id silently removing a creature and its XP: `WorldValidator` checks (Task 2) and the pacing test (Task 6).

Each line has its test in the named task.

---

### Task 1: Data and registration

**Files:** Modify `scripts/core/essences.gd`, `scripts/core/sources.gd`, `scripts/skills/creature_def.gd`, `scripts/core/skill_effects.gd`, `scripts/skills/def_validator.gd`, `tools/build_content.gd`; regenerate `data/skills/*.tres`, `data/creatures/*.tres`; create `assets/sprites/icon_spore_cloud.png`, `assets/sprites/icon_hardened_shell.png`, `tools/art/make_icons.py`; add both icons to `tools/art/manifest.json`. Modify tests `test_constants.gd`, `test_content.gd`, `test_skill_caps.gd`. Create `tests/test_grotto_data.gd`.

**Interfaces — Produces:** `Essences.SPORE`, `Essences.SHELL` (in `ALL`); `Sources.SPORE_MOTH`, `MUSHROOM_CRAB`, `VINE_SNAKE` (in `ALL`; `PALE_MOTH` joins in Task 8); `CreatureDef.armored_charger: bool`, `CreatureDef.drifter: bool`; `SkillEffects.KNOCKBACK_TAKEN := "knockback_taken"`, `SkillEffects.knockback_factor(pairs: Array) -> float`; skills `spore_cloud`, `hardened_shell`; creature defs for the three ordinary creatures; lizard gets `armored_charger = true`.

- [ ] **Step 1: Write the failing test** `tests/test_grotto_data.gd`:

```gdscript
extends GutTest
## The Grotto's data: essences, sources, creature numbers, the two skills and the knockback route.

var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func test_new_essences_and_sources_are_registered() -> void:
	assert_true(Essences.ALL.has("spore"))
	assert_true(Essences.ALL.has("shell"))
	for id in ["spore_moth", "mushroom_crab", "vine_snake"]:
		assert_true(Sources.ALL.has(id), id)
		assert_true(creatures.has(id), id)

func test_the_creatures_have_the_approved_numbers() -> void:
	var want := {"spore_moth": [3, 1, 0, 90, 2, {"spore": 1, "flight": 1}],
		"mushroom_crab": [8, 2, 2, 70, 4, {"shell": 2, "earth": 1}],
		"vine_snake": [5, 3, 0, 150, 3, {"poison": 1, "thread": 1}]}
	for id in want:
		var c: CreatureDef = creatures[id]
		var w: Array = want[id]
		assert_eq([c.stats["max_hp"], c.stats["atk"], c.stats["def"], c.stats["spd"], c.xp, c.essences], w, id)

func test_only_the_lizard_and_crab_are_armored_chargers_and_only_moths_drift() -> void:
	for id in creatures:
		var c: CreatureDef = creatures[id]
		assert_eq(c.armored_charger, id == "lizard" or id == "mushroom_crab", id)
		assert_eq(c.drifter, id == "spore_moth", id)

func test_the_two_skills_match_the_spec() -> void:
	var sc: SkillDef = skills["spore_cloud"]
	assert_eq([sc.source, sc.max_level, sc.level_curve, sc.mp_cost], ["essence", 8, 8, 4])
	assert_eq(sc.unlock[0]["tags"], {"essence": "spore"})
	assert_eq(sc.unlock[0]["n"], 4)
	var hs: SkillDef = skills["hardened_shell"]
	assert_eq([hs.source, hs.max_level, hs.level_curve], ["essence", 8, 10])
	assert_eq(hs.unlock[0]["tags"], {"essence": "shell"})
	assert_eq(hs.effects[0]["stat"], "knockback_taken")
	assert_eq(hs.effects[0]["values"], [-8, -16, -24, -32, -40, -48, -56, -64])

func test_knockback_factor_is_one_with_no_skill_and_floors_at_036() -> void:
	var hs: SkillDef = skills["hardened_shell"]
	assert_eq(SkillEffects.knockback_factor([]), 1.0, "no skill: full knockback, not the missing-key zero")
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 1]]), 0.92, 0.0001)
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 4]]), 0.68, 0.0001)
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 8]]), 0.36, 0.0001)
	assert_almost_eq(SkillEffects.knockback_factor([[hs, 8], [hs, 8]]), 0.36, 0.0001, "the floor guards a second source")

func test_the_content_validates_and_both_skills_have_icons() -> void:
	var loaded := DefLoader.load_content("res://data/skills", "res://data/creatures")
	assert_eq(loaded["errors"].size(), 0, str(loaded["errors"]))
	assert_not_null(Art.texture("icon_spore_cloud"))
	assert_not_null(Art.texture("icon_hardened_shell"))
```

- [ ] **Step 2: Run it** (`tools/run_tests.sh test_grotto_data`). Expected: FAIL (engine/parse errors: `armored_charger` unknown, no creature defs).
- [ ] **Step 3: Implement.**
  - `essences.gd`: `const SPORE := "spore"`, `const SHELL := "shell"`, append to `ALL`. `sources.gd`: `SPORE_MOTH := "spore_moth"`, `MUSHROOM_CRAB := "mushroom_crab"`, `VINE_SNAKE := "vine_snake"`, append to `ALL`.
  - `creature_def.gd`: `@export var armored_charger: bool = false` and `@export var drifter: bool = false` (doc: "walks and charges with an armored front, stunned only from behind" / "hovers in a slow loop; no gravity while active or stunned").
  - `skill_effects.gd`: `const KNOCKBACK_TAKEN := "knockback_taken"` and
    ```gdscript
    ## Scales the knockback a hit gives the player: 1.0 with no skill, down to 0.36. pairs = [[SkillDef, level], ...].
    static func knockback_factor(pairs: Array) -> float:
    	var sum := 0
    	for pair in pairs:
    		var d: SkillDef = pair[0]
    		for e in d.effects:
    			if e.get("stat", "") == KNOCKBACK_TAKEN and e.get("kind", "") == "modifier":
    				sum += int(value_at(e, pair[1]))
    	return maxf(0.36, 1.0 + float(sum) / 100.0)
    ```
  - `def_validator.gd` (modifier whitelist, currently `stat != DAMAGE_TAKEN and not StatKeys.ALL.has(stat)`): also allow `SkillEffects.KNOCKBACK_TAKEN`.
  - `tools/build_content.gd`: lizard gets `"armored_charger": true`. Add skills after `regeneration`:
    ```gdscript
    		_s({"id": "spore_cloud", "display_name": "Spore Cloud", "source": "essence", "hidden": false,
    			"description": "Release a lingering cloud of spores that slows and poisons.", "hint": "Something spongy stirs within.",
    			"announce": "Analysis complete. Acquired [Spore Cloud].",
    			"unlock": [_c("absorbed", 4, {"essence": "spore"})],
    			"levels_on": _on("skill_used", {"id": "spore_cloud"}), "level_curve": 8, "max_level": 8,
    			"effects": [_active("spore_cloud", [24, 28, 32, 36, 40, 44, 48, 52])], "mp_cost": 4}),
    		_s({"id": "hardened_shell", "display_name": "Hardened Shell", "source": "essence", "hidden": false,
    			"description": "Take less knockback.", "hint": "Your skin wants to harden, and your footing with it.",
    			"announce": "Analysis complete. Acquired [Hardened Shell].",
    			"unlock": [_c("absorbed", 4, {"essence": "shell"})],
    			"levels_on": _on("damaged", {"damage_type": "physical"}), "level_curve": 10, "max_level": 8,
    			"effects": [_mod(SkillEffects.KNOCKBACK_TAKEN, [-8, -16, -24, -32, -40, -48, -56, -64])]}),
    ```
    (Spore Cloud's active value is its radius in px; its duration is `2.0 + 0.25 * (level - 1)` s, set in Task 4.) And creatures after `spider`:
    ```gdscript
    		_cr({"id": "spore_moth", "display_name": "Spore Moth", "stats": {"max_hp": 3, "atk": 1, "def": 0, "spd": 90},
    			"essences": {"spore": 1, "flight": 1}, "skills": [], "drifter": true,
    			"eat_bonus": {"stat": "max_mp", "amount": 1, "per": 2}, "xp": 2}),
    		_cr({"id": "mushroom_crab", "display_name": "Mushroom Crab", "stats": {"max_hp": 8, "atk": 2, "def": 2, "spd": 70},
    			"essences": {"shell": 2, "earth": 1}, "skills": [], "armored_charger": true,
    			"eat_bonus": {"stat": "def", "amount": 1, "per": 3}, "xp": 4}),
    		_cr({"id": "vine_snake", "display_name": "Vine Snake", "stats": {"max_hp": 5, "atk": 3, "def": 0, "spd": 150},
    			"essences": {"poison": 1, "thread": 1}, "skills": [{"id": "ceiling_walk", "level": 1}],
    			"eat_bonus": {"stat": "atk", "amount": 1, "per": 3}, "xp": 3}),
    ```
  - Icons: `tools/art/make_icons.py` runs `codex exec --skip-git-repo-check -s workspace-write -C <dir> -o <dir>/.last.txt -` with a `$imagegen` prompt per icon (magenta key, a 32×32-readable pictogram in the existing icon style: study `assets/sprites/icon_body_armor.png` first), keys the magenta out with `slice_sheets.keyed`, downscales with BOX to 32×32 and saves `assets/sprites/icon_<id>.png`. Spore Cloud: a puffball of yellow-green spores; Hardened Shell: a spotted mushroom-cap shield. Run it unsandboxed (`uv run --python 3.12 --with Pillow python tools/art/make_icons.py`), look at both PNGs, regenerate one alone if unclear. Add both to `tools/art/manifest.json` if the manifest lists the other icons (check how `icon_body_armor` is recorded; if icons are not listed there, skip).
  - Regenerate: `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd`, then `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless --import >/dev/null 2>&1`.
  - Rescope: `test_constants.gd` (`Sources.ALL` and `Essences.ALL` lists), `test_content.gd` (22 skills → 24, 6 creatures → 9, and its "every essence skill is supplied" check must count Grotto sources: for now count the new creatures' essences directly from `data/creatures` so it passes before rooms exist; Task 6 re-checks it against rooms), `test_skill_caps.gd` (`TABLE` gains `"spore_cloud": [8, 8], "hardened_shell": [8, 10]`; the descending-values rule allows `knockback_taken`: `or e.get("stat", "") == "knockback_taken"`).
- [ ] **Step 4: Run** `tools/run_tests.sh test_grotto_data` → PASS; then the full suite `tools/run_tests.sh` → all green (read the tail).
- [ ] **Step 5: Commit** `git add -A scripts tools data assets tests && git commit -m "feat: spore and shell essences, three Grotto creature defs, Spore Cloud and Hardened Shell, the knockback factor"`.

---

### Task 2: `Enemy` generalization, `EnemyState` arms, `slow_for`, validator checks

**Files:** Modify `scripts/enemies/enemy.gd`, `scripts/enemies/enemy_state.gd`, `scripts/world/world_validator.gd`, `scripts/game.gd` (pass creature ids), `data/enemy_clips.json`. Tests: create `tests/test_grotto_enemy_flags.gd`; extend `tests/test_enemy_state.gd`, `tests/test_world_validator.gd` (or the file that already tests the validator — `grep -l WorldValidator tests/`).

**Interfaces — Consumes:** Task 1 flags. **Produces:** `Enemy.slow_for(seconds: float)`; `WorldValidator.validate(rooms: Dictionary, creature_ids: Array = []) -> PackedStringArray` (when `creature_ids` is non-empty each spawn's `id` must be in it; every feature `kind` must be one `RoomFeatures.make` builds: `glow_pool`, `rebirth_pool`, `tablet`, `switch`); `EnemyState.pick` arms for `spore_moth`, `mushroom_crab`, `vine_snake`.

- [ ] **Step 1: Write the failing tests.**

`tests/test_grotto_enemy_flags.gd`:
```gdscript
extends GutTest
## The crab reuses the lizard's charger and armored front through data flags; slow_for is the one _slow writer.

var creatures := {}
var skills_by_id := {}

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	func receive_hit(_raw: int, _t: String, _from: Vector2 = Vector2.INF, _c: String = "") -> void:
		pass

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	return e

func test_a_front_tackle_hurts_an_armored_charger_but_does_not_stun_it() -> void:
	for id in ["lizard", "mushroom_crab"]:
		var e := _enemy(id)
		var before := e.health.hp
		var stunned := e.receive_tackle(4, false)
		assert_false(stunned, "%s front" % id)
		assert_lt(e.health.hp, before, "%s still takes damage from the front" % id)
		assert_ne(e.status.state, EnemyStatus.STUNNED, id)

func test_a_rear_tackle_stuns_an_armored_charger() -> void:
	for id in ["lizard", "mushroom_crab"]:
		var e := _enemy(id)
		assert_true(e.receive_tackle(1, true), id)
		assert_eq(e.status.state, EnemyStatus.STUNNED, id)

func test_other_creatures_are_stunned_from_the_front() -> void:
	var e := _enemy("toad")
	assert_true(e.receive_tackle(1, false))

func test_slow_for_halves_speed_for_its_seconds_and_thread_uses_it() -> void:
	var e := _enemy("toad")
	var base := e._speed()
	e.slow_for(1.5)
	assert_almost_eq(e._speed(), base * 0.5, 0.001)
	var f := _enemy("toad")
	f.receive_thread(1)
	assert_almost_eq(f._speed(), base * 0.5, 0.001, "receive_thread slows through slow_for")
```

Extend `tests/test_enemy_state.gd` (add at the end; use its existing call style — read the file's helper first):
```gdscript
func test_the_new_creatures_have_arms_and_do_not_fall_back_to_idle() -> void:
	var s := EnemyStatus.ACTIVE
	# moth: fly whatever it does
	assert_eq(EnemyState.pick("spore_moth", s, "", "idle", false, false, false, false, false, false), "fly")
	# crab: the lizard's charge string
	assert_eq(EnemyState.pick("mushroom_crab", s, "windup", "idle", false, false, false, true, false, false), "windup")
	assert_eq(EnemyState.pick("mushroom_crab", s, "charge", "idle", false, false, false, true, true, false), "charge")
	assert_eq(EnemyState.pick("mushroom_crab", s, "rest", "idle", false, false, false, true, false, false), "rest")
	assert_eq(EnemyState.pick("mushroom_crab", s, "", "idle", false, false, false, true, true, false), "walk")
	assert_eq(EnemyState.pick("mushroom_crab", s, "", "idle", false, false, false, true, false, false), "idle")
	# snake: coil / lunge / retreat (rest plays slither) / hide
	assert_eq(EnemyState.pick("vine_snake", s, "windup", "idle", false, false, true, false, false, false), "coil")
	assert_eq(EnemyState.pick("vine_snake", s, "charge", "idle", false, false, true, false, true, false), "lunge")
	assert_eq(EnemyState.pick("vine_snake", s, "rest", "idle", false, false, true, false, true, false), "rest")
	assert_eq(EnemyState.pick("vine_snake", s, "", "idle", false, false, true, false, false, false), "hide")
	# status still wins
	assert_eq(EnemyState.pick("vine_snake", EnemyStatus.STUNNED, "charge", "idle", false, false, true, false, false, false), "stunned")
```

Validator tests (add to the file that tests `WorldValidator`; use its `_room` helper if any, else build a `RoomDef` like `test_rebirth_pool._room`):
```gdscript
func test_a_spawn_with_an_unknown_creature_is_an_error_when_ids_are_given() -> void:
	var r := _room("T1", [])
	r.spawns = [{"id": "spore_mothh", "pos": Vector2(10, 10)}]
	assert_eq(WorldValidator.validate({"T1": r}).size(), 0, "no ids given: not checked")
	var errs := WorldValidator.validate({"T1": r}, ["spore_moth"])
	assert_string_contains(str(errs), "spore_mothh")

func test_an_unknown_feature_kind_is_an_error() -> void:
	var r := _room("T1", [{"kind": "glow_poool", "id": "x", "pos": Vector2(1, 1)}])
	assert_string_contains(str(WorldValidator.validate({"T1": r})), "glow_poool")
```
Also a test that the shipped world validates with the real creature ids: `assert_eq(WorldValidator.validate(rooms, ids).size(), 0)`.

- [ ] **Step 2: Run** them. Expected: FAIL (`slow_for` missing, `pick` returns idle, `validate` takes one argument).
- [ ] **Step 3: Implement.**
  - `enemy.gd` `receive_tackle`: replace `if def.id == Sources.LIZARD and not from_behind:` with `if def.armored_charger and not from_behind:`. `_act`: replace `if def.id == Sources.LIZARD and _charger_act(to_player, delta):` with `if def.armored_charger and _charger_act(to_player, delta):`. Add and use
    ```gdscript
    ## One writer for the slow: a thread and Spore Cloud both call it.
    func slow_for(seconds: float) -> void:
    	_slow = maxf(_slow, seconds)
    ```
    and `receive_thread`'s else branch calls `slow_for(SLOW_SECONDS)`.
  - `enemy_state.gd`: add arms before `return "idle"`:
    ```gdscript
    		"spore_moth", "pale_moth":
    			return "fly"
    		"mushroom_crab":
    			if charge != "":
    				return charge
    			return "walk" if moving else "idle"
    		"vine_snake":
    			match charge:
    				"windup":
    					return "coil"
    				"charge":
    					return "lunge"
    				"rest":
    					return "rest"
    			return "hide"
    ```
    (`pale_moth` costs nothing here and is used in Task 8.)
  - `frame_name()` (no-sheet fallback) needs no arm: it returns `def.id`, and a creature with no old single sprite draws nothing until its sheet loads; `use_sheet` false tests that touch new creatures only check state, not pixels.
  - `world_validator.gd`: `static func validate(rooms: Dictionary, creature_ids: Array = [])`; inside the per-room loop call `errors.append_array(_check_content(a, creature_ids))`:
    ```gdscript
    const FEATURE_KINDS := ["glow_pool", "rebirth_pool", "tablet", "switch"]

    static func _check_content(r: RoomDef, creature_ids: Array) -> PackedStringArray:
    	var out := PackedStringArray()
    	if not creature_ids.is_empty():
    		for s in r.spawns:
    			if not creature_ids.has(s.get("id", "")):
    				out.append("%s: spawn names unknown creature '%s'" % [r.id, s.get("id", "")])
    	for f in r.features:
    		if not FEATURE_KINDS.has(f.get("kind", "")):
    			out.append("%s: unknown feature kind '%s'" % [r.id, f.get("kind", "")])
    	return out
    ```
    `game.gd`: `WorldValidator.validate(rooms, _creatures.keys())`.
  - `data/enemy_clips.json`: no entries yet (Task 5 adds them with the sheets).
- [ ] **Step 4: Run** the three test files, then the full suite → green.
- [ ] **Step 5: Commit** `feat: armored_charger and drifter flags drive the charger and armored front, slow_for, EnemyState arms, world validator content checks`.

---

### Task 3: Behaviours: moth, crab, snake, and the spore puff

**Files:** Modify `scripts/enemies/enemy.gd`; create `scripts/enemies/spore_puff.gd`; `data/audio/cues.json` (cue for the puff). Test: `tests/test_grotto_creatures.gd`.

**Interfaces — Consumes:** Tasks 1–2. **Produces:** `SporePuff` (Node2D, group `hazards`; `launch(pos: Vector2)`, `RADIUS := 20.0`, `LIFETIME := 2.0`, static `hits(target, point) -> bool`); `Enemy._drift_act`, `Enemy._snake_act`; world event `spore_puff` (`{"pos": Vector2}`) emitted when a puff is dropped.

Behaviour rules (from the spec): **Moth** (`def.drifter`): no gravity while ACTIVE or STUNNED (a DYING/DOWNED/GONE one falls); drifts side to side within `PATROL_RANGE * 2` of its home x at 60% speed, holding its home y ±14 (sine), and returns to home y after a stun; every 3 s (`PUFF_INTERVAL`), only while the player is within 320 px (`PUFF_RANGE`), it flashes for `PUFF_WINDUP` 0.4 s (via `_telegraphing()`) then drops a puff at its position. **Crab**: nothing new (the lizard's `_charger_act`). **Snake** (`def.id == Sources.VINE_SNAKE`): tethered to its spawn anchor, `_on_ceiling` never clears; while ACTIVE it waits; when alert and the player is within 40 px in x and 0 < dy ≤ 110 it coils (`_charge = "windup"`, 0.5 s), then lunges (`"charge"`, 0.3 s) along the direction to where the player was at the end of the coil at 300 px/s capped at 80 px from the anchor, then retreats (`"rest"`) back to the anchor at 100 px/s, then hides again. Gravity is off for the snake while ACTIVE or STUNNED and it holds its position when stunned; a dying or downed snake falls.

- [ ] **Step 1: Write the failing tests** `tests/test_grotto_creatures.gd` (copy the `StubPlayer`, `_enemy`, `_solid`, `_floor` helpers from `tests/test_enemy_behaviour.gd`; `_enemy` sets `use_sheet = false`; the stub player also needs `hurt_polygon` absent so `SporePuff.hits` falls back to distance):

```gdscript
func test_a_moth_neither_falls_nor_dives() -> void:
	var m := _enemy("spore_moth", Vector2(0, -60))  # no floor: a faller would drop
	fake_player.global_position = Vector2(60, -60)  # alert range, level with it: a bat would dive
	await wait_physics_frames(60)
	assert_almost_eq(m.global_position.y, -60.0, 16.0, "it holds its height")
	assert_ne(m.swoop_state(), "dive")

func test_a_moth_drops_one_puff_per_interval_in_view_after_a_flash() -> void:
	var m := _enemy("spore_moth", Vector2(0, -60))
	fake_player.global_position = Vector2(100, -60)
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0) - 30)
	assert_eq(_puffs(), 0, "not yet")
	await wait_physics_frames(60)
	assert_eq(_puffs(), 1, "one puff by the interval")
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0))
	assert_eq(_puffs(), 2, "the first is still lingering or gone, the second dropped")  # LIFETIME 2 < INTERVAL 3: adjust to count total launched via the world event if this flakes
	m.queue_free()

func test_a_moth_far_from_the_player_drops_nothing() -> void:
	_enemy("spore_moth", Vector2(0, -60))
	fake_player.global_position = Vector2(2000, -60)
	await wait_physics_frames(int(Enemy.PUFF_INTERVAL * 60.0) * 2)
	assert_eq(_puffs(), 0)

func test_a_stunned_moth_stays_aloft_and_a_downed_one_falls() -> void:
	_floor()
	var m := _enemy("spore_moth", Vector2(0, -60))
	await wait_physics_frames(5)
	m.status.stun()
	await wait_physics_frames(30)
	assert_almost_eq(m.global_position.y, -60.0, 16.0, "stunned: still aloft")
	m.status.down()
	await wait_physics_frames(90)
	assert_gt(m.global_position.y, -20.0, "downed: it fell to the floor so it can be eaten")

func test_a_puff_hurts_the_player_once_then_lingers_harmlessly() -> void:
	var puff := SporePuff.new()
	add_child_autofree(puff)
	puff.launch(Vector2(0, 0))
	fake_player.global_position = Vector2(4, 0)
	await wait_physics_frames(30)
	assert_eq(fake_player.poisons.size(), 1, "one hit per puff, however long it lingers on the player")
	assert_true(puff.is_in_group("hazards"))

func test_a_puff_expires_and_ignores_enemies() -> void:
	var puff := SporePuff.new()
	add_child_autofree(puff)
	puff.launch(Vector2(500, 0))
	var toad := _enemy("toad", Vector2(500, 0))
	await wait_physics_frames(int(SporePuff.LIFETIME * 60.0) + 10)
	assert_true(toad.health.hp == toad.health.max_hp, "a puff hurts the player only")
	assert_false(is_instance_valid(puff) and puff.is_inside_tree(), "it expired")

func test_a_snake_lunges_when_you_pass_under_then_returns_to_its_anchor() -> void:
	var s := _enemy("vine_snake", Vector2(0, -100))
	var anchor := s.global_position
	fake_player.global_position = Vector2(20, 0)  # under it, within 110
	var seen := {}
	for i in 240:
		await wait_physics_frames(1)
		seen[s.charge_state()] = true
		assert_true(s._on_ceiling, "the tether never clears")
	assert_true(seen.has("windup") and seen.has("charge") and seen.has("rest"), str(seen.keys()))
	fake_player.global_position = Vector2(2000, 0)
	await wait_physics_frames(120)
	assert_lt(s.global_position.distance_to(anchor), 4.0, "back on its anchor")

func test_a_stunned_snake_holds_still_and_a_downed_one_falls() -> void:
	_floor()
	var s := _enemy("vine_snake", Vector2(0, -100))
	await wait_physics_frames(5)
	s.status.stun()
	await wait_physics_frames(30)
	assert_almost_eq(s.global_position.y, -100.0, 3.0, "stunned mid-air: it stays on its tether")
	s.status.down()
	await wait_physics_frames(120)
	assert_gt(s.global_position.y, -30.0)
```
(`_puffs()` = `get_tree().get_nodes_in_group("hazards").filter(func(n): return n is SporePuff).size()`.) If the cadence test proves timing-fragile, count `spore_puff` world events instead (connect to `EventBus.world_event`).

- [ ] **Step 2: Run** `tools/run_tests.sh test_grotto_creatures`. Expected: FAIL (`PUFF_INTERVAL`, `SporePuff` missing).
- [ ] **Step 3: Implement.**
  - `spore_puff.gd`:
    ```gdscript
    class_name SporePuff
    extends Node2D
    ## A moth's spore puff: a short-lived cloud that poisons the player once. Group `hazards` (which hurts the
    ## player only, like the toad's glob); the player's own Spore Cloud is a different group.
    const RADIUS := 20.0
    const LIFETIME := 2.0
    const POISON := 1
    const TICK := 1
    const SECONDS := 2.0
    var _age := 0.0
    var _hit := false

    func launch(at: Vector2) -> void:
    	global_position = at
    	add_to_group("hazards")

    func _ready() -> void:
    	if get_child_count() == 0:
    		var haze := ColorRect.new()
    		haze.color = Color(0.85, 0.95, 0.35, 0.35)
    		haze.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
    		haze.position = -haze.size / 2.0
    		add_child(haze)
    		add_child(Art.light(Color(0.85, 0.95, 0.4), 0.5, 0.5))

    func _physics_process(delta: float) -> void:
    	_age += delta
    	if _age > LIFETIME:
    		queue_free()
    		return
    	if _hit:
    		return
    	var player: Node2D = get_tree().get_first_node_in_group("player")
    	if player != null and SporePuff.hits(player, global_position):
    		_hit = true
    		player.receive_poison(POISON, TICK, SECONDS)

    ## True when a puff centred on `point` overlaps `target`: its traced shape, or the centre distance for a
    ## target with no shape (test stubs).
    static func hits(target: Node2D, point: Vector2) -> bool:
    	if target.has_method("hurt_polygon"):
    		return ShapeHit.point_near(target.hurt_polygon(), point, RADIUS)
    	return target.global_position.distance_to(point) <= RADIUS
    ```
  - `enemy.gd`: constants `PUFF_INTERVAL := 3.0`, `PUFF_WINDUP := 0.4`, `PUFF_RANGE := 320.0`, `LUNGE_TRIGGER_X := 40.0`, `LUNGE_TRIGGER_Y := 110.0`, `COIL_SECONDS := 0.5`, `LUNGE_SECONDS := 0.3`, `LUNGE_SPEED := 300.0`, `LUNGE_REACH := 80.0`, `RETREAT_SPEED := 100.0`. Vars `_home_y := 0.0`, `_anchor := Vector2.ZERO`, `_puff_t := PUFF_INTERVAL`, `_puff_windup := 0.0`, `_lunge_dir := Vector2.ZERO`. `_ready`: `_home_y = global_position.y`, `_anchor = global_position`. Physics gravity block becomes:
    ```gdscript
    	var stunned := status.state == EnemyStatus.STUNNED
    	var flying := capabilities.has("flight") and active
    	var hovering := def.drifter and (active or stunned)
    	var tethered := def.id == Sources.VINE_SNAKE and _on_ceiling and (active or stunned)
    	if hovering and not active:
    		velocity.y = 0.0  # a stunned moth holds its height
    	if tethered and not active:
    		velocity = Vector2.ZERO
    	if not flying and not hovering and not tethered and not (_on_ceiling and active):
    		velocity.y += GRAVITY * delta
    ```
    (the existing `elif status.state != DYING` branch already zeroes `velocity.x` for a stunned body). `_act`: after the ceiling branch is skipped for the snake, order the branches: `if def.id == Sources.VINE_SNAKE: _snake_act(player, to_player, delta); return` first, then the existing `_on_ceiling` spider block, then `if def.drifter: _drift_act(player, to_player, delta); return`, then flight, charger, spitter, walk. `_telegraphing()` adds `or _puff_windup > 0.0`. `_drift_act`:
    ```gdscript
    ## A slow side-to-side loop about its home; drops a spore puff every PUFF_INTERVAL while the player is near.
    func _drift_act(player: Node2D, to_player: Vector2, delta: float) -> void:
    	if global_position.x > _home_x + PATROL_RANGE * 2.0:
    		facing = -1
    	elif global_position.x < _home_x - PATROL_RANGE * 2.0:
    		facing = 1
    	velocity.x = facing * _speed() * 0.6
    	var target_y := _home_y + sin(_anim_t * 1.6) * 14.0
    	velocity.y = clampf((target_y - global_position.y) * 2.0, -60.0, 60.0)
    	if to_player.length() > PUFF_RANGE:
    		_puff_t = PUFF_INTERVAL
    		_puff_windup = 0.0
    		return
    	if _puff_windup > 0.0:
    		_puff_windup -= delta
    		if _puff_windup <= 0.0:
    			var puff := SporePuff.new()
    			get_parent().add_child(puff)
    			puff.launch(global_position)
    			EventBus.world_event.emit("spore_puff", {"pos": global_position})
    			_puff_t = PUFF_INTERVAL
    		return
    	_puff_t -= delta
    	if _puff_t <= PUFF_WINDUP:
    		_puff_windup = PUFF_WINDUP
    ```
    `_snake_act`:
    ```gdscript
    ## Tethered to its anchor: coil when prey passes under, lunge along the line to where it was, retreat, hide.
    func _snake_act(player: Node2D, to_player: Vector2, delta: float) -> void:
    	_charge_t -= delta
    	match _charge:
    		"windup":
    			velocity = Vector2.ZERO
    			if _charge_t <= 0.0:
    				_lunge_dir = (player.global_position - global_position).normalized()
    				_charge = "charge"
    				_charge_t = LUNGE_SECONDS
    		"charge":
    			velocity = _lunge_dir * LUNGE_SPEED
    			if _charge_t <= 0.0 or global_position.distance_to(_anchor) >= LUNGE_REACH:
    				_charge = "rest"
    		"rest":
    			var back := _anchor - global_position
    			if back.length() <= 3.0:
    				global_position = _anchor
    				velocity = Vector2.ZERO
    				_charge = ""
    			else:
    				velocity = back.normalized() * RETREAT_SPEED
    		_:
    			velocity = Vector2.ZERO
    			if is_alert() and absf(to_player.x) < LUNGE_TRIGGER_X and to_player.y > 0.0 and to_player.y <= LUNGE_TRIGGER_Y:
    				_charge = "windup"
    				_charge_t = COIL_SECONDS
    	if absf(velocity.x) > 1.0:
    		facing = 1 if velocity.x > 0.0 else -1
    ```
    (The snake's `charge` reuse means `_charge_t` and `charge_state()` work; the `rest` step must not depend on `_charge_t`, which is why it tests distance.)
  - `data/audio/cues.json`: add `spore_puff` mapped to an existing soft cue (mirror how `enemy_hit` or `pool_rest` is declared; reuse a sample already shipped; `test_audio_boundary` fails until it is there).
- [ ] **Step 4: Run** `test_grotto_creatures`, `test_audio_boundary`, the existing enemy suites (`test_enemy`, `test_enemy_ai`, `test_enemy_behaviour`, `test_enemy_contact`) and the full suite → green. Fix flakiness by counting world events, not nodes.
- [ ] **Step 5: Commit** `feat: spore moth drift and puffs, mushroom crab charger reuse, vine snake tethered lunge`.

---

### Task 4: Spore Cloud and Hardened Shell

**Files:** Create `scripts/abilities/spore_cloud.gd`, `scripts/abilities/spore_cloud_area.gd`, `scenes/abilities/spore_cloud.tscn`; modify `scripts/player/player_skill_set.gd`, `scripts/player/player.gd`, `scripts/ui/skill_screen_model.gd`. Tests: `tests/test_spore_cloud.gd`, `tests/test_hardened_shell.gd`.

**Interfaces — Produces:** `SporeCloudArea` (Node2D, group `player_clouds`; `launch(at, radius, seconds, actor)`, ticks each second); `PlayerSkillSet.knockback_factor() -> float`.

- [ ] **Step 1: Write the failing tests.**

`tests/test_spore_cloud.gd`:
```gdscript
extends GutTest
## Spore Cloud: a lingering cloud that slows and poisons enemies, never the player, and expires.

class StubActor extends Node2D:
	var team := "player"
	var facing := 1

var actor: StubActor
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	actor = StubActor.new()
	add_child_autofree(actor)

func _toad(pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures["toad"], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func test_the_cloud_poisons_and_slows_an_enemy_inside_it_each_second() -> void:
	var toad := _toad(Vector2(30, 0))
	var cloud := SporeCloudArea.new()
	add_child_autofree(cloud)
	cloud.launch(Vector2(30, 0), 24.0, 2.0, actor)
	var hp := toad.health.hp
	await wait_seconds(1.2)
	assert_eq(toad.health.hp, hp - 1, "one poison damage after the first second")
	assert_lt(toad._speed(), Enemy.BASE_SPEED * toad.stats.get_stat("spd") / 100.0, "slowed")

func test_an_enemy_outside_the_radius_is_untouched() -> void:
	var toad := _toad(Vector2(200, 0))
	var cloud := SporeCloudArea.new()
	add_child_autofree(cloud)
	cloud.launch(Vector2(0, 0), 24.0, 2.0, actor)
	await wait_seconds(1.2)
	assert_eq(toad.health.hp, toad.health.max_hp)

func test_the_cloud_expires_and_is_in_its_own_group_not_hazards() -> void:
	var cloud := SporeCloudArea.new()
	add_child_autofree(cloud)
	cloud.launch(Vector2.ZERO, 24.0, 0.5, actor)
	assert_true(cloud.is_in_group("player_clouds"))
	assert_false(cloud.is_in_group("hazards"), "the puff group hurts the player; this one never does")
	await wait_seconds(0.8)
	assert_false(is_instance_valid(cloud) and cloud.is_inside_tree())

func test_duration_and_radius_grow_with_level() -> void:
	assert_almost_eq(SporeCloud.duration_for(1), 2.0, 0.0001)
	assert_almost_eq(SporeCloud.duration_for(8), 3.75, 0.0001)
```
(Ability `SporeCloud` static `duration_for(level) := 2.0 + 0.25 * (level - 1)`.)

`tests/test_hardened_shell.gd`:
```gdscript
extends GutTest
## Hardened Shell scales the knockback a hit gives the player, and a player without it takes full knockback.

func _player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var comp := CompendiumModel.new(skills, DefLoader.load_dir("res://data/creatures"))
	var p := Player.new()
	p.setup(rules, comp, [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	return p

func test_a_player_without_the_skill_takes_full_knockback() -> void:
	var p := _player()
	p.receive_hit(1, "physical", Vector2(-50, 0))
	assert_almost_eq(p.velocity.x, Player.KNOCKBACK.x, 0.01)
	assert_almost_eq(p.velocity.y, Player.KNOCKBACK.y, 0.01)

func test_the_skill_scales_both_components_per_level() -> void:
	var p := _player()
	p.skillset.rules.grant("hardened_shell", false)
	p.skillset.refresh()
	assert_almost_eq(p.skillset.knockback_factor(), 0.92, 0.0001)
	p.receive_hit(1, "physical", Vector2(-50, 0))
	assert_almost_eq(p.velocity.x, Player.KNOCKBACK.x * 0.92, 0.01)
	assert_almost_eq(p.velocity.y, Player.KNOCKBACK.y * 0.92, 0.01)

func test_the_skill_screen_reads_knockback_in_percent() -> void:
	var d: SkillDef = null
	for s in DefLoader.load_dir("res://data/skills"):
		if s.id == "hardened_shell":
			d = s
	var lines := SkillScreenModel.effect_lines(d, 3)
	assert_true(lines.has("Knockback taken −24%"), str(lines))
```
(Check `SkillScreenModel`'s function name/signature for the effects lines in `scripts/ui/skill_screen_model.gd` near line 120 and use it; also `p.skillset.rules` is the field name used in `player_skill_set.gd`; adjust if it differs.)

- [ ] **Step 2: Run.** Expected: FAIL (`SporeCloudArea` missing; velocity ignores the factor).
- [ ] **Step 3: Implement.**
  - `spore_cloud_area.gd`:
    ```gdscript
    class_name SporeCloudArea
    extends Node2D
    ## The player's Spore Cloud: for `seconds`, each second it poisons (1) and slows every enemy inside it.
    ## Group `player_clouds`; it never touches the player and is not a `hazards` node.
    const TICK_SECONDS := 1.0
    var radius := 24.0
    var _left := 0.0
    var _tick := 0.0
    var _actor: Node2D

    func launch(at: Vector2, p_radius: float, seconds: float, actor: Node2D) -> void:
    	global_position = at
    	radius = p_radius
    	_left = seconds
    	_actor = actor
    	add_to_group("player_clouds")

    func _ready() -> void:
    	if get_child_count() == 0:
    		var haze := ColorRect.new()
    		haze.color = Color(0.7, 0.95, 0.4, 0.3)
    		haze.size = Vector2(radius * 2.0, radius * 2.0)
    		haze.position = -haze.size / 2.0
    		add_child(haze)

    func _physics_process(delta: float) -> void:
    	_left -= delta
    	if _left <= 0.0:
    		queue_free()
    		return
    	_tick += delta
    	if _tick < TICK_SECONDS:
    		return
    	_tick -= TICK_SECONDS
    	for n in get_tree().get_nodes_in_group("actors"):
    		if n == _actor or not n.has_method("receive_hit") or n.get("team") == _actor.get("team"):
    			continue
    		if n.has_method("can_be_hit") and not n.can_be_hit():
    			continue
    		if n.global_position.distance_to(global_position) <= radius:
    			n.receive_hit(1, "poison", global_position, "poison")
    			if n.has_method("slow_for"):
    				n.slow_for(Enemy.SLOW_SECONDS)
    ```
  - `spore_cloud.gd` (extends `Ability`): `static func duration_for(level: int) -> float: return 2.0 + 0.25 * float(level - 1)`; `_perform()` drops a `SporeCloudArea` at `actor.global_position + aim_dir() * 32.0` in `actor.get_parent()` with `radius = float(value())`, `seconds = duration_for(level)`, and `Vfx.puffs` like poison breath for feedback. Scene `scenes/abilities/spore_cloud.tscn` copies `poison_breath.tscn` with the script path and node name `SporeCloud`. Run `godot --headless --import` after adding the class names.
  - `player_skill_set.gd`: 
    ```gdscript
    ## The multiplier on the knockback a hit gives the player (1.0 with no Hardened Shell).
    func knockback_factor() -> float:
    	var pairs: Array = []
    	for id in rules.owned():
    		pairs.append([rules.get_def(id), rules.level_of(id)])
    	return SkillEffects.knockback_factor(pairs)
    ```
    `player.gd` `receive_hit`: `velocity = Vector2(away * KNOCKBACK.x, KNOCKBACK.y) * skillset.knockback_factor()`.
  - `skill_screen_model.gd`: in the `modifier` match add before the generic `else`: `elif stat == SkillEffects.KNOCKBACK_TAKEN: lines.append("Knockback taken −%d%%" % -v)`.
- [ ] **Step 4: Run** both new tests, `test_abilities`, `test_skill_caps`, and the full suite → green.
- [ ] **Step 5: Commit** `feat: Spore Cloud and Hardened Shell, knockback scaled by the shell`.

---

### Task 5: Sheets, clips and the bestiary portraits (needs the generated art)

**Files:** `art_source/frames/{spore_moth,mushroom_crab,vine_snake,dressing_grotto}/*.png` (generated), `assets/sheets/{spore_moth,mushroom_crab,vine_snake}.{png,json}`, `assets/dressing/grotto/*` + `pieces.json`, `data/enemy_clips.json`, `scripts/ui/skill_screen.gd`. Tests: `tests/test_enemy_sheets.gd`, `tests/test_bestiary.gd` (or the file covering `_portrait`), `tests/test_dressing.gd`-style tests that already iterate biomes.

**Interfaces — Produces:** sheets loadable via `SpriteSheet.load_set("spore_moth")` etc.; clips for the three sets; `DressingLib.has_biome("grotto")` with the 8 pieces; a bestiary portrait for a sheet-only creature.

- [ ] **Step 1: Wait for the background generators** (five workers started at the beginning of the branch; their outputs are in `art_source/frames/`). Check completeness: `ls art_source/frames/spore_moth | wc -l` (7), `mushroom_crab` (11), `vine_snake` (10), `dressing_grotto` (8). Build a raw contact sheet per set as the enemy-art plan did (`tools/art/enemy_review.py` if it takes a set name; else view PNGs with Read) and look at every frame: same creature across frames, facing right, magenta fully keyed, the snake's `hide_1` reads as a hanging vine. Regenerate a bad frame alone: `uv run --python 3.12 python tools/art/generate_frames.py <set> <frame>` (unsandboxed; an explicit name regenerates). Do not proceed on frames that look wrong.
- [ ] **Step 2: Extend the tests first.** In `tests/test_enemy_sheets.gd`: `SETS` gains `"spore_moth", "mushroom_crab", "vine_snake"`; the `states` table gains
  ```gdscript
  		"spore_moth": ["fly", "stunned", "hurt", "downed"],
  		"mushroom_crab": ["idle", "walk", "windup", "charge", "rest", "stunned", "hurt", "downed"],
  		"vine_snake": ["hide", "coil", "lunge", "rest", "slither", "stunned", "hurt", "downed"]
  ```
  `test_only_the_charging_lizard_and_the_diving_bat_have_attack_shapes` already checks each listed frame's `attack_from` against its shape and asserts only the lizard and bat, so extend its last two asserts to name the crab and snake too (`assert_true(_listed("mushroom_crab")["frames"].any(...))`, same for `vine_snake`), and rename it `test_only_the_creatures_that_strike_have_attack_shapes`. Add a portrait test: the bestiary's tile for `spore_moth`, `mushroom_crab` and `vine_snake` is not blank (see Step 4 for the function to call). Run `tools/run_tests.sh test_enemy_sheets` → FAIL (no sheets).
- [ ] **Step 3: Assemble.** `uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py spore_moth` (then `mushroom_crab`, `vine_snake`), `uv run --python 3.12 --with Pillow python tools/art/assemble_pieces.py dressing_grotto`, then the import command. Add the three clip tables to `data/enemy_clips.json`:
  ```json
  "spore_moth": {
    "fly": {"frames": ["fly_1", "fly_2", "fly_3", "fly_4"], "fps": 10.0, "loop": true},
    "stunned": {"frames": ["stunned"], "fps": 1.0, "loop": false},
    "hurt": {"frames": ["hurt"], "fps": 1.0, "loop": false},
    "downed": {"frames": ["downed"], "fps": 1.0, "loop": false}
  },
  "mushroom_crab": {
    "idle": {"frames": ["idle_1"], "fps": 1.0, "loop": true},
    "walk": {"frames": ["walk_1", "walk_2", "walk_3", "walk_2"], "fps": 8.0, "loop": true},
    "windup": {"frames": ["windup_1"], "fps": 1.0, "loop": false},
    "charge": {"frames": ["charge_1", "charge_2"], "fps": 12.0, "loop": true},
    "rest": {"frames": ["rest_1"], "fps": 1.0, "loop": true},
    "stunned": {"frames": ["stunned"], "fps": 1.0, "loop": false},
    "hurt": {"frames": ["hurt"], "fps": 1.0, "loop": false},
    "downed": {"frames": ["downed"], "fps": 1.0, "loop": false}
  },
  "vine_snake": {
    "hide": {"frames": ["hide_1"], "fps": 1.0, "loop": true},
    "coil": {"frames": ["coil_1"], "fps": 1.0, "loop": false},
    "lunge": {"frames": ["lunge_1", "lunge_2"], "fps": 10.0, "loop": false},
    "rest": {"frames": ["slither_1", "slither_2", "slither_1", "slither_3"], "fps": 8.0, "loop": true},
    "slither": {"frames": ["slither_1", "slither_2", "slither_1", "slither_3"], "fps": 8.0, "loop": true},
    "stunned": {"frames": ["stunned"], "fps": 1.0, "loop": false},
    "hurt": {"frames": ["hurt"], "fps": 1.0, "loop": false},
    "downed": {"frames": ["downed"], "fps": 1.0, "loop": false}
  }
  ```
  (The snake's `rest` clip plays the slither frames: it is the retreat; the spec's "rest plays hide" is overruled, see the ledger.) `Enemy._load_sheet` picks `idle` if the clip exists else `fly`; the snake and moth need `hide`/`fly`: extend that line to `"idle" if has idle else ("fly" if has fly else "hide")`.
- [ ] **Step 4: Portraits from the sheet.** `scripts/ui/skill_screen.gd` `_portrait` (`Art.texture(PORTRAIT.get(id, "icon_locked"))`, near line 511): when `PORTRAIT` has no entry and `SpriteSheet.available(id)`, return `SpriteSheet.load_set(id).frame_texture(PORTRAIT_FRAME.get(id, "idle_1"))` with `const PORTRAIT_FRAME := {"spore_moth": "fly_1", "mushroom_crab": "idle_1", "vine_snake": "hide_1"}`. Write the test against the real function (read it first): it returns a non-null texture of a sane size for each new id.
- [ ] **Step 5: Run** `test_enemy_sheets`, the bestiary/portrait test, dressing tests, `test_art_assets`, then the full suite → green. Also run the game headless-import once to be sure the new PNGs import.
- [ ] **Step 6: Commit** `art: spore moth, mushroom crab and vine snake sheets and clips, the Grotto dressing library, portraits from the sheet`.

---

### Task 6: The rooms, the climb chains and the pacing

**Files:** Modify `tools/prefabs.gd` (`ledge_chain`), `tools/build_world.gd` (C5's hole and moved content, G1–G4, `rooms()`), regenerate `data/rooms/*.tres`; tests: create `tests/test_grotto_rooms.gd`; rescope `tests/test_progression_stages.gd`, `tests/test_skill_caps.gd` (appraisal), `tests/test_form_offers.gd`, `tests/test_rebirth_kit.gd`, `tests/test_rooms.gd`, `tests/test_content.gd`.

**Interfaces — Consumes:** Tasks 1–5. **Produces:** `Prefabs.ledge_chain(room: Dictionary, west_x: float, width: float, offset: float, top_y: float, step: float, floor_y: float) -> void` (appends alternating ledges `Rect2(west_x if i % 2 == 0 else west_x + offset, top_y + step * i, width, 12)` while `top_y + step*i < floor_y - 8`); rooms `G1`..`G4`; C5 gains `_exit("bottom", 220, 380, "G1")`.

Layout (from the spec; world pixels; local coordinates below): C5 hole span x 220–380 ↔ G1 `top` exit 220–380. G2's hole span local x 800–960 (world 5280–5440) ↔ G3 `top` exit 160–320. G1 (2×1, cell (5,5)): `right` exit local y 200–320 ↔ G2 (3×2, cell (7,5)) `left` exit local y 200–320. G2 `bottom` exit 800–960 ↔ G3 (2×2, cell (8,7)) `top` exit 160–320. G3 `right` exit y 200–320 ↔ G4 (1×1, cell (10,7)) `left` exit y 200–320. G1 pool at (300, 320) in Task 7.

- [ ] **Step 1: Write the failing tests** `tests/test_grotto_rooms.gd`. Full helpers and assertions:

```gdscript
extends GutTest
## The Grotto: the rooms validate, are two-way, are dressed, pay the planned XP, and nothing stands over a hole.

const BODY := Vector2(28, 24)  # the 2x slime's body box
const RISE := 55.0
const GAP := 60.0

var rooms := {}
var creatures := {}

func before_all() -> void:
	rooms = World.load_rooms("res://data/rooms")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func test_the_shipped_world_validates_with_creature_ids() -> void:
	assert_eq(WorldValidator.validate(rooms, creatures.keys()).size(), 0, str(WorldValidator.validate(rooms, creatures.keys())))

func test_the_grotto_has_its_rooms_in_the_right_cells_and_sizes() -> void:
	var want := {"G1": [Vector2i(5, 5), Vector2i(2, 1)], "G2": [Vector2i(7, 5), Vector2i(3, 2)],
		"G3": [Vector2i(8, 7), Vector2i(2, 2)], "G4": [Vector2i(10, 7), Vector2i(1, 1)]}
	for id in want:
		assert_true(rooms.has(id), id)
		assert_eq([(rooms[id] as RoomDef).cell, (rooms[id] as RoomDef).size], want[id], id)
		assert_eq((rooms[id] as RoomDef).area, "grotto", id)

func test_c5_opens_into_g1_and_spawn_keys_are_unique() -> void:
	assert_true((rooms["C5"] as RoomDef).exits.any(func(e): return e["room"] == "G1" and e["edge"] == "bottom"))
	var seen := {}
	for id in rooms:
		for i in (rooms[id] as RoomDef).spawns.size():
			var k := "%s:%d" % [id, i]
			assert_false(seen.has(k), k)
			seen[k] = true

# --- pacing: one rule, summing spawn xp directly (a Progression stops paying at the cap) ---

func _reach_ungated() -> Array:
	var seen := ["C1"]
	var frontier := ["C1"]
	while not frontier.is_empty():
		var id: String = frontier.pop_back()
		for e in (rooms[id] as RoomDef).exits:
			if e.has("gate") or e.has("shortcut"):
				continue
			if not seen.has(e["room"]):
				seen.append(e["room"])
				frontier.append(e["room"])
	return seen

func _first_time(room_ids: Array) -> int:
	var total := 0
	for id in room_ids:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			total += c.xp * (1 if c.id == "water_pool" else 2)  # down and eat; a pool is only downed... it has no xp anyway
	return total

func test_the_pacing_rule() -> void:
	var open := _reach_ungated()
	var cave := open.filter(func(id): return (rooms[id] as RoomDef).area == "cave")
	var g123 := ["G1", "G2", "G3"]
	assert_true(open.has("G4"), "G4 is on the ungated route")
	assert_gte(_first_time(cave) + _first_time(["G1", "G2", "G3", "G4"]), Progression.stage_total(1), "Cave + G1..G4 reaches the cap")
	assert_lt(_first_time(cave) + _first_time(g123), Progression.stage_total(1), "Cave + G1..G3 does not: the evolution lands in G4")
	var all_cave := rooms.keys().filter(func(id): return (rooms[id] as RoomDef).area == "cave")
	assert_lt(_first_time(all_cave), Progression.stage_total(1), "the Cave alone stays under the cap")
	assert_eq(_first_time(cave), 108, "the ungated Cave is worth 108 of its 124")

func test_a_g1_life_can_reach_the_cap_from_the_ungated_xp() -> void:
	var p := Progression.new()
	p.start_at(3)
	var pool := _first_time(_reach_ungated())
	assert_gte(pool, 245, "a level-3 start needs 245 XP")
	p.add_xp(pool)
	assert_true(p.at_cap())

# --- the holes ---

func _hole_spans(id: String) -> Array:
	var out: Array = []
	var r: RoomDef = rooms[id]
	for e in r.exits:
		if e["edge"] == "top" or e["edge"] == "bottom":
			out.append(e)
	return out

func test_nothing_spawns_or_stands_over_a_floor_hole() -> void:
	for id in rooms:
		var r: RoomDef = rooms[id]
		for e in r.exits:
			if e["edge"] != "bottom":
				continue
			var span := Vector2(e["from"], e["to"])
			var floor_y := r.pixel_size().y - RoomDef.FLOOR
			for s in r.spawns:
				assert_false(_over(span, floor_y, s["pos"], Vector2(16, 12)), "%s spawn %s over its hole" % [id, s])
			for d in r.decor:
				assert_false(_over(span, floor_y, d["pos"], Vector2(24, 24)), "%s decor %s over its hole" % [id, d])
			for p in r.dressing:
				var size := DressingLib.size(r.area, p["piece"])
				assert_false(_over(span, floor_y, p["pos"], size), "%s dressing %s over its hole" % [id, p])

## `pos` with `extent` (centred in x) overlaps the span horizontally and sits within 120 px above the floor line or below it.
func _over(span: Vector2, floor_y: float, pos: Vector2, extent: Vector2) -> bool:
	var x_overlap := pos.x + extent.x / 2.0 > span.x and pos.x - extent.x / 2.0 < span.y
	return x_overlap and pos.y >= floor_y - 120.0

# --- the climb back (directed, exit to exit, with headroom) ---

## The lower room's rock, in its own coordinates: its bands, and the upper room's floor bands seen from below
## (rock from y -40 to 0 outside the hole).
func _rock(lower: RoomDef, upper_exit_span: Vector2) -> Array:
	var out: Array = []
	for w in RoomBuilder.edge_walls(lower.pixel_size(), lower.exits):
		out.append(w["rect"])
	out.append(Rect2(0, -RoomDef.FLOOR, upper_exit_span.x, RoomDef.FLOOR))
	out.append(Rect2(upper_exit_span.y, -RoomDef.FLOOR, lower.pixel_size().x - upper_exit_span.y, RoomDef.FLOOR))
	for s in lower.solids:
		out.append(s)
	return out

func _sweep_clear(rock: Array, x: float, from_top: float, to_top: float, skip: Array) -> bool:
	var column := Rect2(x - BODY.x / 2.0, to_top - BODY.y, BODY.x, from_top - to_top + BODY.y - 0.5)
	for r: Rect2 in rock:
		if skip.has(r):
			continue
		if column.intersects(r):
			return false
	return true

## True when a body standing on `p` can hop to `q`: rise within RISE, a take-off column with headroom that is
## within GAP of q sideways (or overlapping it after clearing its top).
func _hop(rock: Array, p: Rect2, q: Rect2) -> bool:
	var rise := p.position.y - q.position.y
	if rise > RISE:
		return false
	var x := p.position.x + BODY.x / 2.0
	while x <= p.end.x - BODY.x / 2.0 + 0.01:
		var gap := maxf(0.0, maxf(q.position.x - (x + BODY.x / 2.0), (x - BODY.x / 2.0) - q.end.x))
		if gap <= GAP and (rise <= 0.0 or _sweep_clear(rock, x, p.position.y, q.position.y, [p])):
			return true
		x += 4.0
	return false

## Climb from the lower room's floor to `target` (the upper room's floor piece, in lower coordinates).
func _climbs(lower: RoomDef, hole: Vector2, target: Rect2) -> bool:
	var rock := _rock(lower, hole)
	var floor_top := lower.pixel_size().y - RoomDef.FLOOR
	var surfaces: Array = lower.solids.filter(func(s: Rect2) -> bool: return s.size.y <= 24.0 and s.size.x > 20.0)
	surfaces.append(target)
	var reached: Array = []
	var frontier: Array = [Rect2(RoomDef.WALL, floor_top, lower.pixel_size().x - 2.0 * RoomDef.WALL, 1)]  # the floor
	while not frontier.is_empty():
		var p: Rect2 = frontier.pop_back()
		for q: Rect2 in surfaces:
			if reached.has(q):
				continue
			if _hop(rock, p, q):
				reached.append(q)
				frontier.append(q)
	return reached.has(target)

func test_the_chain_under_c5s_hole_reaches_c5s_west_piece_and_onward() -> void:
	var hole := Vector2(220, 380)
	var g1: RoomDef = rooms["G1"]
	var west := Rect2(RoomDef.WALL, -RoomDef.FLOOR, hole.x - RoomDef.WALL, 1)  # C5's floor west of the hole, top at -40 from G1
	assert_true(_climbs(g1, hole, west), "a player dropped into G1 can climb back to C5's west piece")

func test_the_chain_under_g2s_hole_reaches_g2s_west_piece() -> void:
	var hole := Vector2(160, 320)  # G3's local span
	var g3: RoomDef = rooms["G3"]
	var west := Rect2(RoomDef.WALL, -RoomDef.FLOOR, 0.0, 1)
	# G2's floor west piece starts at G2's west wall: in G3 coordinates it spans x from -640 (clamped) to the hole
	west = Rect2(-640, -RoomDef.FLOOR, 640 + hole.x, 1)
	assert_true(_climbs(g3, hole, west), "a player dropped into G3 can climb back to G2's west floor piece")

func test_a_chain_that_bonks_the_ceiling_band_fails_the_model() -> void:
	# a control: the same G1 with its second ledge moved out from under the span must NOT climb
	var g1: RoomDef = (rooms["G1"] as RoomDef).duplicate(true)
	var moved: Array = []
	for s in g1.solids:
		var r: Rect2 = s
		if is_equal_approx(r.position.y, 62.0):
			r = Rect2(40, r.position.y, r.size.x, r.size.y)  # far from the span
		moved.append(r)
	g1.solids = moved
	var west := Rect2(RoomDef.WALL, -RoomDef.FLOOR, 200, 1)
	assert_false(_climbs(g1, Vector2(220, 380), west), "the headroom term sees the bonk")
```
(G3's west-piece target uses G2's floor: in G3 local coordinates G2's floor band is `Rect2(-640.., -40, ...)`; adjust the two x numbers to G2's actual world x range: G2 spans world 4480–6400 and G3 world 5120–6400, so G2's floor west of the hole is G3-local x from −640 to 160. The exact rock list is `_rock`; keep `west` consistent with it. The last test also needs the second ledge to be at `top_y + 52 = 62`, which is Step 3's chain: keep those numbers.)

Also add: G4 and G2's exit sill checks, i.e. `test_g1_reaches_g2_and_g4_by_base_jumps` reusing the existing `test_every_ledge_is_reachable_from_its_floor_by_base_jumps` from `test_rooms.gd` (it iterates every room, so it covers G1–G4's ledges automatically once they exist); plus a G2 sill test: from G2's lower floor west piece the ledge chain reaches a surface whose top is at local y 320 (the G1 sill) and that surface's west edge is x ≤ 40: assert via `_climbs`-style BFS over G2's ledges from `Rect2(20, 680, 780, 1)` to `Rect2(20, 320, 40, 1)`.

- [ ] **Step 2: Run** `tools/run_tests.sh test_grotto_rooms`. Expected: FAIL (no G rooms, no chain).
- [ ] **Step 3: Author the rooms.** In `tools/prefabs.gd` add (not in `library()`, so the prefab tests that walk it are unaffected; `test_prefabs.gd`'s exit-clearance test filters solids with size.y ≤ 24 as level design, and chain ledges are 12 thick):
  ```gdscript
  ## A climb of alternating ledges under a floor hole: `width` wide, alternately at `west_x` and `west_x + offset`,
  ## `step` apart from `top_y` down to just above `floor_y`. The top ledge sits flush with the hole's west edge.
  static func ledge_chain(room: Dictionary, west_x: float, width: float, offset: float, top_y: float, step: float, floor_y: float) -> void:
  	var solids: Array = room.get("solids", [])
  	var i := 0
  	while top_y + step * i < floor_y - 8.0:
  		solids.append(Rect2(west_x if i % 2 == 0 else west_x + offset, top_y + step * i, width, 12))
  		i += 1
  	room["solids"] = solids
  ```
  `build_world.gd` (`rooms()` gains `g1(), g2(), g3(), g4()`):
  - **C5**: add `_exit("bottom", 220, 380, "G1")`; move the dressing at x 300 and 320 (`mushroom_grove` (300,1050), `stone_arch` (320,1050)) to x 500 and 620 respectively, but 620 is at the room edge: drop the `stone_arch` (320,1050) to (560, 1050) and the `mushroom_grove` to (500, 1050); the `rock_pillar` (80,1050) stays; move the lizard spawn to `(470, 1020)`. Keep the water pool (560,1036) and crystal prism (500,1040); if the moved dressing overlaps them visually, nudge decor by hand and look at the screenshot in Task 9.
  - **G1** (`"area": "grotto"`, cell (5,5), size (2,1), start none): exits `_exit("top", 220, 380, "C5")`, `_exit("right", 200, 320, "G2")`; `Prefabs.ledge_chain(f, 220.0, 90.0, 70.0, 10.0, 52.0, 320.0)` (ledges at y 10, 62, 114, 166, 218, 270; the floor at 320); decor: glowing mushrooms and moss (`grotto_glow_fungus`, `grotto_flowers` via `Prefabs.decor_id` ids `glow_fungus`/`flowers` with biome `grotto`); dressing from the new library (`mushroom_cap_pillar`, `glowing_mushroom_cluster`, `hanging_spore_moss`, `mossy_stalactite`); spawns: 3 `spore_moth` at y ≈ 200–250, x 500/700/900; 2 `mushroom_crab` at (600,300), (1000,300). The rebirth pool arrives in Task 7 (leave the features list empty here, `[]`).
  - **G2** (cell (7,5), size (3,2), 1920×720; floor top 680): exits `_exit("left", 200, 320, "G1")`, `_exit("bottom", 800, 960, "G3")`; solids: the upper walkway `Rect2(20, 320, 1880, 12)` (the G1 sill's level, continuous); a west chain `Prefabs.ledge_chain(f, 500.0, 100.0, 70.0, 632.0, -45.0, 320.0)` — the helper steps downward in y, so for a climb going UP write it as a loop: ledges `Rect2(500 if i % 2 == 0 else 570, 680 - 45 * (i + 1), 100, 12)` for i in 0..7 (top at 320+? : 680−45×8 = 320 lands on the walkway, so use i in 0..6, ending at y 365 then the walkway at 320); an east chain the same way at x 1100/1170 (from the east floor piece x 960+); two mid mushroom-cap platforms `Rect2(300, 480, 140, 12)` and `Rect2(1300, 500, 140, 12)` for the "two floors" look (each reachable: check the ledge test); dressing: cap pillars, spore moss, bridge, pod; spawns: 4 `spore_moth`, 3 `mushroom_crab` on the lower floor pieces (x 300, 650, 1200), 2 `vine_snake` at ceiling anchors `(400, 32)` and `(1500, 32)`. Nothing over the hole span x 800–960 within 120 px above y 680.
  - **G3** (cell (8,7), size (2,2), 1280×720; floor top 680): exits `_exit("top", 160, 320, "G2")`, `_exit("right", 200, 320, "G4")`; `Prefabs.ledge_chain(f, 160.0, 90.0, 70.0, 10.0, 52.0, 680.0)` (13 ledges to y 634; step to the floor 46); the east climb to G4's sill: ledges `Rect2(960 if i % 2 == 0 else 1100, 680 - 45 * (i + 1), 110, 12)` for i in 0..6 (top at 365) plus a last `Rect2(1150, 320, 110, 12)`; spawns: 4 `vine_snake` at ceiling anchors `(500, 32)`, `(700, 32)`, `(900, 32)`, `(1100, 32)`; 4 `mushroom_crab` on the floor at x 450, 600, 800, 1000. Snakes must not hang above the two chains: the west chain occupies x 160–320 (snakes start at x 500) and the east climb x 960–1260 (snake at 900 is 60 px west of 960, ok; keep 1100 snake's x 1100 above the east climb: move it to `(1030, 32)`? It hangs over the climb: fine, it is a hazard there by design; the tests do not forbid it).
  - **G4** (cell (10,7), size (1,1)): exit `_exit("left", 200, 320, "G3")`; features: `{"kind": "glow_pool", "id": "g4_pool", "pos": Vector2(320, 320)}` and a tablet `{"kind": "tablet", "id": "g4_tablet", "pos": Vector2(480, 320), "title": "Mossy tablet", "text": "Spores and shells shape those who eat them.", "hint": "spore shell"}`; spawns: 3 `spore_moth` (y ≈ 180–240), 3 `mushroom_crab` at (150,300), (250,300), (560,300).
  Keep `Prefabs.stamp(f, "cap_stairs"/"hummock", ..., false, "grotto")` for flavour where there is room clear of exits (the grotto ids exist in `Prefabs.SETS`).
  Regenerate: `gtimeout -k 5 300 env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_world.gd`, then import.
- [ ] **Step 4: Run** `test_grotto_rooms`. Tune numbers (chain x positions, spawn counts) until: the directed climbs pass, the control test fails as intended, the pacing rule passes (108 + G1..G4 ≥ 270 and 108 + G1..G3 < 270, with the guide 28/52/56/36 = 172 and 136 through G3), no spawn over a hole. If a ledge is unreachable by the existing `test_rooms` ledge test, move it.
- [ ] **Step 5: Rescope the existing tests** (each currently fails once rooms exist; run the full suite and fix what it names):
  - `test_progression_stages` cave-pass test: iterate only rooms with `area == "cave"`.
  - `test_skill_caps` `..._reachable_against_what_their_sources_supply`: `inspectable` and `sound` count only Cave rooms (`area == "cave"`); the sentence stays "the Cave alone cannot max Appraisal (8 needed, 5 types)".
  - `test_form_offers`: build `rooms` as the Cave rooms only in `before_all` (`rooms = rooms.filter`-style dictionary of `area == "cave"`), keeping its supply numbers; add a separate test that the whole world's supply includes spore and shell lineages (`supply["toxic"] > 16`, `supply["bulwark"] > 4`).
  - `test_rebirth_kit`: the "5 thread is all of Weaver's supply" assertion uses Cave-only supply; the shipped-pool eligibility test stays as is (Task 7 gives it a pool).
  - `test_rooms.gd`: the id-set assertion becomes `C1..C6` plus `G1..G4`; `test_the_main_route_needs_no_skills` also asserts G1..G4 are open.
  - `test_content.gd` essence-supply check: count essences over every spawn in every room (now includes spore and shell).
  - `test_constants`/`test_enemy_sheets` are done. `test_art_visuals` and any test iterating all creatures for a portrait/sprite: fix what fails.
- [ ] **Step 6: Run the full suite** → green. **Commit** `feat: the Fungal Grotto's four rooms, the climb chains, C5's floor hole, the pacing rule`.

---

### Task 7: G1's pool and kit, and the `ReincarnationMenu`

**Files:** Modify `tools/build_world.gd` (G1 feature), `scripts/game.gd`, `data/audio/cues.json` (menu cues if any); create `scripts/ui/reincarnation_menu.gd`; tests: `tests/test_reincarnation_menu.gd`, extend `tests/test_rebirth_kit.gd`.

**Interfaces — Produces:** `ReincarnationMenu` (`CanvasLayer`, `layer = 40`; `bind(run: Run)`; `show_decision(decision: Dictionary)`; `move(dir: int)`; `confirm() -> bool`; `selected() -> int`; `labels() -> Array`; `is_open() -> bool`).

- [ ] **Step 1: Write the failing tests.**

`tests/test_reincarnation_menu.gd`:
```gdscript
extends GutTest
## The menu renders RebirthChoice's decision, moves, confirms only unlocked entries, and sits above the death card.

func _decision() -> Dictionary:
	return {"options": [{"id": "C1", "name": "Cave mouth", "locked": false},
		{"id": "G1", "name": "Grotto rebirth pool", "locked": false},
		{"id": "F1", "name": "???", "locked": true}], "selected": 1}

func _menu() -> ReincarnationMenu:
	var m := ReincarnationMenu.new()
	add_child_autofree(m)
	return m

func test_it_does_nothing_until_a_decision_is_pending() -> void:
	var m := _menu()
	assert_false(m.is_open())
	assert_false(m.confirm())
	m.move(1)
	assert_eq(m.selected(), 0)

func test_it_renders_in_order_with_the_last_choice_selected_and_locked_pools_as_question_marks() -> void:
	var m := _menu()
	m.show_decision(_decision())
	assert_true(m.is_open())
	assert_eq(m.labels(), ["Cave mouth", "Grotto rebirth pool", "???"])
	assert_eq(m.selected(), 1)

func test_up_and_down_move_and_clamp() -> void:
	var m := _menu()
	m.show_decision(_decision())
	m.move(-1)
	assert_eq(m.selected(), 0)
	m.move(-1)
	assert_eq(m.selected(), 0, "clamped at the top")
	m.move(1)
	m.move(1)
	m.move(1)
	assert_eq(m.selected(), 2, "clamped at the bottom")

func test_a_locked_entry_cannot_be_confirmed_and_an_unlocked_one_calls_choose() -> void:
	var run := Run.new()
	add_child_autofree(run)
	var chosen: Array = []
	var m := _menu()
	m.choose_callback = func(id: String) -> void: chosen.append(id)
	m.show_decision(_decision())
	m.move(1)
	assert_eq(m.selected(), 2)
	assert_false(m.confirm())
	assert_eq(chosen, [])
	m.move(-1)
	assert_true(m.confirm())
	assert_eq(chosen, ["G1"])
	assert_false(m.is_open(), "it closes once a choice is made")

func test_it_sits_above_the_death_card() -> void:
	var run := Run.new()
	add_child_autofree(run)
	var m := _menu()
	assert_gt(m.layer, run._card.layer)
```
Also a flow test in `tests/test_rebirth_flow.gd`: with two attuned pools in a stubbed `Run` (the existing `_run`/`_pools` helpers), bind a menu to `run`, kill the player, wait for the card, assert `menu.is_open()`, call `menu.move(1)`/`menu.confirm()`, and assert `restart_requested` fired and `pending_start` names G1. And: once a menu is bound, `Run` does not auto-pick (assert `restart_requested` has NOT fired after `_resolve` with two attuned pools until `confirm()`).

Extend `tests/test_rebirth_kit.gd` `test_every_shipped_non_default_pool_leaves_two_lineages_eligible` (already loops every non-default pool) to the spec's rule: numerator = the kit's seeds plus the ungated Grotto's absorbed units; denominator = the whole-world supply; assert ≥ 2 eligible AND more than the same life without the seeds:
```gdscript
func _ungated_grotto_units(rooms: Dictionary, creatures: Dictionary) -> Dictionary:
	var out := {}
	for id in ["G1", "G2", "G3", "G4"]:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			for e in c.essences:
				out[e] = int(out.get(e, 0)) + int(c.essences[e])
	return out
```
and in the loop `var without := _ungated_grotto_units(...)`, `var with := without.duplicate(); for e in seeds: with[e] += seeds[e]`, `assert_gte(eligible(with), 2)` and `assert_gt(eligible(with), eligible(without))`. (Skip pools whose area is not `grotto`; later areas bring their own supply.) Also a test that the G1 pool's kit validates and grants Leap and Wall Cling at level 1 quietly: `RebirthKit.validate(kit)` empty, `kit["level"] == 3`.

- [ ] **Step 2: Run.** Expected: FAIL (`ReincarnationMenu` missing; G1 has no pool).
- [ ] **Step 3: Implement.**
  - `build_world.gd` G1 `features`: `[{"kind": "rebirth_pool", "id": "G1", "area": "grotto", "kit": {"skills": ["leap", "wall_cling"], "level": 3, "affinity": {"thread": 2, "sound": 2, "flight": 4}}, "pos": Vector2(300, 320)}]`. Verify with the eligibility test: the world's supply after Task 6 is weaver 11, tide 9, toxic 26, bulwark 44, echo 22 (guide spawns); ungated Grotto alone gives bulwark 36/44 (.82) and toxic 16/26 (.62); with seeds weaver 8/11 (.73), echo 16/22 (.73): four eligible versus two. If the shipped spawn counts differ, recompute and adjust the seeds until the test passes; the test is the authority.
  - `reincarnation_menu.gd`:
    ```gdscript
    class_name ReincarnationMenu
    extends CanvasLayer
    ## Shows RebirthChoice's decision after death: up/down moves, accept confirms an unlocked entry. Layer 40:
    ## above the death card (30) and the skill screen (20). It takes input only while a decision is pending.
    var choose_callback := Callable()
    var _options: Array = []
    var _index := 0
    var _open := false
    var _list := VBoxContainer.new()

    func _init() -> void:
    	layer = 40
    	visible = false

    func _ready() -> void:
    	var shade := ColorRect.new()
    	shade.color = Color(0.0, 0.0, 0.05, 0.85)
    	shade.size = Vector2(640, 360)
    	add_child(shade)
    	_list.position = Vector2(200, 110)
    	_list.size = Vector2(240, 140)
    	add_child(_list)

    func bind(run: Run) -> void:
    	choose_callback = run.choose
    	run.choice_needed.connect(show_decision)

    func show_decision(decision: Dictionary) -> void:
    	_options = decision.get("options", [])
    	_index = int(decision.get("selected", 0))
    	_open = not _options.is_empty()
    	visible = _open
    	_redraw()

    func is_open() -> bool:
    	return _open

    func labels() -> Array:
    	return _options.map(func(o: Dictionary) -> String: return o["name"])

    func selected() -> int:
    	return _index

    func move(dir: int) -> void:
    	if not _open:
    		return
    	_index = clampi(_index + dir, 0, _options.size() - 1)
    	_redraw()

    func confirm() -> bool:
    	if not _open or _options[_index]["locked"]:
    		return false
    	var id: String = _options[_index]["id"]
    	_open = false
    	visible = false
    	if choose_callback.is_valid():
    		choose_callback.call(id)
    	return true

    func _unhandled_input(event: InputEvent) -> void:
    	if not _open:
    		return
    	if event.is_action_pressed("ui_up"):
    		move(-1)
    	elif event.is_action_pressed("ui_down"):
    		move(1)
    	elif event.is_action_pressed("ui_accept"):
    		confirm()
    	else:
    		return
    	get_viewport().set_input_as_handled()

    func _redraw() -> void:
    	for c in _list.get_children():
    		c.queue_free()
    	for i in _options.size():
    		var l := Label.new()
    		l.text = ("> " if i == _index else "  ") + str(_options[i]["name"])
    		l.add_theme_font_size_override("font_size", 12)
    		l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6) if _options[i]["locked"] else Color(0.75, 0.9, 1.0))
    		_list.add_child(l)
    ```
    (`confirm` closes the menu before calling `choose`, which is why the test asserts `is_open()` is false after.)
  - `game.gd`, after `run.bind(...)`: `var menu := ReincarnationMenu.new(); add_child(menu); menu.bind(run)`. This connects `choice_needed`, so `Run` stops auto-picking. Update any whole-`Game` test that dies with two attuned pools to call `choose` (none exist; `grep -rn choice_needed tests`).
  - Regenerate rooms and import; ensure `ui_up/ui_down/ui_accept` map the stick/D-pad and A on a pad (Godot's defaults do; `Controls.ensure_actions()` does not remove them).
- [ ] **Step 4: Run** the new tests, `test_rebirth_*`, and the full suite → green.
- [ ] **Step 5: Commit** `feat: G1's rebirth pool and kit, the thin ReincarnationMenu above the death card`.

---

### Task 8: The optional slice: the Pale Moth and G5

**Files:** `tools/art/pale_moth_frames.json`, `tools/art/assemble_frames.py` (`derive_from`, `lighten`), `tools/art/test_assemble_frames.py`, `assets/sheets/pale_moth.{png,json}`, `scripts/core/sources.gd`, `tools/build_content.gd`, `data/creatures/pale_moth.tres`, `data/enemy_clips.json`, `scripts/enemies/enemy.gd` (nothing: `def.drifter` and the `pick` arm already cover it), `scripts/ui/skill_screen.gd` (`PORTRAIT_FRAME`), `tools/build_world.gd` (G3's opening, G5), tests `tests/test_pale_moth.gd`, `tests/test_grotto_rooms.gd` additions. Keep this slice in its own commit range so it can be dropped.

**Interfaces — Produces:** `Sources.PALE_MOTH`; creature `pale_moth` (`drifter = true`); a `pale_moth` sheet derived from the moth's frames; room `G5` (cell (7,7), size (1,1)) with exit `_exit("right", 200, 320, "G3", {"gate": "wall_cling"})` and G3's matching `_exit("left", 200, 320, "G5", {"gate": "wall_cling"})`.

- [ ] **Step 1: Tests first.**
  - `tools/art/test_assemble_frames.py`: a `derive_from` set reads the source set's keyed source frames, applies `lighten` (a 0..1 blend toward white on RGB, alpha untouched) AFTER keying and cropping, and scales by the enlarge factor from the widths; a lightened frame is lighter than its source and keeps its alpha silhouette; the magenta key is still removed (a raw-lightened key would not be).
  - `tests/test_pale_moth.gd`: the def numbers (6/1/0/110, xp 8, spore 3 flight 2, `drifter`); `Sources.ALL` has it; the sheet loads with the same frame names as the moth's and every frame is at least 1.3× the moth's matching frame in width; its clips equal the moth's; `EnemyState.pick("pale_moth", ...)` returns `fly`; an `Enemy` built from it drifts and drops puffs like the moth (reuse the Task 3 cadence test with `pale_moth`); its traced hurt shape hugs its pixels (`test_enemy_sheets` `SETS` gains `pale_moth`, which already checks frames on the floor line and inside their frames); its portrait is non-blank.
  - Rooms: extend `tests/test_grotto_rooms.gd`: G5 exists and holds exactly one `pale_moth` spawn and nothing else; G3's exit to G5 has `gate: "wall_cling"`; `test_the_pacing_rule` still passes (G5 is gated so it is not on the ungated route: assert `not _reach_ungated().has("G5")`); the G5 gate is structural: with `T` derived from `Player` (`Player.JUMP_SPEED`/`GRAVITY` constants; read `scripts/player/player.gd` lines 9–12 and 300 for their names; the Leap and Echo `jump_height` modifiers from `data/skills/leap.tres` and `tools/build_forms.gd`), assert (a) the chimney's paired walls exist in G3 (two solids, each ≤ 20 wide or > 24 tall, flanking the opening) and hang from the ceiling to at least `T` px below the opening's lower lip where `T = max(stage1, stage2 apex) + 3` (the test computes stage 1 with Leap at the stage-1 cap 5 (+30%) and stage 2 with Leap 8 (+45%) plus Echo's +10, each as `apex = 60.5 * jump_height / 100`, so `T = 96.775`); (b) no solid lies between the paired walls above the chimney's bottom; (c) no base-jump path reaches the opening: run the Task 6 `_hop` model over G3's surfaces and assert the opening's sill is not reachable.
- [ ] **Step 2: Run** them → FAIL.
- [ ] **Step 3: Implement.**
  - `assemble_frames.py`: read optional `derive_from` (a set name) and `lighten` (float) from the JSON. When present, source images come from `art_source/frames/<derive_from>/<name>.png`, and after keying and cropping (inside `fit_scaled`/`fit_frame` on the keyed crop) blend RGB toward white by `lighten` before scaling; widths in the JSON are the moth's times 1.4. The anchor scale comes from the derived anchor width, so frames keep the moth's proportions enlarged. `pale_moth_frames.json`: `{"derive_from": "spore_moth", "lighten": 0.45, "anchor": "fly_1", "frames": [same names as the moth with widths × 1.4]}` — no prompts, refs or canonical. Then `uv run --python 3.12 --with Pillow python tools/art/assemble_frames.py pale_moth`.
  - Sources/content/clips/portrait: `PALE_MOTH := "pale_moth"` in `Sources.ALL`; `_cr({"id": "pale_moth", "display_name": "Pale Moth", "stats": {"max_hp": 6, "atk": 1, "def": 0, "spd": 110}, "essences": {"spore": 3, "flight": 2}, "skills": [], "drifter": true, "eat_bonus": {"stat": "max_mp", "amount": 2, "per": 1}, "xp": 8})`; the `pale_moth` clip table is a copy of the moth's; `PORTRAIT_FRAME` gains `"pale_moth": "fly_1"`. Update `test_content` (creatures 10) and `test_constants`. Regenerate content, import.
  - Rooms: G3 gets `_exit("left", 200, 320, "G5", {"gate": "wall_cling"})`; G5 (`"area": "grotto"`, cell (7,7), size (1,1)) gets `_exit("right", 200, 320, "G3", {"gate": "wall_cling"})`, one `pale_moth` spawn at (320, 200), dressing and glow decor. In G3, the opening is on the west wall at local y 200–320; build the chimney inside G3 at x 20–120 on the west side: two solids, left `Rect2(60, 20, 16, 340)` and right `Rect2(104, 20, 16, 340)`?? That blocks the wall-cling route: the chimney is a paired-wall shaft of width 28+ (C2's is x 280–400: two walls 16 wide 104 apart), so use C2's proportions: `Rect2(24, 20, 16, 220)` and `Rect2(128, 20, 16, 220)` hung from G3's ceiling (y 20–240) with the opening's lower lip at y 320 → the walls end at y 240, which is above the lip: `T` requires the walls to extend to at least `320 + T` = 417 below the lip? No: "at least T px below the opening's lower lip" means the walls hang past the lip downward to y ≥ 320 + 96.8; so use `Rect2(24, 20, 16, 400)` and `Rect2(128, 20, 16, 400)` (to y 420 ≥ 417). The chimney floor at y 420 is a ledge `Rect2(24, 420, 120, 12)` reachable from G3's floor by base jumps? Floor top 680 to 420 is 260: add a short climb of ledges from the floor at x 160–320's column? That column is the west chain (x 160–320): the chain's ledges at y 62..634 already pass y 426 and y 478: the ledge at y 426 (i = 7: 10 + 52×7 = 374; i = 8: 426) x 160–250 sits 20 px east of the chimney wall at x 128–144: within GAP 60 of the chimney floor ledge at y 420 (same level): the chain reaches the chimney floor: fine, the player walks into the chimney from the chain, then wall-jumps up the paired walls to the opening (Wall Cling), which is exactly the gate. Recheck the `_hop` clearance test: the opening's sill (local y 320) must not be reachable by base jumps from any surface: the chimney floor at 420 is 100 px below the sill (rise 100 > 55), and the chain's ledge at 322 (i = 6: 10 + 312 = 322) x 160–250 is 12 px below the sill and 60 px east of the wall at 144 but the wall (x 128–144, y 20–420) is in the way: the opening at x 0–20 (west wall, y 200–320) is beyond the paired walls, screened. Adjust the chain's west offset if a ledge sits within reach: the test decides.
  - Regenerate rooms, import.
- [ ] **Step 4: Run** the slice tests and the full suite → green.
- [ ] **Step 5: Commit** `feat: the Pale Moth (a derived lightened, enlarged sheet) and its wall-cling room G5`.

---

### Task 9: Real-game check, review, the gate and the merge

- [ ] **Step 1: Screenshots (windowed, real).** Use the evolution plan's screenshot approach (`tools/` scripts or `godot --path . -- --room=<id>` if one exists; find it: `ls tools | grep -i shot`, `grep -rn screenshot tools`). Capture and LOOK at: G1, G2, G3, G4, G5, each new creature in its room (moth with a puff, crab mid-charge, snake coiled and lunging), the map tab, and the menu with two pools attuned. Fix anything that reads wrong (dressing over the C5 hole, snakes floating, the pale moth not pale, overlapping menu text). Save images under `docs/` only if the earlier plans did; otherwise `.tmp/`.
- [ ] **Step 2: Playtest-checklist lines** in `docs/playtest-checklist.md`: drop into the Grotto and climb back; a moth's puff and its flash; a crab front tackle hurts but does not stun; a snake lunges when passed under and returns; Spore Cloud slows and poisons; Hardened Shell reduces knockback; die with G1 attuned and choose in the menu; the first evolution lands in G4; the Pale Moth needs Wall Cling; update the line at `:66` that says dying "lets you choose" now that the menu exists.
- [ ] **Step 3: Audio** — confirm `spore_puff` (and any menu cue) are covered; `test_audio_boundary` green.
- [ ] **Step 4: Final whole-branch review.** `../subagent-driven-development/scripts/review-package` (per executing-plans) then one fresh opus reviewer with the spec, this plan, the Review Focus above verbatim and the ledger's Rulings. Re-grade, one fix pass test-first, minors to the ledger.
- [ ] **Step 5: Gate and merge.** Full suite green on the branch; merge `feat/grotto` into `main` (resolve conflicts with anything the audio session pushed; run the suite on the merged tree), push, remove the worktree `.worktrees/grotto` and delete the branch, launch the game from `main`.
