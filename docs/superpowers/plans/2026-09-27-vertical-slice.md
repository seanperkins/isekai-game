# Vertical Slice (Plan 2 of 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the slime playable in one hand-built test room:
- movement, jumping and wall cling, with edge-triggered events;
- HP, damage math and the low-HP bands;
- data-driven enemies that have stats, use skills, can be stunned or downed, and can be eaten;
- water pools;
- predation with essence absorption and eat bonuses;
- passive skill effects;
- two active slots with Cycle, and working player abilities;
- Appraisal inspect;
- a HUD with Great Sage pop-ups, a ticker and a status screen;
- death, which reloads a fresh run.

**Architecture:** Game rules live in pure `RefCounted` classes that GUT tests headless:
- `Health`, `PlayerSensors`, `PredationHold`, `EnemyStatus`, `ActiveSlots`, `PlayerSkillSet`, `SkillEffects`, `StatusText`.

Scene scripts are thin layers over them:
- `Player`, `Enemy`, `WaterPool`, `Ability` and its subclasses, `Hud`, `Game`.

Nodes are built in code rather than hand-authored `.tscn` geometry, so every scene is reproducible from its script. Only the player emits to `EventBus`; enemies' `Health` has no emitter (the actor boundary).

**Tech Stack:** Godot 4.7 (GDScript), GUT 9.7.1, and `tools/run_tests.sh` (from Plan 1).

**Spec:** `docs/superpowers/specs/2026-09-27-slime-prototype-design.md`
**Builds on:** Plan 1 (`docs/superpowers/plans/2026-09-27-skill-engine-core.md`), merged to `main` at `ebb8f20`.

## Global Constraints

Everything in Plan 1's Global Constraints still holds. That includes: String ids everywhere, tests run only through `tools/run_tests.sh`, re-import after each new `class_name`, and no `push_error` in tested paths.

- **Actor boundary.** Only the player emits gameplay events.
  - `Health.emit_event` is set only on the player, and `PlayerSensors` exists only on the player.
  - Enemy code never touches `EventBus`.
  - Player-owned abilities emit nothing themselves; the player emits `skill_used` when activation succeeds.
- **Player base stats:** HP 30, ATK 1, DEF 0, SPD 100. An eat heals 5 HP, capped at max HP.
- **Timers:**
  - Stun lasts 2 s and downed lasts 5 s. Both timers pause while a predate hold is active.
  - Predate hold is 1.0 s × `predation_time` / 100.
  - Invulnerability after a direct hit is 0.6 s.
  - Ability cooldown is 0.8 s.
- **HP bands:**
  - `hp_low_entered` fires when `hp*100 < max_hp*30`, only while not already latched.
  - `hp_low_exited` fires when `hp*100 >= max_hp*60`, only after an entry.
  - Bands are re-evaluated whenever HP or max HP changes. Raising max HP doesn't raise current HP.
- **Damage:**
  - Direct hits use `Damage.direct_hit(raw, percent_off, flat_off + DEF)`.
  - Poison ticks use `Damage.tick(raw, percent_off)` and can't take HP below 1. Ticks never emit `damaged`.
  - The poison-spit application is a direct hit, so it emits `damaged{damage_type: poison}` and can kill.
- **Downed:**
  - An enemy at 0 HP is downed, not removed. It can be eaten without a stun for 5 s, then vanishes.
  - A downed enemy runs no AI and deals no contact damage.
  - A tackle that downs an enemy emits `stunned_enemy`.
  - The serpent can't be stunned.
- **Lizard:** a tackle only stuns it from behind, meaning the lizard's `facing` equals the player's `facing`.
- **Controls** are registered at runtime by the `Controls` autoload:
  - move: A/D or ←/→
  - `jump`: Space, W or ↑
  - `tackle`: J
  - `predate`: K (hold)
  - `inspect`: I
  - `active_1`: U, `active_2`: O
  - `cycle`: Tab
- **Plan 3, not here:** the enemy-only abilities as scenes (Tail Swipe, Constrict, a Poison Spit projectile), room generation, the boss fight, the Compendium screen, the run log, and the death screen. In this plan the toad's spit is an instant ranged poison hit applied by the toad's script. Death reloads the scene.

## Review Focus

1. **The player dies while holding Predate on a target.** The target must be released (`set_held(false)`) so its timer isn't frozen forever, and no events may fire from a dead player. *Task 10.*
2. **The eat target is freed mid-hold** (its downed timer expired, or another code path freed it). `process_predate` must cancel cleanly and never touch a freed object. *Task 10.*
3. **An active is used whose scene fails to load.** This can't happen with validated content, but `use_active` must return without emitting `skill_used` if the ability node is missing. *Task 10.*
4. **Max HP drops below current HP.** It can't drop in a run, but `set_max_hp` must clamp HP and re-evaluate bands, never leaving HP above max. *Task 3.*
5. **Inspect with nothing in range and Appraisal at Lv1.** It must still emit `inspected{self}` and produce a report, without calling Compendium with an empty source. *Task 10.*

---

## File Structure

```
autoload/controls.gd                   # Controls: input actions at runtime
scripts/core/skill_effects.gd          # SkillEffects: effect math shared by player and enemies
scripts/actors/health.gd               # Health: HP, bands, damage/tick/heal, optional emitter
scripts/player/player_sensors.gd       # PlayerSensors: wall_touched edge, jumped, inspected first_time
scripts/player/predation_hold.gd       # PredationHold: hold timer toward an eat target
scripts/player/active_slots.gd         # ActiveSlots: 2 slots, LRU, Cycle
scripts/player/player_skill_set.gd     # PlayerSkillSet: owned skills -> stats, capabilities, slots, damage mods, triggers
scripts/player/player.gd               # Player (CharacterBody2D)
scripts/enemies/enemy_status.gd        # EnemyStatus: active/stunned/downed/gone timers
scripts/enemies/enemy.gd               # Enemy (CharacterBody2D) from a CreatureDef
scripts/world/water_pool.gd            # WaterPool: single-use terrain eat target
scripts/world/room_layout.gd           # RoomLayout: the test room as data
scripts/world/room_builder.gd          # RoomBuilder: solids from layout
scripts/abilities/ability.gd           # Ability base (cooldown, targeting, team)
scripts/abilities/*.gd                 # six player actives
scripts/ui/status_text.gd              # StatusText: pure text for status screen/HUD
scripts/ui/hud.gd                      # Hud (CanvasLayer)
scripts/game.gd                        # Game: builds the room, spawns, starts run, reloads on death
scenes/main.tscn                       # main scene (Game)
scenes/abilities/{poison_breath,sticky_thread,hydraulic_propulsion,water_blade,swing_thread,jet_dash}.tscn  # now scripted
Modified: scripts/stats/stats.gd (+clear_modifiers, base, skill_bonus), scripts/skills/skill_rules_engine.gd (+count), project.godot (Controls autoload, main scene)
```

---

### Task 1: Engine and Stats accessors, and the Controls autoload

**Files:**
- Modify: `scripts/skills/skill_rules_engine.gd`, `scripts/stats/stats.gd`, `project.godot`
- Create: `autoload/controls.gd`
- Test: `tests/test_accessors.gd`

**Interfaces:**
- Produces:
  - `SkillRulesEngine.count(event_name: String, tags: Dictionary = {}) -> int`
  - `Stats.clear_modifiers()`, `Stats.base(key) -> int`, `Stats.skill_bonus(key) -> int`. The skill bonus is the final value minus base minus eat bonus.
  - The `Controls` autoload, with `ensure_actions()` and `BINDINGS`.

- [ ] **Step 1: Write the failing test, `tests/test_accessors.gd`**

```gdscript
extends GutTest

func test_engine_count_reads_this_runs_ledger() -> void:
	var e: SkillRulesEngine = autofree(SkillRulesEngine.new())
	e.setup([])
	e.start_run()
	e.handle_event("absorbed", {"essence": "poison", "source": "toad"})
	e.handle_event("absorbed", {"essence": "water", "source": "toad"})
	assert_eq(e.count("absorbed", {"essence": "poison"}), 1)
	assert_eq(e.count("absorbed"), 2)
	e.reset_run()
	assert_eq(e.count("absorbed"), 0)

func test_stats_split_base_eat_and_skill() -> void:
	var s := Stats.new({"def": 1})
	s.apply_eat(TestDefs.creature("lizard", {"eat_bonus": {"stat": "def", "amount": 1, "per": 1}}))
	s.set_modifiers("body_armor", [{"stat": "def", "op": "add", "value": 2}])
	assert_eq(s.get_stat("def"), 4)
	assert_eq(s.base("def"), 1)
	assert_eq(s.eat_bonus("def"), 1)
	assert_eq(s.skill_bonus("def"), 2)
	s.clear_modifiers()
	assert_eq(s.get_stat("def"), 2)
	assert_eq(s.eat_bonus("def"), 1)

func test_controls_register_every_action() -> void:
	Controls.ensure_actions()
	for action in ["move_left", "move_right", "jump", "tackle", "predate", "inspect", "active_1", "active_2", "cycle"]:
		assert_true(InputMap.has_action(action), action)
		assert_gt(InputMap.action_get_events(action).size(), 0, action)
	Controls.ensure_actions()  # idempotent
	assert_eq(InputMap.action_get_events("tackle").size(), 1)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh accessors`
Expected: FAIL (a Parse Error because the `Controls` identifier isn't declared, or because `count` doesn't exist).

- [ ] **Step 3: Implement the accessors and the autoload**

Add this to `scripts/skills/skill_rules_engine.gd`, after `get_def`:

```gdscript
## Events of this run matching `tags` (superset match), e.g. essence totals for the status screen.
func count(event_name: String, tags: Dictionary = {}) -> int:
	return _ledger.counter(event_name, tags)
```

Add this to `scripts/stats/stats.gd`, after `eat_bonus`:

```gdscript
func base(key: String) -> int:
	return int(_base.get(key, 0))

## The part of get_stat() that comes from skill modifiers (for the status screen split).
func skill_bonus(key: String) -> int:
	return get_stat(key) - base(key) - eat_bonus(key)

func clear_modifiers() -> void:
	_mods.clear()
```

Create `autoload/controls.gd`:

```gdscript
extends Node
## Registers input actions at startup so project.godot stays readable. Idempotent.

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"tackle": [KEY_J],
	"predate": [KEY_K],
	"inspect": [KEY_I],
	"active_1": [KEY_U],
	"active_2": [KEY_O],
	"cycle": [KEY_TAB],
}

func _ready() -> void:
	ensure_actions()

func ensure_actions() -> void:
	for action in BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
```

In `project.godot`, add this as the **first** line under `[autoload]`:

```ini
Controls="*res://autoload/controls.gd"
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh accessors`
Expected: `PASS: 3 tests`.

- [ ] **Step 5: Run the full suite, then commit**

Run: `tools/run_tests.sh`. Expected: `PASS: 102 tests`.

```bash
git add scripts/skills/skill_rules_engine.gd scripts/stats/stats.gd autoload/controls.gd project.godot tests/test_accessors.gd
git commit -m "feat: add ledger count, stat split accessors and runtime controls"
```

---

### Task 2: SkillEffects — the effect math shared by player and enemies

**Files:**
- Create: `scripts/core/skill_effects.gd`
- Test: `tests/test_skill_effects.gd`

**Interfaces:**
- Produces: `SkillEffects`, with these static methods:
  - `value_at(effect: Dictionary, level: int)` returns the value for that level, clamped, or 0 when there are no values.
  - `stat_modifiers(def: SkillDef, level: int) -> Array` returns `[{"stat", "op", "value"}]`, only for `StatKeys` targets.
  - `capabilities(def, level) -> Dictionary` maps each flag to its level, respecting `min_level`.
  - `damage_reduction(pairs: Array, damage_type: String, hp: int, max_hp: int) -> Dictionary` returns `{"percent_off", "flat_off"}`. `pairs` is `[[SkillDef, level], ...]`.
  - `active_scene(def) -> String`, which is `""` when the skill has no active effect.
  - `active_values(def) -> Array`

- [ ] **Step 1: Write the failing test, `tests/test_skill_effects.gd`**

```gdscript
extends GutTest

var skills := {}

func before_all() -> void:
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func test_value_at_clamps_level_and_defaults_to_zero() -> void:
	var e := {"kind": "modifier", "stat": "def", "op": "add", "values": [1, 2, 3]}
	assert_eq(SkillEffects.value_at(e, 1), 1)
	assert_eq(SkillEffects.value_at(e, 3), 3)
	assert_eq(SkillEffects.value_at(e, 9), 3)
	assert_eq(SkillEffects.value_at({"kind": "active"}, 2), 0)

func test_stat_modifiers_skip_damage_taken() -> void:
	assert_eq(SkillEffects.stat_modifiers(skills["leap"], 2), [{"stat": "jump_height", "op": "add", "value": 15}])
	assert_eq(SkillEffects.stat_modifiers(skills["poison_resistance"], 1), [])
	assert_eq(SkillEffects.stat_modifiers(skills["regeneration"], 1), [{"stat": "regen_interval", "op": "set", "value": 8}])

func test_capabilities_include_compound_effects() -> void:
	assert_eq(SkillEffects.capabilities(skills["wall_cling"], 2), {"wall_cling": 2})
	assert_eq(SkillEffects.stat_modifiers(skills["wall_cling"], 2), [{"stat": "slide_speed", "op": "add", "value": -45}])
	var gated := TestDefs.skill("g", {"effects": [{"kind": "capability", "flag": "x", "min_level": 2}]})
	assert_eq(SkillEffects.capabilities(gated, 1), {})
	assert_eq(SkillEffects.capabilities(gated, 2), {"x": 2})

func test_damage_reduction_scope_and_condition() -> void:
	var pairs := [[skills["poison_resistance"], 2], [skills["pain_resistance"], 3]]
	assert_eq(SkillEffects.damage_reduction(pairs, "poison", 30, 30), {"percent_off": 35, "flat_off": 0})
	assert_eq(SkillEffects.damage_reduction(pairs, "physical", 30, 30), {"percent_off": 0, "flat_off": 0})
	assert_eq(SkillEffects.damage_reduction(pairs, "physical", 8, 30), {"percent_off": 0, "flat_off": 3})
	assert_eq(SkillEffects.damage_reduction(pairs, "physical", 9, 30), {"percent_off": 0, "flat_off": 0})

func test_active_scene_and_values() -> void:
	assert_eq(SkillEffects.active_scene(skills["poison_breath"]), "res://scenes/abilities/poison_breath.tscn")
	assert_eq(SkillEffects.active_values(skills["poison_breath"]), [2, 3, 4, 5, 6])
	assert_eq(SkillEffects.active_scene(skills["leap"]), "")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh skill_effects`
Expected: FAIL (a Parse Error because `SkillEffects` isn't declared).

- [ ] **Step 3: Implement `scripts/core/skill_effects.gd`**

```gdscript
class_name SkillEffects
extends RefCounted
## Effect math shared by the player's and enemies' skill sets. Pure functions over SkillDefs.

const DAMAGE_TAKEN := "damage_taken"

static func value_at(effect: Dictionary, level: int):
	var values: Array = effect.get("values", [])
	if values.is_empty():
		return 0
	return values[clampi(level, 1, values.size()) - 1]

static func stat_modifiers(def: SkillDef, level: int) -> Array:
	var out: Array = []
	for e in def.effects:
		if e.get("kind", "") == "modifier" and StatKeys.ALL.has(e.get("stat", "")):
			out.append({"stat": e["stat"], "op": e.get("op", "add"), "value": int(value_at(e, level))})
	return out

static func capabilities(def: SkillDef, level: int) -> Dictionary:
	var out := {}
	for e in def.effects:
		if e.get("kind", "") == "capability" and level >= int(e.get("min_level", 1)):
			out[e["flag"]] = level
	return out

## Incoming-damage reductions from owned skills. pairs = [[SkillDef, level], ...].
static func damage_reduction(pairs: Array, damage_type: String, hp: int, max_hp: int) -> Dictionary:
	var percent := 0
	var flat := 0
	for pair in pairs:
		var d: SkillDef = pair[0]
		var level: int = pair[1]
		for e in d.effects:
			if e.get("stat", "") != DAMAGE_TAKEN:
				continue
			var kind: String = e.get("kind", "")
			if kind == "conditional_modifier":
				var cond: Dictionary = e.get("condition", {})
				if cond.has("hp_below_percent") and not (hp * 100 < max_hp * int(cond["hp_below_percent"])):
					continue
			elif kind != "modifier":
				continue
			var scope: Dictionary = e.get("scope", {})
			if scope.has("damage_type") and scope["damage_type"] != damage_type:
				continue
			var v := int(value_at(e, level))
			match e.get("op", ""):
				"percent_off":
					percent += v
				"flat_off":
					flat += v
	return {"percent_off": mini(percent, 100), "flat_off": flat}

static func active_scene(def: SkillDef) -> String:
	for e in def.effects:
		if e.get("kind", "") == "active":
			return e.get("scene", "")
	return ""

static func active_values(def: SkillDef) -> Array:
	for e in def.effects:
		if e.get("kind", "") == "active":
			return e.get("values", [])
	return []
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh skill_effects`
Expected: `PASS: 5 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/skill_effects.gd tests/test_skill_effects.gd
git commit -m "feat: add shared skill effect math"
```

---

### Task 3: Health — HP, damage, ticks, bands and the actor boundary

**Files:**
- Create: `scripts/actors/health.gd`
- Test: `tests/test_health.gd`

**Interfaces:**
- Produces: `Health` (a `RefCounted`).
  - Signals: `changed(hp: int, max_hp: int)` and `died`.
  - Vars: `hp`, `max_hp`, and `emit_event: Callable`. The emitter is invalid by default, so nothing is emitted.
  - Methods:
    - `_init(p_max_hp: int)`
    - `take_hit(amount: int, damage_type: String)` emits `damaged` once, then updates the bands.
    - `take_tick(amount: int)` never goes below 1 HP and never emits `damaged`.
    - `heal(amount: int)`, `set_max_hp(value: int)`
    - `is_dead() -> bool`, `is_low() -> bool`

- [ ] **Step 1: Write the failing test, `tests/test_health.gd`**

```gdscript
extends GutTest

var events: Array
var h: Health

func before_each() -> void:
	events = []
	h = Health.new(30)
	h.emit_event = func(n: String, t: Dictionary) -> void: events.append([n, t])

func _names() -> Array:
	return events.map(func(e): return e[0])

func test_hit_reduces_hp_and_emits_damaged_once() -> void:
	h.take_hit(3, "physical")
	assert_eq(h.hp, 27)
	assert_eq(events, [["damaged", {"damage_type": "physical"}]])

func test_low_band_enters_below_30_percent_only_once() -> void:
	h.take_hit(21, "physical")  # 9: not below 30% of 30
	assert_false(_names().has("hp_low_entered"))
	h.take_hit(1, "physical")   # 8
	h.take_hit(1, "physical")   # 7, still latched
	assert_eq(_names().count("hp_low_entered"), 1)

func test_low_band_exits_at_60_percent_after_entry() -> void:
	h.take_hit(22, "physical")  # 8 -> entered
	h.heal(9)                   # 17: not yet
	assert_false(_names().has("hp_low_exited"))
	h.heal(1)                   # 18 = 60%
	assert_eq(_names().count("hp_low_exited"), 1)
	h.heal(5)
	assert_eq(_names().count("hp_low_exited"), 1)

func test_exit_requires_prior_entry() -> void:
	h.take_hit(5, "physical")
	h.heal(5)
	assert_false(_names().has("hp_low_exited"))

func test_raising_max_hp_re_evaluates_bands_without_healing() -> void:
	h.take_hit(21, "physical")  # 9 of 30: not low
	h.set_max_hp(33)            # 9 of 33 is below 30% (9.9)
	assert_eq(h.hp, 9)
	assert_eq(_names().count("hp_low_entered"), 1)

func test_lowering_max_hp_clamps_hp() -> void:
	# Review Focus 4
	h.set_max_hp(20)
	assert_eq(h.hp, 20)
	assert_eq(h.max_hp, 20)

func test_ticks_floor_at_one_and_never_emit_damaged() -> void:
	h.take_hit(27, "poison")  # 3
	events.clear()
	h.take_tick(2)
	h.take_tick(2)
	assert_eq(h.hp, 1)
	assert_false(_names().has("damaged"))
	assert_false(h.is_dead())

func test_death_emits_died_once_and_ignores_further_changes() -> void:
	var deaths := [0]
	h.died.connect(func() -> void: deaths[0] += 1)
	h.take_hit(40, "physical")
	h.take_hit(5, "physical")
	h.heal(10)
	assert_eq(h.hp, 0)
	assert_true(h.is_dead())
	assert_eq(deaths[0], 1)

func test_heal_caps_at_max() -> void:
	h.take_hit(4, "physical")
	h.heal(99)
	assert_eq(h.hp, 30)

func test_no_emitter_means_no_events() -> void:
	var enemy_health := Health.new(5)
	enemy_health.take_hit(4, "physical")
	enemy_health.heal(1)
	assert_eq(enemy_health.hp, 2)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh health`
Expected: FAIL (a Parse Error because `Health` isn't declared).

- [ ] **Step 3: Implement `scripts/actors/health.gd`**

```gdscript
class_name Health
extends RefCounted
## HP with low-HP bands. Emits gameplay events only when emit_event is set, which only
## the player does (actor boundary). DoT ticks never emit and never take HP below 1.

signal changed(hp: int, max_hp: int)
signal died

const LOW_ENTER_PERCENT := 30
const LOW_EXIT_PERCENT := 60

var hp: int
var max_hp: int
var emit_event: Callable = Callable()
var _low := false
var _dead := false

func _init(p_max_hp: int) -> void:
	max_hp = maxi(1, p_max_hp)
	hp = max_hp

func take_hit(amount: int, damage_type: String) -> void:
	if _dead:
		return
	hp = maxi(0, hp - amount)
	_emit(Events.DAMAGED, {"damage_type": damage_type})
	_after_change()

func take_tick(amount: int) -> void:
	if _dead:
		return
	hp = maxi(mini(hp, 1), hp - amount)
	_after_change()

func heal(amount: int) -> void:
	if _dead:
		return
	hp = mini(max_hp, hp + amount)
	_after_change()

func set_max_hp(value: int) -> void:
	max_hp = maxi(1, value)
	hp = mini(hp, max_hp)
	_after_change()

func is_dead() -> bool:
	return _dead

func is_low() -> bool:
	return _low

func _after_change() -> void:
	if hp > 0:
		if not _low and hp * 100 < max_hp * LOW_ENTER_PERCENT:
			_low = true
			_emit(Events.HP_LOW_ENTERED, {})
		elif _low and hp * 100 >= max_hp * LOW_EXIT_PERCENT:
			_low = false
			_emit(Events.HP_LOW_EXITED, {})
	changed.emit(hp, max_hp)
	if hp <= 0 and not _dead:
		_dead = true
		died.emit()

func _emit(event_name: String, tags: Dictionary) -> void:
	if emit_event.is_valid():
		emit_event.call(event_name, tags)
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh health`
Expected: `PASS: 10 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/actors/health.gd tests/test_health.gd
git commit -m "feat: add health with low-HP bands and the actor-boundary emitter"
```

---

### Task 4: PlayerSensors, PredationHold and EnemyStatus

**Files:**
- Create: `scripts/player/player_sensors.gd`, `scripts/player/predation_hold.gd`, `scripts/enemies/enemy_status.gd`
- Test: `tests/test_sensors_and_timers.gd`

**Interfaces:**
- Produces:
  - `PlayerSensors`, with `emit_event: Callable`, `physics_update(on_wall: bool, on_floor: bool)`, `jumped(from: String)` and `inspected(target: String, appraisal_target: bool)`.
  - `PredationHold`, with:
    - `start(target: Object, predation_time_percent: int)`
    - `update(delta) -> bool`, which returns true once complete
    - `cancel()`, `active() -> bool`, `target`
  - `EnemyStatus`:
    - consts `ACTIVE=0`, `STUNNED=1`, `DOWNED=2`, `GONE=3`, `STUN_SECONDS=2.0`, `DOWNED_SECONDS=5.0`
    - vars `state` and `held`
    - methods `stun(seconds := STUN_SECONDS)`, `down()`, `consume()`, `update(delta)`, `predatable() -> bool`

- [ ] **Step 1: Write the failing test, `tests/test_sensors_and_timers.gd`**

```gdscript
extends GutTest

var events: Array
var sensors: PlayerSensors

func before_each() -> void:
	events = []
	sensors = PlayerSensors.new()
	sensors.emit_event = func(n: String, t: Dictionary) -> void: events.append([n, t])

func test_wall_touched_fires_once_per_airborne_contact() -> void:
	sensors.physics_update(true, false)
	sensors.physics_update(true, false)
	sensors.physics_update(true, false)
	sensors.physics_update(false, false)
	sensors.physics_update(true, false)
	assert_eq(events.size(), 2)
	assert_eq(events[0], ["wall_touched", {}])

func test_wall_contact_on_the_floor_does_not_count() -> void:
	sensors.physics_update(true, true)
	sensors.physics_update(true, false)  # still the same contact, now airborne: no new edge
	assert_eq(events.size(), 0)

func test_jumped_and_inspected_first_time() -> void:
	sensors.jumped("ground")
	sensors.inspected("bat", true)
	sensors.inspected("bat", true)
	sensors.inspected("serpent", false)
	assert_eq(events[0], ["jumped", {"from": "ground"}])
	assert_eq(events[1], ["inspected", {"target": "bat", "first_time": true, "appraisal_target": true}])
	assert_eq(events[2][1]["first_time"], false)
	assert_eq(events[3][1], {"target": "serpent", "first_time": true, "appraisal_target": false})

func test_predation_hold_scales_with_predation_time() -> void:
	var hold := PredationHold.new()
	var target := RefCounted.new()
	hold.start(target, 70)  # Glutton Lv1: 0.7 s
	assert_false(hold.update(0.6))
	assert_true(hold.update(0.1))
	hold.cancel()
	assert_false(hold.active())
	assert_false(hold.update(5.0))

func test_stun_then_recover() -> void:
	var s := EnemyStatus.new()
	s.stun()
	assert_true(s.predatable())
	s.update(1.9)
	assert_eq(s.state, EnemyStatus.STUNNED)
	s.update(0.2)
	assert_eq(s.state, EnemyStatus.ACTIVE)
	assert_false(s.predatable())

func test_downed_vanishes_after_five_seconds_and_hold_pauses_it() -> void:
	var s := EnemyStatus.new()
	s.down()
	s.update(4.0)
	s.held = true
	s.update(10.0)
	assert_eq(s.state, EnemyStatus.DOWNED)
	s.held = false  # a cancelled hold keeps the remaining 1 s
	s.update(0.9)
	assert_eq(s.state, EnemyStatus.DOWNED)
	s.update(0.2)
	assert_eq(s.state, EnemyStatus.GONE)

func test_stun_never_overrides_downed_or_gone() -> void:
	var s := EnemyStatus.new()
	s.down()
	s.stun()
	assert_eq(s.state, EnemyStatus.DOWNED)
	s.consume()
	s.stun()
	s.down()
	assert_eq(s.state, EnemyStatus.GONE)
	assert_false(s.predatable())
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh sensors_and_timers`
Expected: FAIL (a Parse Error because `PlayerSensors` isn't declared).

- [ ] **Step 3: Implement the three classes**

`scripts/player/player_sensors.gd`:

```gdscript
class_name PlayerSensors
extends RefCounted
## Edge-triggered player event emitters. Only the player owns one (actor boundary).

var emit_event: Callable = Callable()
var _was_on_wall := false
var _inspected := {}

## wall_touched fires when is_on_wall() goes false -> true while airborne.
func physics_update(on_wall: bool, on_floor: bool) -> void:
	if on_wall and not _was_on_wall and not on_floor:
		_emit(Events.WALL_TOUCHED, {})
	_was_on_wall = on_wall

func jumped(from: String) -> void:
	_emit(Events.JUMPED, {"from": from})

func inspected(target: String, appraisal_target: bool) -> void:
	var first := not _inspected.has(target)
	_inspected[target] = true
	_emit(Events.INSPECTED, {"target": target, "first_time": first, "appraisal_target": appraisal_target})

func _emit(event_name: String, tags: Dictionary) -> void:
	if emit_event.is_valid():
		emit_event.call(event_name, tags)
```

`scripts/player/predation_hold.gd`:

```gdscript
class_name PredationHold
extends RefCounted
## Hold-to-eat timer. Base 1 s, scaled by the predation_time stat (percent of base).

const BASE_SECONDS := 1.0

var target: Object = null
var _elapsed := 0.0
var _required := BASE_SECONDS

func start(p_target: Object, predation_time_percent: int) -> void:
	target = p_target
	_elapsed = 0.0
	_required = BASE_SECONDS * predation_time_percent / 100.0

func update(delta: float) -> bool:
	if target == null:
		return false
	_elapsed += delta
	return _elapsed >= _required - 0.0001

func cancel() -> void:
	target = null
	_elapsed = 0.0

func active() -> bool:
	return target != null
```

`scripts/enemies/enemy_status.gd`:

```gdscript
class_name EnemyStatus
extends RefCounted
## Enemy condition timers. Stun and downed timers pause while `held` (a predate hold).

const ACTIVE := 0
const STUNNED := 1
const DOWNED := 2
const GONE := 3
const STUN_SECONDS := 2.0
const DOWNED_SECONDS := 5.0

var state := ACTIVE
var held := false
var _timer := 0.0

func stun(seconds: float = STUN_SECONDS) -> void:
	if state == ACTIVE or state == STUNNED:
		state = STUNNED
		_timer = seconds

func down() -> void:
	if state != GONE:
		state = DOWNED
		_timer = DOWNED_SECONDS

func consume() -> void:
	state = GONE

func predatable() -> bool:
	return state == STUNNED or state == DOWNED

func update(delta: float) -> void:
	if held or state == ACTIVE or state == GONE:
		return
	_timer -= delta
	if _timer <= 0.0:
		state = ACTIVE if state == STUNNED else GONE
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh sensors_and_timers`
Expected: `PASS: 7 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player_sensors.gd scripts/player/predation_hold.gd scripts/enemies/enemy_status.gd tests/test_sensors_and_timers.gd
git commit -m "feat: add edge-triggered player sensors, predation hold and enemy status timers"
```

---

### Task 5: ActiveSlots — two slots, LRU and Cycle

**Files:**
- Create: `scripts/player/active_slots.gd`
- Test: `tests/test_active_slots.gd`

**Interfaces:**
- Produces: `ActiveSlots` (a `RefCounted`).
  - Signal: `slot_replaced(new_id: String, old_id: String)`
  - Vars: `slots: Array` (two entries; `""` means empty), `owned: Array` and `last_used: int`
  - Methods: `add(id)`, `use(i: int) -> String`, `cycle()`, `reset()`

- [ ] **Step 1: Write the failing test, `tests/test_active_slots.gd`**

```gdscript
extends GutTest

var s: ActiveSlots
var replaced: Array

func before_each() -> void:
	s = ActiveSlots.new()
	replaced = []
	s.slot_replaced.connect(func(n: String, o: String) -> void: replaced.append([n, o]))

func test_new_actives_fill_empty_slots_first() -> void:
	s.add("a")
	s.add("b")
	assert_eq(s.slots, ["a", "b"])
	assert_eq(replaced, [])

func test_third_active_replaces_least_recently_used() -> void:
	s.add("a")
	s.add("b")
	s.use(0)  # a is now more recent than b
	s.add("c")
	assert_eq(s.slots, ["a", "c"])
	assert_eq(replaced, [["c", "b"]])
	assert_eq(s.owned, ["a", "b", "c"])

func test_adding_an_owned_id_again_is_ignored() -> void:
	s.add("a")
	s.add("a")
	assert_eq(s.slots, ["a", ""])

func test_use_returns_id_and_sets_last_used() -> void:
	s.add("a")
	s.add("b")
	assert_eq(s.use(1), "b")
	assert_eq(s.last_used, 1)
	var empty := ActiveSlots.new()
	assert_eq(empty.use(0), "")

func test_cycle_rotates_last_used_slot_without_duplicates() -> void:
	for id in ["a", "b", "c"]:
		s.add(id)  # c replaces a (the LRU): slots [c, b]
	s.slots = ["a", "b"]  # arrange a known layout; owned is still [a, b, c]
	s.use(0)
	s.cycle()
	assert_eq(s.slots, ["c", "b"])
	s.cycle()
	assert_eq(s.slots, ["a", "b"])  # never puts b in both slots

func test_cycle_is_a_no_op_with_zero_or_one_owned() -> void:
	s.cycle()
	assert_eq(s.slots, ["", ""])
	s.add("a")
	s.cycle()
	assert_eq(s.slots, ["a", ""])

func test_cycle_brings_back_an_evicted_active() -> void:
	s.add("hydraulic_propulsion")
	s.add("poison_breath")
	s.use(1)
	s.add("water_blade")  # evicts hydraulic (LRU)
	assert_false(s.slots.has("hydraulic_propulsion"))
	s.use(0)
	s.cycle()
	assert_true(s.slots.has("hydraulic_propulsion"))

func test_reset_clears_everything() -> void:
	s.add("a")
	s.reset()
	assert_eq(s.slots, ["", ""])
	assert_eq(s.owned, [])
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh active_slots`
Expected: FAIL (a Parse Error because `ActiveSlots` isn't declared).

- [ ] **Step 3: Implement `scripts/player/active_slots.gd`**

```gdscript
class_name ActiveSlots
extends RefCounted
## Two active-skill slots. A new active fills an empty slot, else replaces the least
## recently used one. Cycle rotates the last-used slot through owned actives that are not
## in the other slot; it updates the LRU stamp only and never counts as using a skill.

signal slot_replaced(new_id: String, old_id: String)

var slots: Array = ["", ""]
var owned: Array = []
var last_used := 0
var _stamps: Array = [0, 0]
var _clock := 0

func add(id: String) -> void:
	if owned.has(id):
		return
	owned.append(id)
	for i in 2:
		if slots[i] == "":
			slots[i] = id
			_touch(i)
			return
	var lru := 0 if _stamps[0] <= _stamps[1] else 1
	var old: String = slots[lru]
	slots[lru] = id
	_touch(lru)
	slot_replaced.emit(id, old)

func use(i: int) -> String:
	if slots[i] == "":
		return ""
	last_used = i
	_touch(i)
	return slots[i]

func cycle() -> void:
	var other: String = slots[1 - last_used]
	var candidates := owned.filter(func(x): return x != other)
	if candidates.is_empty():
		return
	var current := candidates.find(slots[last_used])
	var next: String = candidates[(current + 1) % candidates.size()]
	if next == slots[last_used]:
		return
	slots[last_used] = next
	_touch(last_used)

func reset() -> void:
	slots = ["", ""]
	owned = []
	last_used = 0
	_stamps = [0, 0]
	_clock = 0

func _touch(i: int) -> void:
	_clock += 1
	_stamps[i] = _clock
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh active_slots`
Expected: `PASS: 8 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/active_slots.gd tests/test_active_slots.gd
git commit -m "feat: add two active slots with LRU replacement and Cycle"
```

---

### Task 6: PlayerSkillSet — owned skills turned into stats, flags, slots, damage mods and triggers

**Files:**
- Create: `scripts/player/player_skill_set.gd`
- Test: `tests/test_player_skill_set.gd`

**Interfaces:**
- Consumes: `SkillRulesEngine` (`owned`, `level_of`, `get_def`), `Stats`, `ActiveSlots`, `SkillEffects`, and `Ledger._matches`.
- Produces: `PlayerSkillSet` (a `RefCounted`).
  - Signal: `slot_replaced(new_id, old_id)`, forwarded from its slots.
  - Vars: `slots: ActiveSlots`, `capabilities: Dictionary`, `stats: Stats`
  - Methods:
    - `on_skill_unlocked(id)`, `refresh()`, `reset()`
    - `has(flag) -> bool`, `level(flag) -> int`
    - `incoming(damage_type, hp, max_hp) -> Dictionary`
    - `heal_on(event_name, tags) -> int`

- [ ] **Step 1: Write the failing test, `tests/test_player_skill_set.gd`**

```gdscript
extends GutTest

var rules: SkillRulesEngine
var stats: Stats
var set: PlayerSkillSet

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(DefLoader.load_dir("res://data/skills"))
	stats = Stats.new({"max_hp": 30, "atk": 1, "def": 0, "spd": 100})
	set = PlayerSkillSet.new(rules, stats)
	rules.skill_unlocked.connect(set.on_skill_unlocked)
	rules.skill_leveled.connect(func(_id: String, _lv: int) -> void: set.refresh())
	rules.start_run()

func _emit(ev: String, tags: Dictionary, times: int = 1) -> void:
	for i in times:
		rules.handle_event(ev, tags)

func test_passive_modifiers_follow_unlock_and_level() -> void:
	_emit("jumped", {"from": "ground"}, 40)
	assert_eq(stats.get_stat("jump_height"), 110)
	_emit("jumped", {"from": "ground"}, 40)
	assert_eq(stats.get_stat("jump_height"), 115)

func test_capabilities_and_compound_modifier() -> void:
	_emit("wall_touched", {}, 15)
	assert_true(set.has("wall_cling"))
	assert_eq(set.level("wall_cling"), 1)
	assert_eq(stats.get_stat("slide_speed"), 70)

func test_toughness_raises_max_hp() -> void:
	_emit("damaged", {"damage_type": "physical"}, 20)
	assert_eq(stats.get_stat("max_hp"), 33)

func test_active_unlocks_fill_slots() -> void:
	_emit("absorbed", {"essence": "water", "source": "water_pool"}, 4)
	assert_eq(set.slots.slots, ["hydraulic_propulsion", ""])

func test_incoming_damage_mods() -> void:
	_emit("damaged", {"damage_type": "poison"}, 6)   # Poison Resistance Lv1
	assert_eq(set.incoming("poison", 30, 30), {"percent_off": 20, "flat_off": 0})
	_emit("hp_low_exited", {}, 2)                    # Pain Resistance Lv1
	assert_eq(set.incoming("physical", 8, 30), {"percent_off": 0, "flat_off": 1})
	assert_eq(set.incoming("physical", 20, 30), {"percent_off": 0, "flat_off": 0})

func test_glutton_trigger_heals_on_creature_eats_only() -> void:
	assert_eq(set.heal_on("predated", {"source": "bat", "kind": "creature"}), 0)
	_emit("predated", {"source": "bat", "kind": "creature"}, 5)
	assert_eq(set.heal_on("predated", {"source": "bat", "kind": "creature"}), 3)
	assert_eq(set.heal_on("predated", {"source": "water_pool", "kind": "terrain"}), 0)

func test_reset_clears_slots_flags_and_modifiers() -> void:
	_emit("wall_touched", {}, 15)
	_emit("absorbed", {"essence": "water"}, 4)
	rules.reset_run()
	set.reset()
	assert_false(set.has("wall_cling"))
	assert_eq(set.slots.slots, ["", ""])
	assert_eq(stats.get_stat("slide_speed"), 100)

func test_slot_replaced_is_forwarded() -> void:
	var seen: Array = []
	set.slot_replaced.connect(func(n: String, o: String) -> void: seen.append([n, o]))
	set.slots.add("a")
	set.slots.add("b")
	set.slots.add("c")
	assert_eq(seen, [["c", "a"]])
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh player_skill_set`
Expected: FAIL (a Parse Error because `PlayerSkillSet` isn't declared).

- [ ] **Step 3: Implement `scripts/player/player_skill_set.gd`**

```gdscript
class_name PlayerSkillSet
extends RefCounted
## Turns the player's owned skills into stat modifiers, capability flags, active slots,
## incoming-damage reductions and triggers. Recomputed from SkillRules on every change.

signal slot_replaced(new_id: String, old_id: String)

var rules: SkillRulesEngine
var stats: Stats
var slots := ActiveSlots.new()
var capabilities := {}

func _init(p_rules: SkillRulesEngine, p_stats: Stats) -> void:
	rules = p_rules
	stats = p_stats
	slots.slot_replaced.connect(func(n: String, o: String) -> void: slot_replaced.emit(n, o))

func on_skill_unlocked(id: String) -> void:
	var d := rules.get_def(id)
	if d != null and SkillEffects.active_scene(d) != "":
		slots.add(id)
	refresh()

func refresh() -> void:
	stats.clear_modifiers()
	capabilities.clear()
	for id in rules.owned():
		var d := rules.get_def(id)
		var lv := rules.level_of(id)
		stats.set_modifiers(id, SkillEffects.stat_modifiers(d, lv))
		capabilities.merge(SkillEffects.capabilities(d, lv), true)

func reset() -> void:
	slots.reset()
	refresh()

func has(flag: String) -> bool:
	return capabilities.has(flag)

func level(flag: String) -> int:
	return int(capabilities.get(flag, 0))

func incoming(damage_type: String, hp: int, max_hp: int) -> Dictionary:
	var pairs: Array = []
	for id in rules.owned():
		pairs.append([rules.get_def(id), rules.level_of(id)])
	return SkillEffects.damage_reduction(pairs, damage_type, hp, max_hp)

## Extra healing from owned triggers matching this event (e.g. Glutton on creature eats).
func heal_on(event_name: String, tags: Dictionary) -> int:
	var total := 0
	for id in rules.owned():
		var t: Dictionary = rules.get_def(id).trigger
		if t.is_empty() or t.get("on", "") != event_name or t.get("action", "") != "heal":
			continue
		if Ledger._matches(tags, t.get("tags", {})):
			total += int(t.get("amount", 0))
	return total
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh player_skill_set`
Expected: `PASS: 8 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player_skill_set.gd tests/test_player_skill_set.gd
git commit -m "feat: apply owned skills to stats, flags, slots, damage and triggers"
```

---

### Task 7: Abilities — the base class and six player actives

**Files:**
- Create: `scripts/abilities/ability.gd`, `scripts/abilities/poison_breath.gd`, `scripts/abilities/hydraulic_propulsion.gd`, `scripts/abilities/water_blade.gd`, `scripts/abilities/sticky_thread.gd`, `scripts/abilities/swing_thread.gd`, `scripts/abilities/jet_dash.gd`
- Modify (rewrite): `scenes/abilities/{poison_breath,hydraulic_propulsion,water_blade,sticky_thread,swing_thread,jet_dash}.tscn`
- Test: `tests/test_abilities.gd`

**Interfaces:**
- Consumes: an actor with `team: String`, `facing: int`, `global_position`, `apply_impulse(v: Vector2)` and `get_tree()`. Targets are nodes in group `"actors"` with a different `team` and a `receive_hit(raw: int, damage_type: String)` method. Sticky Thread targets may also have `receive_thread(tier: int)`.
- Produces: `Ability` (extends `Node2D`).
  - `setup(actor, values: Array, level: int)`
  - `activate() -> bool`, which is false while on cooldown
  - `value() -> int`
  - `targets_in_front(range_px: float, half_height: float) -> Array`
  - `level`, and `COOLDOWN_SECONDS = 0.8`

- [ ] **Step 1: Write the failing test, `tests/test_abilities.gd`**

```gdscript
extends GutTest

class FakeActor extends Node2D:
	var team := "player"
	var facing := 1
	var impulses: Array = []
	var hits: Array = []
	var threads: Array = []
	func apply_impulse(v: Vector2) -> void:
		impulses.append(v)
	func receive_hit(raw: int, damage_type: String) -> void:
		hits.append([raw, damage_type])
	func receive_thread(tier: int) -> void:
		threads.append(tier)

var player: FakeActor

func before_each() -> void:
	player = FakeActor.new()
	add_child_autofree(player)
	player.add_to_group("actors")

func _enemy(x: float, y: float = 0.0) -> FakeActor:
	var e := FakeActor.new()
	e.team = "enemy"
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = Vector2(x, y)
	return e

func _ability(scene: String, values: Array, level: int = 1) -> Ability:
	var a: Ability = load(scene).instantiate()
	add_child_autofree(a)
	a.setup(player, values, level)
	return a

func test_cooldown_blocks_until_it_elapses() -> void:
	var a := _ability("res://scenes/abilities/jet_dash.tscn", [])
	assert_true(a.activate())
	assert_false(a.activate())
	a._process(0.8)
	assert_true(a.activate())

func test_poison_breath_hits_other_team_in_front_only() -> void:
	var front := _enemy(40)
	var behind := _enemy(-40)
	var far := _enemy(200)
	var ally := FakeActor.new()
	add_child_autofree(ally)
	ally.add_to_group("actors")
	ally.global_position = Vector2(20, 0)
	var a := _ability("res://scenes/abilities/poison_breath.tscn", [2, 3, 4, 5, 6], 3)
	a.activate()
	assert_eq(front.hits, [[4, "poison"]])
	assert_eq(behind.hits, [])
	assert_eq(far.hits, [])
	assert_eq(ally.hits, [])

func test_water_blade_hits_nearest_in_front() -> void:
	var near := _enemy(60)
	var farther := _enemy(120)
	_ability("res://scenes/abilities/water_blade.tscn", [3]).activate()
	assert_eq(near.hits, [[3, "physical"]])
	assert_eq(farther.hits, [])

func test_sticky_thread_passes_tier() -> void:
	var e := _enemy(50)
	_ability("res://scenes/abilities/sticky_thread.tscn", [1, 1, 2, 2, 2], 3).activate()
	assert_eq(e.threads, [2])

func test_movement_abilities_push_the_actor_in_facing_direction() -> void:
	player.facing = -1
	_ability("res://scenes/abilities/hydraulic_propulsion.tscn", [100, 120, 140, 160, 180], 2).activate()
	_ability("res://scenes/abilities/jet_dash.tscn", []).activate()
	_ability("res://scenes/abilities/swing_thread.tscn", []).activate()
	assert_eq(player.impulses.size(), 3)
	assert_eq(player.impulses[0], Vector2(-456.0, -140.0))
	for v in player.impulses:
		assert_lt(v.x, 0.0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh abilities`
Expected: FAIL (a Parse Error because `Ability` isn't declared).

- [ ] **Step 3: Implement the ability scripts**

`scripts/abilities/ability.gd`:

```gdscript
class_name Ability
extends Node2D
## Base for active skills. The actor supplies facing, team and apply_impulse(); targets are
## other-team members of group "actors". Abilities never emit gameplay events themselves.

const COOLDOWN_SECONDS := 0.8

var actor: Node2D
var values: Array = []
var level := 1
var _cooldown := 0.0

func setup(p_actor: Node2D, p_values: Array, p_level: int) -> void:
	actor = p_actor
	values = p_values
	level = p_level

func activate() -> bool:
	if _cooldown > 0.0 or actor == null:
		return false
	_cooldown = COOLDOWN_SECONDS
	_perform()
	return true

func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

func value() -> int:
	if values.is_empty():
		return 0
	return int(values[clampi(level, 1, values.size()) - 1])

## Other-team actors in front of the actor, nearest first.
func targets_in_front(range_px: float, half_height: float) -> Array:
	var out: Array = []
	for n in actor.get_tree().get_nodes_in_group("actors"):
		if n == actor or n.get("team") == actor.team or not n.has_method("receive_hit"):
			continue
		var dx: float = (n.global_position.x - actor.global_position.x) * actor.facing
		if dx >= -4.0 and dx <= range_px and absf(n.global_position.y - actor.global_position.y) <= half_height:
			out.append(n)
	out.sort_custom(func(a, b): return absf(a.global_position.x - actor.global_position.x) < absf(b.global_position.x - actor.global_position.x))
	return out

func _perform() -> void:
	pass
```

`scripts/abilities/poison_breath.gd`:

```gdscript
extends Ability
## Short poison cone in front of the actor.

func _perform() -> void:
	for t in targets_in_front(56.0, 24.0):
		t.receive_hit(value(), "poison")
```

`scripts/abilities/hydraulic_propulsion.gd`:

```gdscript
extends Ability
## Short water-powered burst; values are percent of base distance.

const BASE_PUSH := 380.0

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * BASE_PUSH * value() / 100.0, -140.0))
```

`scripts/abilities/water_blade.gd`:

```gdscript
extends Ability
## Instant water blade: hits the nearest other-team actor ahead.

func _perform() -> void:
	var targets := targets_in_front(160.0, 20.0)
	if not targets.is_empty():
		targets[0].receive_hit(value(), "physical")
```

`scripts/abilities/sticky_thread.gd`:

```gdscript
extends Ability
## Thread that slows (tier 1) or holds (tier 2) the nearest enemy ahead.

func _perform() -> void:
	for t in targets_in_front(96.0, 24.0):
		if t.has_method("receive_thread"):
			t.receive_thread(value())
			return
```

`scripts/abilities/swing_thread.gd`:

```gdscript
extends Ability
## Grappling-hook swing: up and forward.

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * 260.0, -360.0))
```

`scripts/abilities/jet_dash.gd`:

```gdscript
extends Ability
## Long horizontal dash.

func _perform() -> void:
	actor.apply_impulse(Vector2(actor.facing * 700.0, 0.0))
```

Rewrite each of the six scenes to attach its script. Run this:

```bash
for id in poison_breath hydraulic_propulsion water_blade sticky_thread swing_thread jet_dash; do
  name=$(echo "$id" | awk -F_ '{for(i=1;i<=NF;i++) printf toupper(substr($i,1,1)) substr($i,2)}')
  printf '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://scripts/abilities/%s.gd" id="1"]\n\n[node name="%s" type="Node2D"]\nscript = ExtResource("1")\n' "$id" "$name" > "scenes/abilities/$id.tscn"
done
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh abilities`
Expected: `PASS: 5 tests`. Then run `tools/run_tests.sh content`, expecting `PASS: 4 tests`: the scenes still exist, so validation passes.

- [ ] **Step 5: Commit**

```bash
git add scripts/abilities scenes/abilities tests/test_abilities.gd
git commit -m "feat: add ability base and six player actives"
```

---

### Task 8: Enemy and WaterPool

**Files:**
- Create: `scripts/enemies/enemy.gd`, `scripts/world/water_pool.gd`
- Test: `tests/test_enemy.gd`

**Interfaces:**
- Consumes: `CreatureDef`, the full skill def list indexed by id (including `enemy_only`), `Stats`, `Health` (with no emitter), `EnemyStatus` and `SkillEffects`.
- Produces:
  - `Enemy` (extends `CharacterBody2D`).
    - Vars: `def`, `stats`, `health`, `status`, `capabilities`, `team = "enemy"`, `facing`
    - Methods:
      - `setup(def: CreatureDef, skill_defs_by_id: Dictionary)`
      - `receive_hit(raw, damage_type)`, `receive_tackle(atk: int, from_behind: bool) -> bool`, `receive_thread(tier)`
      - `can_be_predated() -> bool`, `set_held(v)`, `consume() -> CreatureDef`
    - Groups: `"actors"`, `"predatable"`, `"inspectable"`.
  - `WaterPool` (extends `Node2D`), with `setup(def)`, `can_be_predated()`, `set_held(v)` and `consume() -> CreatureDef`, in groups `"predatable"` and `"inspectable"`.

- [ ] **Step 1: Write the failing test, `tests/test_enemy.gd`**

```gdscript
extends GutTest

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	return e

func test_stats_include_the_creatures_own_skills() -> void:
	var lizard := _enemy("lizard")
	assert_eq(lizard.stats.get_stat("def"), 3)  # 1 + Body Armor Lv2
	var bat := _enemy("bat")
	assert_true(bat.capabilities.has("flight"))
	assert_true(bat.capabilities.has("reveals_hidden"))
	assert_true(bat.is_in_group("actors") and bat.is_in_group("predatable") and bat.is_in_group("inspectable"))

func test_tackle_stuns_and_makes_it_predatable() -> void:
	var bat := _enemy("bat")
	assert_false(bat.can_be_predated())
	assert_true(bat.receive_tackle(1, false))
	assert_eq(bat.health.hp, 1)
	assert_eq(bat.status.state, EnemyStatus.STUNNED)
	assert_true(bat.can_be_predated())

func test_lethal_damage_downs_instead_of_removing() -> void:
	var bat := _enemy("bat")
	bat.receive_hit(9, "physical")
	assert_eq(bat.status.state, EnemyStatus.DOWNED)
	assert_true(bat.can_be_predated())
	assert_true(bat.receive_tackle(1, true) == false)  # downed: no further tackle effect

func test_tackle_that_downs_still_counts() -> void:
	var bat := _enemy("bat")
	bat.receive_hit(1, "physical")
	assert_true(bat.receive_tackle(1, false))
	assert_eq(bat.status.state, EnemyStatus.DOWNED)

func test_lizard_is_only_stunned_from_behind() -> void:
	var lizard := _enemy("lizard")
	assert_false(lizard.receive_tackle(1, false))
	assert_eq(lizard.status.state, EnemyStatus.ACTIVE)
	assert_true(lizard.receive_tackle(1, true))
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)

func test_serpent_cannot_be_stunned_or_eaten() -> void:
	var serpent := _enemy("serpent")
	assert_false(serpent.receive_tackle(1, true))
	assert_false(serpent.can_be_predated())

func test_thread_tier_two_stuns() -> void:
	var spider := _enemy("spider")
	spider.receive_thread(1)
	assert_eq(spider.status.state, EnemyStatus.ACTIVE)
	spider.receive_thread(2)
	assert_eq(spider.status.state, EnemyStatus.STUNNED)

func test_consume_returns_def_and_leaves() -> void:
	var toad := _enemy("toad")
	toad.receive_tackle(1, false)
	assert_eq(toad.consume(), creatures["toad"])
	assert_false(toad.can_be_predated())

func test_enemies_never_emit_gameplay_events() -> void:
	var seen: Array = []
	var recorder := func(n: String, t: Dictionary) -> void: seen.append(n)
	EventBus.game_event.connect(recorder)
	var toad := _enemy("toad")
	toad.receive_hit(1, "poison")
	toad.receive_tackle(1, false)
	toad.receive_hit(9, "physical")
	EventBus.game_event.disconnect(recorder)
	assert_eq(seen, [])

func test_water_pool_is_single_use() -> void:
	var pool := WaterPool.new()
	pool.setup(creatures["water_pool"])
	add_child_autofree(pool)
	assert_true(pool.can_be_predated())
	assert_eq(pool.consume(), creatures["water_pool"])
	assert_false(pool.can_be_predated())
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh enemy`
Expected: FAIL (a Parse Error because `Enemy` isn't declared).

- [ ] **Step 3: Implement the enemy and the pool**

`scripts/enemies/enemy.gd`:

```gdscript
class_name Enemy
extends CharacterBody2D
## A creature built from its CreatureDef: stats, its own skills, simple AI.
## Enemies never emit gameplay events (Health has no emitter).

const GRAVITY := 900.0
const BASE_SPEED := 60.0
const CHASE_RANGE := 160.0
const CONTACT_RANGE := 18.0
const PATROL_RANGE := 48.0
const SPIT_RANGE := 120.0
const SPIT_COOLDOWN := 3.0
const SPIT_TICK := 2
const SPIT_SECONDS := 3.0
const SLOW_SECONDS := 2.0
const COLORS := {"bat": Color(0.45, 0.35, 0.6), "toad": Color(0.3, 0.7, 0.3),
	"lizard": Color(0.6, 0.5, 0.3), "spider": Color(0.15, 0.15, 0.15), "serpent": Color(0.2, 0.4, 0.8)}

var def: CreatureDef
var stats: Stats
var health: Health
var status := EnemyStatus.new()
var capabilities := {}
var team := "enemy"
var facing := -1
var _home_x := 0.0
var _on_ceiling := false
var _spit_damage := 0
var _spit_cd := 0.0
var _slow := 0.0

func setup(p_def: CreatureDef, skill_defs_by_id: Dictionary) -> void:
	def = p_def
	stats = Stats.new(def.stats)
	for s in def.skills:
		var sd: SkillDef = skill_defs_by_id.get(s["id"])
		if sd == null:
			continue
		var lv := int(s["level"])
		stats.set_modifiers(sd.id, SkillEffects.stat_modifiers(sd, lv))
		capabilities.merge(SkillEffects.capabilities(sd, lv), true)
		if sd.id == "poison_spit":
			_spit_damage = int(SkillEffects.value_at(sd.effects[0], lv))
	health = Health.new(stats.get_stat("max_hp"))  # no emit_event: actor boundary
	health.died.connect(_on_died)
	_on_ceiling = capabilities.has("ceiling_walk")
	add_to_group("actors")
	add_to_group("predatable")
	add_to_group("inspectable")

func _ready() -> void:
	_home_x = global_position.x
	if get_child_count() == 0:
		_build_body()

func receive_hit(raw: int, damage_type: String) -> void:
	if status.state == EnemyStatus.DOWNED or status.state == EnemyStatus.GONE:
		return
	health.take_hit(Damage.direct_hit(raw, 0, stats.get_stat("def")), damage_type)

## Returns true when the tackle stunned or downed this enemy (the player emits stunned_enemy).
func receive_tackle(atk: int, from_behind: bool) -> bool:
	if status.state == EnemyStatus.DOWNED or status.state == EnemyStatus.GONE:
		return false
	receive_hit(atk, "physical")
	if status.state == EnemyStatus.DOWNED:
		return true
	if not def.predatable:
		return false  # the serpent can't be stunned
	if def.id == Sources.LIZARD and not from_behind:
		return false  # armored front
	status.stun()
	return true

func receive_thread(tier: int) -> void:
	if tier >= 2 and def.predatable:
		status.stun()
	else:
		_slow = SLOW_SECONDS

func can_be_predated() -> bool:
	return def.predatable and status.predatable()

func set_held(v: bool) -> void:
	status.held = v

func consume() -> CreatureDef:
	status.consume()
	queue_free()
	return def

func _on_died() -> void:
	if def.predatable:
		status.down()
	else:
		status.consume()  # Plan 3 turns the serpent's death into victory

func _physics_process(delta: float) -> void:
	status.update(delta)
	if status.state == EnemyStatus.GONE:
		queue_free()
		return
	_spit_cd = maxf(0.0, _spit_cd - delta)
	_slow = maxf(0.0, _slow - delta)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var active := status.state == EnemyStatus.ACTIVE
	if active and player != null:
		_act(player)
	else:
		velocity.x = 0.0
	var flying := capabilities.has("flight") and active
	if not flying and not (_on_ceiling and active):
		velocity.y += GRAVITY * delta
	move_and_slide()
	if active and player != null and global_position.distance_to(player.global_position) <= CONTACT_RANGE:
		player.receive_hit(stats.get_stat("atk"), "physical")

func _act(player: Node2D) -> void:
	var speed := BASE_SPEED * stats.get_stat("spd") / 100.0 * (0.5 if _slow > 0.0 else 1.0)
	var to_player: Vector2 = player.global_position - global_position
	if _on_ceiling:
		velocity = Vector2.ZERO
		if absf(to_player.x) < 40.0 and to_player.y > 0.0:
			_on_ceiling = false  # drop on prey
		return
	if capabilities.has("flight"):
		if to_player.length() < CHASE_RANGE:
			velocity = to_player.normalized() * speed
		else:
			velocity = Vector2(0.0, sin(Time.get_ticks_msec() / 300.0) * 20.0)
		facing = 1 if velocity.x >= 0.0 else -1
		return
	if absf(to_player.x) < CHASE_RANGE and absf(to_player.y) < 48.0:
		facing = 1 if to_player.x > 0.0 else -1
		velocity.x = facing * speed
	else:
		if global_position.x > _home_x + PATROL_RANGE:
			facing = -1
		elif global_position.x < _home_x - PATROL_RANGE:
			facing = 1
		velocity.x = facing * speed * 0.5
	if _spit_damage > 0 and _spit_cd <= 0.0 and to_player.length() < SPIT_RANGE:
		_spit_cd = SPIT_COOLDOWN
		player.receive_poison(_spit_damage, SPIT_TICK, SPIT_SECONDS)

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 12)
	shape.shape = rect
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(16, 12)
	visual.position = Vector2(-8, -6)
	visual.color = COLORS.get(def.id if def != null else "", Color.WHITE)
	add_child(visual)
```

`scripts/world/water_pool.gd`:

```gdscript
class_name WaterPool
extends Node2D
## Single-use terrain eat target. Needs no stun.

var def: CreatureDef
var team := "terrain"
var _consumed := false

func setup(p_def: CreatureDef) -> void:
	def = p_def
	add_to_group("predatable")
	add_to_group("inspectable")

func _ready() -> void:
	if get_child_count() == 0:
		var visual := ColorRect.new()
		visual.size = Vector2(24, 6)
		visual.position = Vector2(-12, -3)
		visual.color = Color(0.3, 0.5, 1.0)
		add_child(visual)

func can_be_predated() -> bool:
	return not _consumed

func set_held(_v: bool) -> void:
	pass

func consume() -> CreatureDef:
	_consumed = true
	queue_free()
	return def
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh enemy`
Expected: `PASS: 10 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/enemies/enemy.gd scripts/world/water_pool.gd tests/test_enemy.gd
git commit -m "feat: add data-driven enemies and single-use water pools"
```

---

### Task 9: StatusText — the pure text for the status screen, inspect panel and HUD

**Files:**
- Create: `scripts/ui/status_text.gd`
- Test: `tests/test_status_text.gd`

**Interfaces:**
- Consumes: `Stats` (`get_stat`, `eat_bonus`, `skill_bonus`), `Health`, `SkillRulesEngine` (`owned`, `level_of`, `get_def`, `count`), `CompendiumModel.self_report`, and `ActiveSlots`.
- Produces: `StatusText`, with these static methods:
  - `self_lines(stats, health, rules, compendium, appraisal_level) -> PackedStringArray`
  - `creature_lines(report: Dictionary) -> PackedStringArray`
  - `slot_line(slots: ActiveSlots, rules) -> String`
  - `ticker_text(entry: Dictionary, rules) -> String`

- [ ] **Step 1: Write the failing test, `tests/test_status_text.gd`**

```gdscript
extends GutTest

var rules: SkillRulesEngine
var compendium: CompendiumModel
var stats: Stats
var health: Health

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, DefLoader.load_dir("res://data/creatures"))
	stats = Stats.new({"max_hp": 30, "atk": 1, "def": 0, "spd": 100})
	health = Health.new(30)
	rules.start_run()

func test_self_lines_show_stats_skills_essences_and_bands_without_numbers() -> void:
	stats.apply_eat(TestDefs.creature("lizard", {"eat_bonus": {"stat": "def", "amount": 1, "per": 1}}))
	stats.set_modifiers("body_armor", [{"stat": "def", "op": "add", "value": 2}])
	for i in 3:
		rules.handle_event("absorbed", {"essence": "sound", "source": "bat"})
	for i in 20:
		rules.handle_event("jumped", {"from": "ground"})
	var text := "\n".join(StatusText.self_lines(stats, health, rules, compendium, 2))
	assert_string_contains(text, "HP 30/30")
	assert_string_contains(text, "DEF 3 (+1 eat, +2 skill)")
	assert_string_contains(text, "Appraisal Lv1")
	assert_string_contains(text, "Echolocation Lv1")
	assert_string_contains(text, "sound 3")
	assert_string_contains(text, "Leap — something stirs")
	assert_false(text.contains("20/40"))

func test_self_lines_add_hints_at_lv3() -> void:
	for i in 32:
		rules.handle_event("jumped", {"from": "ground"})
	var text := "\n".join(StatusText.self_lines(stats, health, rules, compendium, 3))
	assert_string_contains(text, "Leap — it's close (Your body remembers every leap.)")

func test_creature_lines_grow_with_report() -> void:
	var lv1 := "\n".join(StatusText.creature_lines({"id": "bat", "name": "Cave Bat", "hp": 2}))
	assert_eq(lv1, "Cave Bat\nHP 2")
	var lv3 := "\n".join(StatusText.creature_lines({"id": "toad", "name": "Poison Toad", "hp": 3,
		"stats": {"max_hp": 3, "atk": 3, "def": 0, "spd": 70}, "essences": {"poison": 1, "water": 1},
		"eat_bonus": {"stat": "max_hp", "amount": 1, "per": 1},
		"skills": [{"id": "poison_spit", "level": 1}, {"id": "poison_resistance", "level": 2}]}))
	assert_string_contains(lv3, "ATK 3  DEF 0  SPD 70")
	assert_string_contains(lv3, "Essences: poison 1, water 1")
	assert_string_contains(lv3, "Eat bonus: +1 max_hp")
	assert_string_contains(lv3, "Skills: poison_spit Lv1, poison_resistance Lv2")

func test_creature_lines_for_empty_report() -> void:
	assert_eq(StatusText.creature_lines({}), PackedStringArray(["Nothing to appraise."]))

func test_slot_and_ticker_text() -> void:
	var slots := ActiveSlots.new()
	assert_eq(StatusText.slot_line(slots, rules), "[U] —   [O] —")
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water"})
	slots.add("hydraulic_propulsion")
	assert_eq(StatusText.slot_line(slots, rules), "[U] Hydraulic Propulsion   [O] —")
	assert_eq(StatusText.ticker_text({"kind": "level", "id": "hydraulic_propulsion", "level": 2}, rules), "Hydraulic Propulsion Lv2")
	assert_eq(StatusText.ticker_text({"kind": "slot_replaced", "new_id": "water_blade", "old_id": "hydraulic_propulsion"}, rules),
		"Water Blade replaced Hydraulic Propulsion")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh status_text`
Expected: FAIL (a Parse Error because `StatusText` isn't declared).

- [ ] **Step 3: Implement `scripts/ui/status_text.gd`**

```gdscript
class_name StatusText
extends RefCounted
## Pure text builders for the status screen, the inspect panel and the HUD.
## Progress toward hidden skills is only ever shown as a band, never as numbers.

static func self_lines(stats: Stats, health: Health, rules, compendium: CompendiumModel, appraisal_level: int) -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("HP %d/%d" % [health.hp, health.max_hp])
	for key in ["atk", "def", "spd"]:
		var line := "%s %d" % [key.to_upper(), stats.get_stat(key)]
		var parts: Array = []
		if stats.eat_bonus(key) != 0:
			parts.append("%+d eat" % stats.eat_bonus(key))
		if stats.skill_bonus(key) != 0:
			parts.append("%+d skill" % stats.skill_bonus(key))
		if not parts.is_empty():
			line += " (%s)" % ", ".join(parts)
		lines.append(line)
	lines.append("Skills:")
	var ids: Array = rules.owned()
	ids.sort()
	for id in ids:
		lines.append("  %s Lv%d" % [rules.get_def(id).display_name, rules.level_of(id)])
	var essences: Array = []
	for ess in Essences.ALL:
		var n: int = rules.count(Events.ABSORBED, {"essence": ess})
		if n > 0:
			essences.append("%s %d" % [ess, n])
	lines.append("Essences: " + (", ".join(essences) if not essences.is_empty() else "none"))
	var report := compendium.self_report(appraisal_level, rules)
	for h in report["hints"]:
		var line := "  %s — %s" % [h["name"], "it's close" if h["band"] == CompendiumModel.BAND_CLOSE else "something stirs"]
		if h.has("hint") and h["hint"] != "":
			line += " (%s)" % h["hint"]
		lines.append(line)
	for e in report["evolutions"]:
		lines.append("  Something could become %s…" % e["name"])
	return lines

static func creature_lines(report: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	if report.is_empty():
		lines.append("Nothing to appraise.")
		return lines
	lines.append(report["name"])
	lines.append("HP %d" % report["hp"])
	if report.has("stats") and not report["stats"].is_empty():
		var s: Dictionary = report["stats"]
		lines.append("ATK %d  DEF %d  SPD %d" % [s.get("atk", 0), s.get("def", 0), s.get("spd", 0)])
	if report.has("essences"):
		var parts: Array = []
		for ess in report["essences"]:
			parts.append("%s %d" % [ess, report["essences"][ess]])
		lines.append("Essences: " + ", ".join(parts))
	if report.has("eat_bonus") and not report["eat_bonus"].is_empty():
		var b: Dictionary = report["eat_bonus"]
		var per := int(b.get("per", 1))
		lines.append("Eat bonus: %+d %s%s" % [b["amount"], b["stat"], "" if per == 1 else " per %d eaten" % per])
	if report.has("skills"):
		var parts: Array = []
		for sk in report["skills"]:
			parts.append("%s Lv%d" % [sk["id"], sk["level"]])
		lines.append("Skills: " + ", ".join(parts))
	return lines

static func slot_line(slots: ActiveSlots, rules) -> String:
	var names: Array = []
	for id in slots.slots:
		names.append(rules.get_def(id).display_name if id != "" and rules.get_def(id) != null else "—")
	return "[U] %s   [O] %s" % names

static func ticker_text(entry: Dictionary, rules) -> String:
	match entry.get("kind", ""):
		"level":
			return "%s Lv%d" % [_name(entry["id"], rules), entry["level"]]
		"slot_replaced":
			return "%s replaced %s" % [_name(entry["new_id"], rules), _name(entry["old_id"], rules)]
	return ""

static func _name(id: String, rules) -> String:
	var d = rules.get_def(id)
	return d.display_name if d != null else id
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh status_text`
Expected: `PASS: 5 tests`.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/status_text.gd tests/test_status_text.gd
git commit -m "feat: add status screen and HUD text builders"
```

---

### Task 10: Player

**Files:**
- Create: `scripts/player/player.gd`
- Test: `tests/test_player.gd`

**Interfaces:**
- Consumes: everything above.
- Produces: `Player` (extends `CharacterBody2D`).
  - Signals: `died` and `inspect_report(lines: PackedStringArray)`
  - Vars: `team = "player"`, `facing`, `stats`, `health`, `skillset`, `sensors`, `predation`
  - Methods:
    - `setup(rules, compendium, creature_defs: Array, emit: Callable)`
    - Actions: `do_jump()`, `do_tackle()`, `begin_predate()`, `process_predate(delta)`, `cancel_predate()`, `do_inspect()`, `use_active(i)`
    - Taking damage: `receive_hit(raw, damage_type)`, `receive_poison(application, tick_amount, seconds)`
    - `tick(delta)`, `apply_impulse(v)`

  It's in groups `"player"` and `"actors"`.

- [ ] **Step 1: Write the failing test, `tests/test_player.gd`**

```gdscript
extends GutTest

var rules: SkillRulesEngine
var compendium: CompendiumModel
var creatures := {}
var skills_by_id := {}
var events: Array
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	for c in creature_list:
		creatures[c.id] = c
	for d in skills:
		skills_by_id[d.id] = d
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	compendium = CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	events = []
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func _names() -> Array:
	return events.map(func(e): return e[0])

func _enemy(id: String, x: float) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = Vector2(x, 0)
	e.set_physics_process(false)
	return e

func test_tackle_stuns_enemy_in_front_and_emits() -> void:
	var bat := _enemy("bat", 20)
	var behind := _enemy("bat", -20)
	player.do_tackle()
	assert_eq(bat.status.state, EnemyStatus.STUNNED)
	assert_eq(behind.status.state, EnemyStatus.ACTIVE)
	assert_eq(events, [["stunned_enemy", {"source": "bat"}]])

func test_lizard_front_tackle_does_not_stun_or_emit() -> void:
	var lizard := _enemy("lizard", 20)  # lizard faces -1, player faces 1: head-on
	player.do_tackle()
	assert_eq(lizard.status.state, EnemyStatus.ACTIVE)
	assert_false(_names().has("stunned_enemy"))
	lizard.facing = 1
	player._dash = 0.0
	player.do_tackle()
	assert_eq(lizard.status.state, EnemyStatus.STUNNED)

func test_predation_completes_after_hold_and_absorbs_essences() -> void:
	var toad := _enemy("toad", 20)
	toad.receive_tackle(1, true)
	player.begin_predate()
	assert_true(toad.status.held)
	player.process_predate(0.5)
	assert_false(_names().has("predated"))
	player.process_predate(0.6)
	assert_eq(events.slice(0, 3), [["predated", {"source": "toad", "kind": "creature"}],
		["absorbed", {"essence": "poison", "source": "toad"}], ["absorbed", {"essence": "water", "source": "toad"}]])
	assert_eq(player.stats.get_stat("max_hp"), 31)
	assert_false(player.predation.active())

func test_downed_enemy_is_eaten_without_a_stun() -> void:
	var bat := _enemy("bat", 20)
	bat.receive_hit(9, "physical")
	player.begin_predate()
	player.process_predate(1.0)
	assert_true(_names().has("predated"))

func test_water_pool_eat_is_terrain_and_single_use() -> void:
	var pool := WaterPool.new()
	pool.setup(creatures["water_pool"])
	add_child_autofree(pool)
	pool.global_position = Vector2(10, 0)
	player.begin_predate()
	player.process_predate(1.0)
	assert_eq(events[0], ["predated", {"source": "water_pool", "kind": "terrain"}])
	assert_eq(_names().count("absorbed"), 2)
	assert_false(pool.can_be_predated())

func test_target_freed_mid_hold_cancels_cleanly() -> void:
	# Review Focus 2
	var bat := _enemy("bat", 20)
	bat.receive_tackle(1, true)
	player.begin_predate()
	bat.free()
	player.process_predate(2.0)
	assert_false(player.predation.active())
	assert_false(_names().has("predated"))

func test_death_mid_hold_releases_target() -> void:
	# Review Focus 1
	var bat := _enemy("bat", 20)
	bat.receive_tackle(1, true)
	player.begin_predate()
	player.receive_hit(99, "physical")
	assert_true(player.health.is_dead())
	assert_false(bat.status.held)
	events.clear()
	player.process_predate(2.0)
	player.do_tackle()
	assert_eq(events, [])

func test_direct_hit_emits_and_grants_invulnerability() -> void:
	player.receive_hit(3, "physical")
	player.receive_hit(3, "physical")
	assert_eq(player.health.hp, 27)
	player.tick(0.6)
	player.receive_hit(3, "physical")
	assert_eq(player.health.hp, 24)
	assert_eq(_names().count("damaged"), 2)

func test_poison_application_then_ticks_floor_at_one() -> void:
	player.receive_poison(4, 2, 3.0)
	assert_eq(player.health.hp, 26)
	for i in 3:
		player.tick(1.0)
	assert_eq(player.health.hp, 20)
	assert_eq(events.filter(func(e): return e[0] == "damaged"), [["damaged", {"damage_type": "poison"}]])

func test_glutton_heal_can_exit_the_low_band_during_eats() -> void:
	# Plan 1 handoff: the Glutton heal can emit hp_low_exited right after a predated drain.
	for i in 5:
		rules.handle_event("predated", {"source": "bat", "kind": "creature"})
	assert_eq(rules.level_of("glutton"), 1)
	player.receive_hit(22, "physical")  # 8/30: low
	for x in [20, 22]:
		var bat := _enemy("bat", x)
		bat.receive_hit(9, "physical")
		player.begin_predate()
		player.process_predate(1.0)
	assert_eq(player.health.hp, 24)  # 8 + (5+3) + (5+3)
	var names := _names()
	assert_lt(names.rfind("predated"), names.find("hp_low_exited"))
	assert_eq(rules.count("hp_low_exited"), 1)

func test_inspect_self_when_nothing_in_range() -> void:
	# Review Focus 5
	var got: Array = []
	player.inspect_report.connect(func(lines: PackedStringArray) -> void: got.append(lines))
	player.do_inspect()
	assert_eq(events[0], ["inspected", {"target": "self", "first_time": true, "appraisal_target": true}])
	assert_string_contains("\n".join(got[0]), "HP 30/30")

func test_inspect_creature_reports_with_post_inspect_level() -> void:
	player.do_inspect()  # self: 1 distinct target
	_enemy("bat", 40)
	var got: Array = []
	player.inspect_report.connect(func(lines: PackedStringArray) -> void: got.append(lines))
	player.do_inspect()  # bat: 2 distinct -> Appraisal Lv2
	assert_eq(rules.level_of("appraisal"), 2)
	assert_string_contains("\n".join(got[0]), "Essences: sound 1, flight 1")

func test_use_active_emits_skill_used_with_cooldown() -> void:
	for i in 4:
		rules.handle_event("absorbed", {"essence": "water", "source": "water_pool"})
	player.use_active(0)
	player.use_active(0)
	assert_eq(events.filter(func(e): return e[0] == "skill_used"), [["skill_used", {"id": "hydraulic_propulsion"}]])
	player.use_active(1)  # empty slot
	assert_eq(_names().count("skill_used"), 1)

func test_use_active_without_a_loadable_ability_emits_nothing() -> void:
	# Review Focus 3
	player.skillset.slots.add("no_such_skill")
	player.use_active(0)
	assert_false(_names().has("skill_used"))

func test_max_hp_follows_toughness_and_eats() -> void:
	for i in 20:
		rules.handle_event("damaged", {"damage_type": "physical"})
	assert_eq(player.health.max_hp, 33)

func test_jump_on_floor_emits_jumped() -> void:
	var floor := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 20)
	shape.shape = rect
	floor.add_child(shape)
	floor.position = Vector2(0, 30)
	add_child_autofree(floor)
	player.global_position = Vector2(0, 0)
	await wait_physics_frames(30)
	assert_true(player.is_on_floor())
	player.do_jump()
	assert_true(events.has(["jumped", {"from": "ground"}]))
	assert_lt(player.velocity.y, 0.0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh player`
Expected: FAIL (a Parse Error because `Player` isn't declared). The existing `player_skill_set` suite also matches the `player` filter; that's fine.

- [ ] **Step 3: Implement `scripts/player/player.gd`**

```gdscript
class_name Player
extends CharacterBody2D
## The slime. Reads input, moves, and is the only actor that emits gameplay events.

signal died
signal inspect_report(lines: PackedStringArray)

const SPEED := 140.0
const JUMP_VELOCITY := -330.0
const WALL_JUMP_PUSH := 180.0
const GRAVITY := 900.0
const WALL_SLIDE_SPEED := 90.0
const TACKLE_RANGE := 28.0
const TACKLE_SPEED := 260.0
const TACKLE_SECONDS := 0.15
const PREDATE_RANGE := 32.0
const INSPECT_RANGE := 96.0
const INVULN_SECONDS := 0.6
const EAT_HEAL := 5
const BASE_STATS := {"max_hp": 30, "atk": 1, "def": 0, "spd": 100}

var team := "player"
var facing := 1
var stats: Stats
var health: Health
var skillset: PlayerSkillSet
var sensors := PlayerSensors.new()
var predation := PredationHold.new()

var _rules: SkillRulesEngine
var _compendium: CompendiumModel
var _creatures := {}
var _emit: Callable
var _invuln := 0.0
var _dash := 0.0
var _poison_left := 0.0
var _poison_tick := 0
var _poison_acc := 0.0
var _regen_acc := 0.0
var _abilities := {}

func setup(rules: SkillRulesEngine, compendium: CompendiumModel, creature_defs: Array, emit: Callable) -> void:
	_rules = rules
	_compendium = compendium
	_emit = emit
	for c in creature_defs:
		_creatures[c.id] = c
	stats = Stats.new(BASE_STATS)
	health = Health.new(BASE_STATS["max_hp"])
	health.emit_event = emit
	health.died.connect(_on_health_died)
	sensors.emit_event = emit
	skillset = PlayerSkillSet.new(rules, stats)
	rules.skill_unlocked.connect(_on_skill_unlocked)
	rules.skill_leveled.connect(_on_skill_leveled)
	rules.run_started.connect(_on_run_started)
	add_to_group("player")
	add_to_group("actors")
	if get_child_count() == 0:
		_build_body()

func _physics_process(delta: float) -> void:
	if health == null or health.is_dead():
		return
	var dir := Input.get_axis("move_left", "move_right")
	if predation.active():
		dir = 0.0
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if _dash > 0.0:
		_dash -= delta
	else:
		velocity.x = dir * SPEED * stats.get_stat("spd") / 100.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if skillset.has("wall_cling") and is_on_wall() and not is_on_floor() and velocity.y > 0.0:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED * stats.get_stat("slide_speed") / 100.0)
	if Input.is_action_just_pressed("jump"):
		do_jump()
	if Input.is_action_just_pressed("tackle"):
		do_tackle()
	if Input.is_action_pressed("predate"):
		if predation.active():
			process_predate(delta)
		else:
			begin_predate()
	elif predation.active():
		cancel_predate()
	if Input.is_action_just_pressed("inspect"):
		do_inspect()
	if Input.is_action_just_pressed("active_1"):
		use_active(0)
	if Input.is_action_just_pressed("active_2"):
		use_active(1)
	if Input.is_action_just_pressed("cycle"):
		skillset.slots.cycle()
	move_and_slide()
	sensors.physics_update(is_on_wall(), is_on_floor())
	tick(delta)

func do_jump() -> void:
	if health.is_dead():
		return
	var boost := sqrt(stats.get_stat("jump_height") / 100.0)
	if is_on_floor():
		velocity.y = JUMP_VELOCITY * boost
		sensors.jumped("ground")
	elif skillset.has("wall_cling") and is_on_wall():
		velocity.y = JUMP_VELOCITY * boost
		velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
		_dash = 0.15
		sensors.jumped("wall")

func do_tackle() -> void:
	if health.is_dead() or predation.active() or _dash > 0.0:
		return
	velocity.x = facing * TACKLE_SPEED
	_dash = TACKLE_SECONDS
	var target = _nearest_in_front(TACKLE_RANGE)
	if target == null or not target.has_method("receive_tackle"):
		return
	var from_behind: bool = target.facing == facing
	if target.receive_tackle(stats.get_stat("atk"), from_behind):
		_emit.call(Events.STUNNED_ENEMY, {"source": target.def.id})

func begin_predate() -> void:
	if health.is_dead():
		return
	var target = _nearest_in_group("predatable", PREDATE_RANGE, func(n): return n.can_be_predated())
	if target == null:
		return
	target.set_held(true)
	predation.start(target, stats.get_stat("predation_time"))

func process_predate(delta: float) -> void:
	var t = predation.target
	if health.is_dead() or not is_instance_valid(t) or not t.can_be_predated():
		cancel_predate()
		return
	if predation.update(delta):
		_complete_predation(t)

func cancel_predate() -> void:
	var t = predation.target
	if is_instance_valid(t):
		t.set_held(false)
	predation.cancel()

func do_inspect() -> void:
	if health.is_dead():
		return
	var target = _nearest_in_group("inspectable", INSPECT_RANGE, func(_n): return true)
	if target == null:
		sensors.inspected("self", true)
		inspect_report.emit(StatusText.self_lines(stats, health, _rules, _compendium, _rules.level_of("appraisal")))
		return
	var c: CreatureDef = target.def
	sensors.inspected(c.id, c.appraisal_target)
	inspect_report.emit(StatusText.creature_lines(_compendium.creature_report(c.id, _rules.level_of("appraisal"))))

func use_active(i: int) -> void:
	if health.is_dead():
		return
	var id := skillset.slots.use(i)
	if id == "":
		return
	var ability := _ability(id)
	if ability == null:
		return
	ability.level = _rules.level_of(id)
	if ability.activate():
		_emit.call(Events.SKILL_USED, {"id": id})

func receive_hit(raw: int, damage_type: String) -> void:
	if _invuln > 0.0 or health.is_dead():
		return
	var m := skillset.incoming(damage_type, health.hp, health.max_hp)
	health.take_hit(Damage.direct_hit(raw, m["percent_off"], m["flat_off"] + stats.get_stat("def")), damage_type)
	_invuln = INVULN_SECONDS

func receive_poison(application: int, tick_amount: int, seconds: float) -> void:
	if _invuln > 0.0 or health.is_dead():
		return
	receive_hit(application, "poison")
	_poison_left = seconds
	_poison_tick = tick_amount
	_poison_acc = 0.0

func tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	if health.is_dead():
		return
	if _poison_left > 0.0:
		_poison_acc += delta
		while _poison_acc >= 1.0 - 0.0001 and _poison_left > 0.0:
			_poison_acc -= 1.0
			_poison_left -= 1.0
			var m := skillset.incoming("poison", health.hp, health.max_hp)
			health.take_tick(Damage.tick(_poison_tick, m["percent_off"]))
	var interval := stats.get_stat("regen_interval")
	if interval > 0:
		_regen_acc += delta
		if _regen_acc >= interval:
			_regen_acc -= interval
			health.heal(1)
	else:
		_regen_acc = 0.0

func apply_impulse(v: Vector2) -> void:
	velocity = Vector2(v.x, velocity.y + v.y)
	_dash = 0.25

func _complete_predation(t) -> void:
	predation.cancel()
	var c: CreatureDef = t.consume()
	var kind := "terrain" if c.id == Sources.WATER_POOL else "creature"
	_emit.call(Events.PREDATED, {"source": c.id, "kind": kind})
	for ess in c.essences:
		for i in int(c.essences[ess]):
			_emit.call(Events.ABSORBED, {"essence": ess, "source": c.id})
	stats.apply_eat(c)
	_sync_max_hp()
	health.heal(EAT_HEAL + skillset.heal_on(Events.PREDATED, {"source": c.id, "kind": kind}))

func _ability(id: String) -> Ability:
	if _abilities.has(id):
		return _abilities[id]
	var d := _rules.get_def(id)
	if d == null:
		return null
	var path := SkillEffects.active_scene(d)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var node = load(path).instantiate()
	if not (node is Ability):
		node.free()
		return null
	node.setup(self, SkillEffects.active_values(d), _rules.level_of(id))
	add_child(node)
	_abilities[id] = node
	return node

func _nearest_in_front(range_px: float):
	var best = null
	var best_dx := INF
	for n in get_tree().get_nodes_in_group("actors"):
		if n == self or n.get("team") == team:
			continue
		var dx: float = (n.global_position.x - global_position.x) * facing
		if dx < -4.0 or dx > range_px or absf(n.global_position.y - global_position.y) > 20.0:
			continue
		if dx < best_dx:
			best = n
			best_dx = dx
	return best

func _nearest_in_group(group: String, range_px: float, accept: Callable):
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		if n == self or not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d <= range_px and d < best_d and accept.call(n):
			best = n
			best_d = d
	return best

func _sync_max_hp() -> void:
	health.set_max_hp(stats.get_stat("max_hp"))

func _on_skill_unlocked(id: String) -> void:
	skillset.on_skill_unlocked(id)
	_sync_max_hp()

func _on_skill_leveled(_id: String, _level: int) -> void:
	skillset.refresh()
	_sync_max_hp()

func _on_run_started() -> void:
	skillset.reset()
	stats.reset_run()
	_sync_max_hp()

func _on_health_died() -> void:
	cancel_predate()
	died.emit()

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 12)
	shape.shape = rect
	add_child(shape)
	var visual := ColorRect.new()
	visual.size = Vector2(14, 12)
	visual.position = Vector2(-7, -6)
	visual.color = Color(0.4, 0.8, 1.0)
	add_child(visual)
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh test_player.gd`
Expected: `PASS: 17 tests`.

- [ ] **Step 5: Run the full suite, then commit**

Run: `tools/run_tests.sh`. Expected: all tests pass.

```bash
git add scripts/player/player.gd tests/test_player.gd
git commit -m "feat: add the playable slime with tackle, predation, inspect and actives"
```

---

### Task 11: Room, HUD, Game and the main scene

**Files:**
- Create: `scripts/world/room_layout.gd`, `scripts/world/room_builder.gd`, `scripts/ui/hud.gd`, `scripts/game.gd`, `scenes/main.tscn`
- Modify: `project.godot` (set `run/main_scene`)
- Test: `tests/test_game.gd`

**Interfaces:**
- Consumes: the autoloads (`SkillRules`, `Compendium`, `Announcer`, `EventBus`, `Controls`), `Player`, `Enemy`, `WaterPool`, `StatusText`.
- Produces:
  - `RoomLayout.TEST_ROOM`, a Dictionary: `{"solids": Array[Rect2], "spawns": Array[{"id": String, "pos": Vector2}], "player": Vector2}`
  - `RoomBuilder.build(parent: Node, layout: Dictionary)`
  - `Hud` (a `CanvasLayer`), with `bind(player, rules, compendium, queue)`, `hp_text() -> String` and `popup_text() -> String`
  - The `Game` script, with vars `player` and `hud`

- [ ] **Step 1: Write the failing test, `tests/test_game.gd`**

```gdscript
extends GutTest

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_main_scene_boots_a_run_with_room_actors_and_hud() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_not_null(game.player)
	assert_true(SkillRules.run_active)
	assert_eq(SkillRules.level_of("appraisal"), 1)
	var enemies := get_tree().get_nodes_in_group("actors").filter(func(n): return n is Enemy)
	assert_eq(enemies.size(), RoomLayout.TEST_ROOM["spawns"].filter(func(s): return s["id"] != "water_pool").size())
	assert_eq(get_tree().get_nodes_in_group("predatable").filter(func(n): return n is WaterPool).size(), 2)
	assert_eq(game.hud.hp_text(), "HP 30/30")

func test_hud_shows_unlock_popup_from_the_announcer() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	for i in 40:
		EventBus.game_event.emit("jumped", {"from": "ground"})
	await wait_process_frames(2)
	assert_string_contains(game.hud.popup_text(), "Leap")

func test_test_room_meets_the_food_minimums_for_the_slice() -> void:
	var counts := {}
	for s in RoomLayout.TEST_ROOM["spawns"]:
		counts[s["id"]] = int(counts.get(s["id"], 0)) + 1
	assert_eq(counts, {"bat": 3, "toad": 4, "lizard": 3, "spider": 3, "water_pool": 2})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tools/run_tests.sh test_game`
Expected: FAIL. Either `res://scenes/main.tscn` doesn't exist, or there's a Parse Error on `RoomLayout`.

- [ ] **Step 3: Implement the room, the HUD, the game and the main scene**

`scripts/world/room_layout.gd`:

```gdscript
class_name RoomLayout
extends RefCounted
## The vertical-slice test room as data: solids, spawns and the player start.
## It holds the spec's per-run food minimums, so every skill in the slice is reachable.

const TEST_ROOM := {
	"player": Vector2(60, 290),
	"solids": [
		Rect2(0, 320, 1600, 40),      # floor
		Rect2(-20, 0, 20, 360),       # left wall
		Rect2(1600, 0, 20, 360),      # right wall
		Rect2(0, -20, 1600, 20),      # ceiling
		Rect2(260, 250, 120, 12),     # platform
		Rect2(520, 200, 100, 12),     # platform
		Rect2(760, 140, 16, 180),     # wall-cling column
		Rect2(900, 230, 140, 12),     # platform
		Rect2(1200, 180, 120, 12),    # platform
	],
	"spawns": [
		{"id": "bat", "pos": Vector2(300, 200)},
		{"id": "bat", "pos": Vector2(560, 150)},
		{"id": "bat", "pos": Vector2(980, 180)},
		{"id": "toad", "pos": Vector2(200, 300)},
		{"id": "toad", "pos": Vector2(420, 300)},
		{"id": "toad", "pos": Vector2(680, 300)},
		{"id": "toad", "pos": Vector2(1100, 300)},
		{"id": "lizard", "pos": Vector2(860, 300)},
		{"id": "lizard", "pos": Vector2(1300, 300)},
		{"id": "lizard", "pos": Vector2(1450, 300)},
		{"id": "spider", "pos": Vector2(340, 12)},
		{"id": "spider", "pos": Vector2(1000, 12)},
		{"id": "spider", "pos": Vector2(1380, 12)},
		{"id": "water_pool", "pos": Vector2(150, 316)},
		{"id": "water_pool", "pos": Vector2(1250, 316)},
	],
}
```

`scripts/world/room_builder.gd`:

```gdscript
class_name RoomBuilder
extends RefCounted
## Builds static solids from a layout. Geometry lives in data, not in .tscn files.

static func build(parent: Node, layout: Dictionary) -> void:
	for r in layout["solids"]:
		var body := StaticBody2D.new()
		body.position = r.position + r.size / 2.0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		shape.shape = rect
		body.add_child(shape)
		var visual := ColorRect.new()
		visual.size = r.size
		visual.position = -r.size / 2.0
		visual.color = Color(0.25, 0.22, 0.2)
		body.add_child(visual)
		parent.add_child(body)
```

`scripts/ui/hud.gd`:

```gdscript
class_name Hud
extends CanvasLayer
## HP, active slots, the Great Sage pop-up, the ticker, and the inspect/status panel.

const PANEL_SECONDS := 4.0
const TICKER_SECONDS := 3.0

var _player: Player
var _rules
var _queue: AnnouncerQueue
var _hp := Label.new()
var _slots := Label.new()
var _popup := Label.new()
var _ticker := Label.new()
var _panel := Label.new()
var _panel_left := 0.0
var _ticker_lines: Array = []  # [[text, seconds_left]]

func bind(player: Player, rules, _compendium: CompendiumModel, queue: AnnouncerQueue) -> void:
	_player = player
	_rules = rules
	_queue = queue
	player.inspect_report.connect(_on_inspect_report)

func _ready() -> void:
	_hp.position = Vector2(12, 8)
	_slots.position = Vector2(12, 28)
	_popup.position = Vector2(320, 24)
	_ticker.position = Vector2(12, 300)
	_panel.position = Vector2(700, 60)
	for l in [_hp, _slots, _popup, _ticker, _panel]:
		add_child(l)

func _process(delta: float) -> void:
	if _player == null:
		return
	_hp.text = hp_text()
	_slots.text = StatusText.slot_line(_player.skillset.slots, _rules)
	_popup.text = popup_text()
	var entry := _queue.pop_ticker()
	while not entry.is_empty():
		_ticker_lines.append([StatusText.ticker_text(entry, _rules), TICKER_SECONDS])
		entry = _queue.pop_ticker()
	for line in _ticker_lines:
		line[1] -= delta
	_ticker_lines = _ticker_lines.filter(func(l): return l[1] > 0.0)
	_ticker.text = "\n".join(_ticker_lines.map(func(l): return l[0]))
	_panel_left = maxf(0.0, _panel_left - delta)
	_panel.visible = _panel_left > 0.0

func hp_text() -> String:
	return "HP %d/%d" % [_player.health.hp, _player.health.max_hp]

func popup_text() -> String:
	var current := _queue.current()
	return current.get("text", "") if not current.is_empty() else ""

func _on_inspect_report(lines: PackedStringArray) -> void:
	_panel.text = "\n".join(lines)
	_panel_left = PANEL_SECONDS
```

`scripts/game.gd`:

```gdscript
extends Node2D
## The vertical slice: builds the test room, spawns actors and the HUD, starts a run.
## Death resets the run and reloads the scene (the full death screen is Plan 3).

var player: Player
var hud: Hud

func _ready() -> void:
	Controls.ensure_actions()
	var layout: Dictionary = RoomLayout.TEST_ROOM
	RoomBuilder.build(self, layout)
	var skills_by_id := {}
	for d in SkillRules.skill_defs:
		skills_by_id[d.id] = d
	var creatures := {}
	for c in SkillRules.creature_defs:
		creatures[c.id] = c
	player = Player.new()
	player.setup(SkillRules, Compendium.model, SkillRules.creature_defs, _emit_game_event)
	player.position = layout["player"]
	add_child(player)
	player.add_child(Camera2D.new())
	for spawn in layout["spawns"]:
		var def: CreatureDef = creatures[spawn["id"]]
		var node: Node2D
		if def.id == Sources.WATER_POOL:
			node = WaterPool.new()
			node.setup(def)
		else:
			node = Enemy.new()
			node.setup(def, skills_by_id)
		node.position = spawn["pos"]
		add_child(node)
	player.skillset.slot_replaced.connect(Announcer.queue.push_slot_replaced)
	hud = Hud.new()
	add_child(hud)
	hud.bind(player, SkillRules, Compendium.model, Announcer.queue)
	player.died.connect(_on_player_died)
	SkillRules.start_run()

func _emit_game_event(event_name: String, tags: Dictionary) -> void:
	EventBus.game_event.emit(event_name, tags)

func _on_player_died() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()
	get_tree().reload_current_scene.call_deferred()
```

`scenes/main.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/game.gd" id="1"]

[node name="Game" type="Node2D"]
script = ExtResource("1")
```

In `project.godot`, add this under `[application]`:

```ini
run/main_scene="res://scenes/main.tscn"
```

- [ ] **Step 4: Import and run**

Run: `gtimeout -k 5 180 env HOME="$PWD/.tmp/gdhome" godot --headless --import > .tmp/test-logs/import.log 2>&1; tools/run_tests.sh test_game`
Expected: `PASS: 3 tests`.

- [ ] **Step 5: Run the full suite, then commit**

Run: `tools/run_tests.sh`. Expected: all tests pass.

```bash
git add scripts/world scripts/ui/hud.gd scripts/game.gd scenes/main.tscn project.godot tests/test_game.gd
git commit -m "feat: add the test room, HUD and main scene for the vertical slice"
```

---

### Task 12: Boot check and the playtest checklist

**Files:**
- Create: `docs/playtest-checklist.md`

**Interfaces:**
- Produces: a headless boot of the main scene with no script errors, and a manual checklist for Sean.

- [ ] **Step 1: Boot the real main scene headless for 300 frames**

```bash
gtimeout -k 5 60 env HOME="$PWD/.tmp/gdhome" godot --headless --quit-after 300 > .tmp/test-logs/boot.log 2>&1; echo exit=$?
grep -nE 'SCRIPT ERROR|Parse Error' .tmp/test-logs/boot.log || echo "boot clean"
```

Expected: `exit=0` and `boot clean`. A `get_system_ca_certificates` engine line on macOS is known environment noise (see the Plan 1 ledger), not a project error.

- [ ] **Step 2: Write `docs/playtest-checklist.md`**

```markdown
# Vertical slice playtest checklist

Run: open the project in Godot 4.7 and press F5 (or `godot` in the project folder).

Controls: A/D move · Space jump · J tackle · K hold to eat · I inspect · U/O actives · Tab cycle

- [ ] Jump feels responsive; after ~40 jumps a Great Sage pop-up announces Leap and jumps get higher.
- [ ] Touching the tall column mid-air ~15 times unlocks Wall Cling; sliding down it is slower; Space jumps off it.
- [ ] Tackle (J) stuns a bat; holding K next to it for ~1 s eats it and heals.
- [ ] A lizard can't be stunned head-on, only from behind.
- [ ] Killing an enemy leaves a body you can eat for ~5 s.
- [ ] Eating 3 bats announces Echolocation; eating toads/spiders eventually announces Poison Breath.
- [ ] Both water pools can be eaten once each; 4 water unlocks Hydraulic Propulsion into slot U.
- [ ] U fires the active in slot 1; Tab swaps it with another owned active; level-ups appear on the ticker.
- [ ] I with nothing near shows your status (HP, stats with eat/skill split, skills, essences).
- [ ] I near a creature shows more info as Appraisal levels up (name/HP → stats/essences → skills).
- [ ] Toads spit poison: an initial hit then ticks that stop at 1 HP.
- [ ] Dying reloads the room with a fresh run; the Compendium keeps what you discovered.
- [ ] Pop-ups are readable and don't pause the game.
```

- [ ] **Step 3: Commit**

```bash
git add docs/playtest-checklist.md
git commit -m "docs: add vertical slice playtest checklist"
```

---

## Handoff to Plan 3 (full run)

Plan 3 covers:
- **Enemy-only ability scenes:** Tail Swipe, Constrict, and a Poison Spit projectile that replaces the toad's instant spit.
- **Constructive room generation** from chunks, with placement rules and hidden passages revealed by Echolocation.
- **The serpent boss.** Its 0 HP means victory.
- **The death/victory screen** and the Compendium screen.
- **The per-run log** at `user://runs.jsonl`.

It also needs to carry these items:
- The Plan 1 deferred minors that touch these areas: the eat-bonus cap scope, and `AnnouncerQueue.current()` returning its internal dictionary by reference.
