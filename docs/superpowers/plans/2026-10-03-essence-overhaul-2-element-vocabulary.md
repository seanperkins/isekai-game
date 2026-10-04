# Essence Overhaul, Part 2: The Element Vocabulary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The ten trait essences become five elements (water, earth, air, light, dark): every creature carries elements, Poison Breath, Spore Cloud and Jolt unlock from mixes, Sticky Thread unlocks by eating three Black Spiders, and the calibration that keeps today's unlock timing is pinned in a test.

**Architecture:** `tools/build_content.gd` stays the source of truth for `data/skills` and `data/creatures`; a one-shot rewrite of its essence tables regenerates the data. Mix unlocks need no engine change (`unlock` is already an AND of counters). A small shared `CalibrationWalk` helper (in `tests/support`) walks the shipped map and eats every spawn so a tool and a test report the same unlock points.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`), Python 3 for the one-shot edit script.

**Spec:** `docs/superpowers/specs/2026-10-03-essence-overhaul-design.md` (approved by Sean; the "Elements", "Mapping", "Thread", "Mix unlocks", "Calibration", "Display" rows and `Sequencing` step 2). Part 1 (`2026-10-03-essence-overhaul-1-forms-by-powers.md`) must be merged first; part 3 (`...-3-price-held-ep.md`) follows.

## Global Constraints

- Godot 4.7 / GDScript / GUT 9.7.1. A SCRIPT ERROR or Parse Error fails the whole run. Every new `class_name` script needs `env HOME="$PWD/.tmp/gdhome" godot --headless --import` and its `.uid` file committed. Content is generated: edit `tools/build_content.gd`, then run `env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd`.
- `Essences.ALL` is exactly `["water", "earth", "air", "light", "dark"]` (this order: `Player._complete_predation` emits `ABSORBED` in `Essences.ALL` order). Fire, mind and blood join with the first creature that carries them.
- Mapping (each trait unit becomes one unit of each element it maps to; duplicates add): sound, flight → air · poison → water + dark · spore → air + dark · armor, shell → earth · shock → light + air · thread → dropped · water, earth unchanged.
- Derived creature table (the only numbers): bat air 2 · toad water 2, dark 1 · lizard earth 2 · spider water 1, dark 1 · spore_moth air 2, dark 1 · mushroom_crab earth 3 · vine_snake water 1, dark 1 · pale_moth air 5, dark 3 · glass_eel light 1, air 1, water 1 · cave_crayfish earth 1, water 1 · drift_jelly light 1, air 1, water 2 · bog_lizardman earth 1, water 1 (unchanged) · storm_eel light 3, air 3, water 2 · gloom_wolf air 1, earth 1 · armed_ant earth 2 · stone_drake earth 4 · taratect water 2, dark 2 · water_pool water 2 (unchanged) · serpent none.
- Unlock thresholds (starting values, verified on a scratch build against today's data on the Cave-start walk): Echolocation `air ≥ 6`, levels on air with `level_curve` 9 · Hydraulic Propulsion `water ≥ 8` · Poison Breath `water ≥ 4` and `dark ≥ 4` · Spore Cloud `air ≥ 8` and `dark ≥ 4` · Jolt `light ≥ 4` and `air ≥ 4` · Body Armor `earth ≥ 6` · Hardened Shell `earth ≥ 14` · Tremor `earth ≥ 59` · Sticky Thread `predated` with `{"source": "spider"}` ×3 · Regeneration unchanged.
- Calibration rule (priority order): reachability is hard (every power reachable from the Cave start and from each rebirth start by some walk of the whole map without farming); the Cave-start walk is the target (each power within one eat of today's point); rebirth-start timing is not held and its moves are recorded in `docs/ledgers/essence-calibration.md`.
- Process: TDD with a failing run first; no attribution lines in commit messages; report only commit SHAs copied from `git` output; scratch files under `<checkout>/.tmp/`, never `/tmp`; work on a branch cut from the merged part 1.
- Test commands: `tools/run_tests.sh <substring>`; `TEST_TIMEOUT=900 tools/run_tests.sh` for the whole suite. Success prints `PASS: N tests`.

## Review Focus

1. **A creature that carries nothing.** The Cave Serpent (`essences {}`) and creatures the table leaves alone. Expect: no `absorbed` events, no validator error, the status screen lists no element (Task 2).
2. **A typo in an unlock's `source` or `essence`.** Expect: `DefValidator` rejects an unknown source (`"spidr"`) and an unknown element, so a power can never be silently unobtainable (Task 2 test).
3. **Appraisal hints flooding.** A bat carries air; Spore Cloud needs air and dark; Jolt needs light and air. Expect: appraising a bat names Echolocation only (Task 3).
4. **A rebirth start that must walk back.** G1, F1 and D1 meet no Black Spider going forward. Expect: Sticky Thread is still reachable (a later eat) from each start, never "0" (Task 4).
5. **A kill that the old unlock counted twice.** A Taratect used to carry thread 3. Expect: it counts once toward Sticky Thread only if its `source` is `spider`; it is `taratect`, so it counts for nothing (Task 2 note, Task 4 pin).

---

## File map

- Modify `scripts/core/essences.gd` — the five elements.
- Modify `tools/build_content.gd` (via a one-shot script) and regenerate `data/skills/*.tres`, `data/creatures/*.tres`.
- Modify `scripts/skills/skill_def.gd` — `sources_used()`.
- Modify `scripts/compendium/compendium_model.gd` — the hint rule.
- Modify `scripts/ui/skill_screen_model.gd` — the `predated` wording.
- Create `tests/support/calibration_walk.gd`, `tools/calibrate_essences.gd`, `docs/ledgers/essence-calibration.md`.
- Modify `tests/support/test_defs.gd` — `satisfy()`.
- Modify tests: `test_constants`, `test_content`, `test_grotto_data`, `test_flooded_data`, `test_deep_data`, `test_deep_slice`, `test_pale_moth`, `test_skill_screen`, `test_status_text`, `test_scripted_run`, `test_web_tether`, `test_form_effects`, `test_player`, `test_skill_caps`, `test_form_tab`, `test_defs`; create `test_creature_hints`.
- Modify tools: `tools/aim_shots.gd`, `tools/vfx_shots.gd`, `tools/evolution_shots.gd`.

---

### Task 1: `TestDefs.satisfy`, a helper that fires an unlock's events

Tests that unlock a real power should not hard-code a threshold the calibration may tune.

**Files:**
- Modify: `tests/support/test_defs.gd`
- Test: `tests/test_defs.gd`

**Interfaces:**
- Consumes: `SkillRulesEngine.get_def(id) -> SkillDef`, `handle_event(name, tags)`, `SkillDef.unlock` (counter conditions: `{"kind": "counter", "event", "tags", "n"}`).
- Produces: `TestDefs.satisfy(rules: SkillRulesEngine, id: String) -> void` — fires every counter condition's event `n` times with a copy of its tags.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_defs.gd`:

```gdscript
func test_satisfy_fires_the_events_a_counter_unlock_needs() -> void:
	var engine: SkillRulesEngine = autofree(SkillRulesEngine.new())
	var d := TestDefs.skill("s", {"unlock": [TestDefs.counter("jumped", 3), TestDefs.counter("absorbed", 2, {"essence": "air"})]})
	engine.setup([d])
	engine.start_run()
	TestDefs.satisfy(engine, "s")
	assert_eq(engine.level_of("s"), 1)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `tools/run_tests.sh test_defs`
Expected: `FAIL: engine error or empty run` (`satisfy` does not exist).

- [ ] **Step 3: Add the helper**

Append to `tests/support/test_defs.gd`:

```gdscript

## Fires the events that satisfy `id`'s counter unlocks, so a test need not repeat a threshold the calibration may tune.
static func satisfy(rules: SkillRulesEngine, id: String) -> void:
	var d: SkillDef = rules.get_def(id)
	for c in d.unlock:
		if c.get("kind", "") == "counter":
			for i in int(c["n"]):
				rules.handle_event(c["event"], c.get("tags", {}).duplicate())
```

- [ ] **Step 4: Run it to verify it passes**

Run: `tools/run_tests.sh test_defs`
Expected: `PASS: <n> tests`

- [ ] **Step 5: Commit**

```bash
git add tests/support/test_defs.gd tests/test_defs.gd
git commit -m "test: TestDefs.satisfy fires the events an unlock needs"
```

---

### Task 2: Switch the vocabulary: elements, creatures, unlocks, pins (one atomic change)

Skills and creatures name essences, the validator reads `Essences.ALL`, and a dozen tests pin both, so they change together.

**Files:**
- Modify: `scripts/core/essences.gd`
- Modify: `tools/build_content.gd` (by script), regenerate `data/skills/*.tres` and `data/creatures/*.tres`
- Modify tools: `tools/aim_shots.gd`, `tools/vfx_shots.gd`, `tools/evolution_shots.gd`
- Test: `tests/test_constants.gd`, `tests/test_content.gd`, `tests/test_grotto_data.gd`, `tests/test_flooded_data.gd`, `tests/test_deep_data.gd`, `tests/test_deep_slice.gd`, `tests/test_pale_moth.gd`, `tests/test_skill_screen.gd`, `tests/test_status_text.gd`, `tests/test_scripted_run.gd`, `tests/test_web_tether.gd`, `tests/test_form_effects.gd`, `tests/test_player.gd`, `tests/test_skill_caps.gd`, `tests/test_form_tab.gd`

**Interfaces:**
- Consumes: `TestDefs.satisfy` (Task 1); `DefValidator` (checks `essence` tags against `Essences.ALL` and `source` tags against `Sources.ALL`).
- Produces: `Essences.WATER/EARTH/AIR/LIGHT/DARK` string constants and `Essences.ALL`; the regenerated content under the thresholds in Global Constraints.

- [ ] **Step 1: Write the failing pins first**

`tests/test_constants.gd`: replace the `Essences.ALL` assertion with

```gdscript
	assert_eq(Essences.ALL, ["water", "earth", "air", "light", "dark"])
```

`tests/test_content.gd`:
- in `test_creature_numbers_are_verbatim` replace `assert_eq(_creature("toad").essences, {"poison": 1, "water": 1})` with `assert_eq(_creature("toad").essences, {"water": 2, "dark": 1})`;
- in `test_spec_numbers_are_verbatim` replace the Echolocation, Poison Breath and Hydraulic lines (`echolocation ... 3`, `poison_breath ... 4`, `hydraulic_propulsion ... 4`) with:

```gdscript
	assert_eq(_skill("echolocation").unlock[0], {"kind": "counter", "event": "absorbed", "tags": {"essence": "air"}, "n": 6})
	assert_eq(_skill("poison_breath").unlock.size(), 2, "poison is water and dark")
	assert_eq(_skill("poison_breath").unlock[0]["n"], 4)
	assert_eq(_skill("hydraulic_propulsion").unlock[0], {"kind": "counter", "event": "absorbed", "tags": {"essence": "water"}, "n": 8})
	assert_eq(_skill("sticky_thread").unlock[0], {"kind": "counter", "event": "predated", "tags": {"source": "spider"}, "n": 3})
```

- replace `test_essence_minimums_satisfy_every_essence_skill` with the version below (the census gains the Flooded's earth carriers so Tremor's `earth ≥ 59` is reachable from the minimums, and a branch for the spider-unlocked Sticky Thread):

```gdscript
func test_essence_minimums_satisfy_every_essence_skill() -> void:
	# Placement minimums from the spec: 3 bats, 4 toads, 3 lizards, 3 spiders, 2 pools.
	# The Grotto's creatures add air and dark (4 moths) and earth (2 crabs). The Flooded adds light (4 eels) and earth (5 crayfish
	# and 6 lizardmen, a unit each). The Deep adds the rest of Tremor's earth: its census is 9 wolves, 9 ants and 3 drakes.
	var minimums := {"bat": 3, "toad": 4, "lizard": 3, "spider": 3, "water_pool": 2, "spore_moth": 4, "mushroom_crab": 2, "glass_eel": 4,
		"cave_crayfish": 5, "bog_lizardman": 6, "gloom_wolf": 9, "armed_ant": 9, "stone_drake": 3}
	var totals := {}
	for sid in minimums:
		var c := _creature(sid)
		for ess in c.essences:
			totals[ess] = int(totals.get(ess, 0)) + int(c.essences[ess]) * minimums[sid]
	for d in skills:
		if d.source != "essence":
			continue
		for cond in d.unlock:
			if cond["event"] == "absorbed":
				assert_gte(int(totals.get(cond["tags"]["essence"], 0)), int(cond["n"]), d.id)
			elif cond["event"] == "predated" and cond.get("tags", {}).has("source"):
				assert_gte(int(minimums.get(cond["tags"]["source"], 0)), int(cond["n"]), "%s: eats of %s" % [d.id, cond["tags"]["source"]])
```

`tests/test_grotto_data.gd`: in `test_new_essences_and_sources_are_registered` replace the two `Essences.ALL.has("spore"/"shell")` lines with `assert_true(Essences.ALL.has("air"))` and `assert_true(Essences.ALL.has("dark"))`; in `test_the_creatures_have_the_approved_numbers` change the three essence dicts to `{"air": 2, "dark": 1}` (spore_moth), `{"earth": 3}` (mushroom_crab), `{"water": 1, "dark": 1}` (vine_snake); in `test_the_two_skills_match_the_spec` replace the Spore Cloud and Hardened Shell unlock lines with:

```gdscript
	assert_eq(sc.unlock[0]["tags"], {"essence": "air"})
	assert_eq(sc.unlock[0]["n"], 8)
	assert_eq(sc.unlock[1]["tags"], {"essence": "dark"})
	assert_eq(sc.unlock[1]["n"], 4)
```
and
```gdscript
	assert_eq(hs.unlock[0]["tags"], {"essence": "earth"})
	assert_eq(hs.unlock[0]["n"], 14)
```

`tests/test_flooded_data.gd`: `Essences.ALL.has(Essences.SHOCK)` → `Essences.ALL.has(Essences.LIGHT)`; eel `{"shock": 1, "water": 1}` → `{"light": 1, "air": 1, "water": 1}`; crayfish `{"shell": 1, "water": 1}` → `{"earth": 1, "water": 1}`; jelly `{"shock": 1, "water": 2}` → `{"light": 1, "air": 1, "water": 2}`; storm eel `{"shock": 3, "water": 2}` → `{"light": 3, "air": 3, "water": 2}`; in `test_swim_and_jolt` replace `assert_eq(jolt.unlock[0]["tags"], {"essence": "shock"})` with `assert_eq(jolt.unlock[0]["tags"], {"essence": "light"})` and `assert_eq(jolt.unlock[1]["tags"], {"essence": "air"})`. (The `contact_type` `"shock"` assertions are a damage type and stay.)

`tests/test_deep_data.gd`: wolf `{"sound": 1, "earth": 1}` → `{"air": 1, "earth": 1}`; ant `{"armor": 1, "earth": 1}` → `{"earth": 2}`; drake `{"earth": 3, "armor": 1}` → `{"earth": 4}`; Tremor `assert_eq(t.unlock[0]["n"], 24)` → `59`; in `test_the_tremor_threshold_is_above_the_pre_deep_earth_supply` change the message text `(4 lizards, 12 crabs, 6 lizardmen)` to `(4 lizards, 12 crabs, 5 crayfish, 6 lizardmen)`.

`tests/test_deep_slice.gd`: `{"thread": 3, "poison": 2}` → `{"water": 2, "dark": 2}`. `tests/test_pale_moth.gd`: `{"spore": 3, "flight": 2}` → `{"air": 5, "dark": 3}`.

`tests/test_player.gd`: replace the `assert_eq(events.slice(0, 3), ...)` block of `test_predation_completes_after_hold_and_absorbs_essences` with:

```gdscript
	assert_eq(events.slice(0, 4), [["predated", {"source": "toad", "kind": "creature"}],
		["absorbed", {"essence": "water", "source": "toad"}], ["absorbed", {"essence": "water", "source": "toad"}],
		["absorbed", {"essence": "dark", "source": "toad"}]])
```

`tests/test_skill_caps.gd`, in `test_the_top_levels_are_reachable_against_what_their_sources_supply`: rename the local `sound` to `air` — `var sound := 0` → `var air := 0`, `sound += int(c.essences.get("sound", 0))` → `air += int(c.essences.get("air", 0))`, and in the Echolocation lines use `air`:

```gdscript
	# Echolocation levels on absorbed air: rooms respawn, so laps of the Cave farm it, but not in a handful
	var echo_needed: int = (defs["echolocation"].max_level - 1) * defs["echolocation"].level_curve
	assert_lte(echo_needed, air * 6, "Echolocation's top level (%d air) is within six laps of the Cave (%d per lap)" % [echo_needed, air])
	assert_gt(echo_needed, air, "and is more than a single lap, so it is not trivial")
```

`tests/test_form_tab.gd`: in `_eat_everything`, emit the eat as well as the essences, so Sticky Thread unlocks as it does in play:

```gdscript
func _eat_everything() -> void:
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var rooms := World.load_rooms("res://data/rooms")
	for id in rooms:
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			rules.handle_event("predated", {"source": c.id, "kind": "creature"})
			for e in c.essences:
				for i in int(c.essences[e]):
					rules.handle_event("absorbed", {"essence": e, "source": c.id})
```

Tests that unlock a real power with an old shorthand switch to `TestDefs.satisfy`:
- `tests/test_skill_screen.gd`: the three `_emit("absorbed", {"essence": "poison"}, 4)` lines become `TestDefs.satisfy(rules, "poison_breath")`; in `test_screen_lists_navigates_and_assigns` the two lines `_emit("absorbed", {"essence": "water"}, 4)` and `_emit("absorbed", {"essence": "poison"}, 4)` become `TestDefs.satisfy(rules, "hydraulic_propulsion")` and `TestDefs.satisfy(rules, "poison_breath")`.
- `tests/test_status_text.gd`: in `test_self_lines_show_stats_skills_essences_and_bands_without_numbers` replace the `for i in 3:` loop of `absorbed sound` with `TestDefs.satisfy(rules, "echolocation")` and the assertion `assert_string_contains(text, "sound 3")` with `assert_string_contains(text, "air 6")`; in `test_slot_and_ticker_text` replace the `for i in 4:` loop of `absorbed water` with `TestDefs.satisfy(rules, "hydraulic_propulsion")`.
- `tests/test_web_tether.gd` (the `for i in 3:` loop that absorbs `thread`): replace the loop with `TestDefs.satisfy(rules, "sticky_thread")  # Sticky Thread, slot 0`.
- `tests/test_form_effects.gd` (`test_sonar_reads_echolocation_one_level_stronger`): replace the `for i in 3:` loop of `absorbed sound` with `TestDefs.satisfy(rules, "echolocation")`.
- `tests/test_scripted_run.gd`: change the bat eat to `_eat("bat", {"air": 2})           # Echolocation (air 6) on the 3rd bat`; the water pool loop to `for i in 4:` with the comment `# Hydraulic Propulsion (8 water)`; the toad eat to `_eat("toad", {"water": 2, "dark": 1})`; the spider eat to `_eat("spider", {"water": 1, "dark": 1})`.

- [ ] **Step 2: Run the pins to verify they fail**

Run: `tools/run_tests.sh test_constants` and `tools/run_tests.sh test_content`
Expected: both FAIL (`Essences.ALL` is still the ten names; the toad still carries poison).

- [ ] **Step 3: Write the elements and rewrite the content generator**

Replace the whole of `scripts/core/essences.gd` with:

```gdscript
class_name Essences
extends RefCounted
## Essence names: the first-pass elements. Fire, mind and blood join with the first creature that carries them. The order is
## canonical: Player emits ABSORBED in this order.

const WATER := "water"
const EARTH := "earth"
const AIR := "air"
const LIGHT := "light"
const DARK := "dark"

const ALL := [WATER, EARTH, AIR, LIGHT, DARK]
```

Create the one-shot edit script at `.tmp/vocab/apply_vocabulary.py` (scratch, not committed; `mkdir -p .tmp/vocab` first):

```python
import re

path = "tools/build_content.gd"
src = open(path).read()

creatures = {
    "bat": '{"air": 2}',
    "toad": '{"water": 2, "dark": 1}',
    "lizard": '{"earth": 2}',
    "spider": '{"water": 1, "dark": 1}',
    "spore_moth": '{"air": 2, "dark": 1}',
    "mushroom_crab": '{"earth": 3}',
    "vine_snake": '{"water": 1, "dark": 1}',
    "pale_moth": '{"air": 5, "dark": 3}',
    "glass_eel": '{"light": 1, "air": 1, "water": 1}',
    "cave_crayfish": '{"earth": 1, "water": 1}',
    "drift_jelly": '{"light": 1, "air": 1, "water": 2}',
    "storm_eel": '{"light": 3, "air": 3, "water": 2}',
    "gloom_wolf": '{"air": 1, "earth": 1}',
    "armed_ant": '{"earth": 2}',
    "stone_drake": '{"earth": 4}',
    "taratect": '{"water": 2, "dark": 2}',
}
for cid, ess in creatures.items():
    pattern = re.compile(r'("id": "%s".*?"essences": )\{[^}]*\}' % cid, re.S)
    src, n = pattern.subn(lambda m: m.group(1) + ess, src, count=1)
    assert n == 1, cid

# Order matters: Hydraulic Propulsion's water 4 must go before Poison Breath's new water 4 is written.
pairs = [
    ('_c("absorbed", 3, {"essence": "sound"})', '_c("absorbed", 6, {"essence": "air"})'),
    ('_on("absorbed", {"essence": "sound"}), "level_curve": 3', '_on("absorbed", {"essence": "air"}), "level_curve": 9'),
    ('_c("absorbed", 4, {"essence": "water"})', '_c("absorbed", 8, {"essence": "water"})'),
    ('_c("absorbed", 4, {"essence": "poison"})', '_c("absorbed", 4, {"essence": "water"}), _c("absorbed", 4, {"essence": "dark"})'),
    ('_c("absorbed", 3, {"essence": "armor"})', '_c("absorbed", 6, {"essence": "earth"})'),
    ('_c("absorbed", 3, {"essence": "thread"})', '_c("predated", 3, {"source": "spider"})'),
    ('_c("absorbed", 4, {"essence": "spore"})', '_c("absorbed", 8, {"essence": "air"}), _c("absorbed", 4, {"essence": "dark"})'),
    ('_c("absorbed", 4, {"essence": "shell"})', '_c("absorbed", 14, {"essence": "earth"})'),
    ('_c("absorbed", 4, {"essence": "shock"})', '_c("absorbed", 4, {"essence": "light"}), _c("absorbed", 4, {"essence": "air"})'),
    ('_c("absorbed", 24, {"essence": "earth"})', '_c("absorbed", 59, {"essence": "earth"})'),
]
for old, new in pairs:
    assert src.count(old) == 1, old
    src = src.replace(old, new)

open(path, "w").write(src)
print("build_content.gd rewritten")
```

Run it and regenerate the data:

```bash
mkdir -p .tmp/vocab .tmp/gdhome
python3 .tmp/vocab/apply_vocabulary.py
env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/build_content.gd
git diff --stat data/skills data/creatures
```

Expected: `build_content.gd rewritten`, a run of `wrote res://data/...` lines, and a diff touching the creatures and skills whose lines changed (about 16 creature files and the skill files for Echolocation, Poison Breath, Body Armor, Sticky Thread, Hydraulic Propulsion, Spore Cloud, Hardened Shell, Jolt and Tremor). Update the creature doc comment in `scripts/skills/creature_def.gd` (`## Essence -> units absorbed per eat, e.g. {"sound": 1, "flight": 1}`) to `e.g. {"air": 2}`.

Update the three screenshot tools. In `tools/aim_shots.gd` replace

```gdscript
			for i in 4:
				rules.handle_event("absorbed", {"essence": "water", "source": "shots"})  # Hydraulic Propulsion, slot 1
			for i in 3:
				rules.handle_event("absorbed", {"essence": "thread", "source": "shots"})
```

with

```gdscript
			for i in 8:
				rules.handle_event("absorbed", {"essence": "water", "source": "shots"})  # Hydraulic Propulsion, slot 1
			for i in 3:
				rules.handle_event("predated", {"source": "spider", "kind": "creature"})  # Sticky Thread
```

In `tools/vfx_shots.gd` replace

```gdscript
			for i in 3:
				rules.handle_event("absorbed", {"essence": "thread", "source": "shots"})  # Sticky Thread, slot 0
			for i in 4:
				rules.handle_event("absorbed", {"essence": "water", "source": "shots"})  # Hydraulic Propulsion, slot 1
```

with

```gdscript
			for i in 3:
				rules.handle_event("predated", {"source": "spider", "kind": "creature"})  # Sticky Thread, slot 0
			for i in 8:
				rules.handle_event("absorbed", {"essence": "water", "source": "shots"})  # Hydraulic Propulsion, slot 1
```

In `tools/evolution_shots.gd` replace the comment and loop

```gdscript
			# eat a bit of everything so the offers include Weaver, Tide and Toxic
			for e in ["thread", "water", "poison", "sound"]:
				for i in 6:
					root.get_node("SkillRules").handle_event("absorbed", {"essence": e, "source": "shots"})
```

with

```gdscript
			# eat a bit of everything so the offers include every lineage
			for e in ["water", "dark", "air", "earth"]:
				for i in 14:
					root.get_node("SkillRules").handle_event("absorbed", {"essence": e, "source": "shots"})
			for i in 3:
				root.get_node("SkillRules").handle_event("predated", {"source": "spider", "kind": "creature"})
```

- [ ] **Step 4: Run the affected tests**

Run each: `tools/run_tests.sh test_constants`, `test_content`, `test_grotto_data`, `test_flooded_data`, `test_deep_data`, `test_deep_slice`, `test_pale_moth`, `test_skill_screen`, `test_status_text`, `test_scripted_run`, `test_web_tether`, `test_form_effects`, `test_player`, `test_skill_caps`, `test_form_tab`, `test_def_validator`
Expected: `PASS: <n> tests` for each. If `test_skill_screen` fails on the `condition_text` expectation for Echolocation (`Absorb sound essence ×3`), leave it: Task 3 rewrites that line with the new wording; note it and continue (or change the expected text to `Absorb air essence ×6` now).

- [ ] **Step 5: Closing grep and the full suite**

```bash
grep -rnE "\"essence\": \"(sound|flight|poison|armor|thread|spore|shell|shock)\"|Essences\.(SOUND|FLIGHT|POISON|ARMOR|THREAD|SPORE|SHELL|SHOCK)|\{\"(sound|flight|armor|thread|spore|shell|shock)\": " scripts tests tools --include='*.gd'
```

Expected: no output other than tests that deliberately build their own stub defs (`test_accessors`, `test_defs`, `test_skill_rules_levels`, `test_audio_runtime`, `test_compendium_model`, and the `status_text` creature-lines dict): those use trait names as opaque data in fixtures that never touch the validator or `Essences.ALL`, and they stay.

Run: `TEST_TIMEOUT=900 tools/run_tests.sh`
Expected: `PASS: <n> tests` with no `SCRIPT ERROR`. If the full run shows another test pinning a retired name, update it the same way (`TestDefs.satisfy` for an unlock shorthand, the new element for a creature pin) and rerun; the grep above is the authoritative list.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/essences.gd scripts/skills/creature_def.gd tools data tests
git commit -m "feat: the ten trait essences become five elements

Water, earth, air, light and dark. Poison Breath, Spore Cloud and Jolt unlock
from mixes, Sticky Thread from eating three Black Spiders, and the creature
table and thresholds are derived from the spec's mapping."
```

---

### Task 3: The creature hint needs every element, or the named source; the unlock wording names the creature

**Files:**
- Modify: `scripts/skills/skill_def.gd`
- Modify: `scripts/compendium/compendium_model.gd`
- Modify: `scripts/ui/skill_screen_model.gd`
- Test: `tests/test_creature_hints.gd` (create), `tests/test_skill_screen.gd`, `tests/test_def_validator.gd`

**Interfaces:**
- Consumes: `SkillDef.essences_used() -> Array`, `Events.PREDATED`, `CompendiumModel.creature_report(source, level, apply)`, `CompendiumModel.state(id)`.
- Produces: `SkillDef.sources_used() -> Array` (creature ids named by `predated` counters); a creature hints a power when it carries every element of the recipe or its id is in `sources_used()`; `SkillScreenModel.condition_text` renders a `predated`-with-`source` counter as `Eat a <Source> ×n`.

- [ ] **Step 1: Write the failing tests**

Create `tests/test_creature_hints.gd`:

```gdscript
extends GutTest
## Which powers a creature names when it is appraised (Appraisal level 2), with the real content.

const S := CompendiumModel.State

func _model() -> CompendiumModel:
	return CompendiumModel.new(DefLoader.load_dir("res://data/skills"), DefLoader.load_dir("res://data/creatures"))

func _named_by(creature_id: String) -> Array:
	var m := _model()
	m.creature_report(creature_id, 2, true)
	var out: Array = []
	for id in ["echolocation", "hydraulic_propulsion", "poison_breath", "spore_cloud", "jolt", "body_armor", "hardened_shell", "tremor", "sticky_thread"]:
		if m.state(id) == S.NAMED:
			out.append(id)
	return out

func test_a_bat_names_echolocation_but_not_the_mixes_it_only_half_carries() -> void:
	assert_eq(_named_by("bat"), ["echolocation"], "air alone is not Spore Cloud (needs dark) or Jolt (needs light)")

func test_a_toad_names_poison_breath_and_hydraulic_propulsion() -> void:
	assert_eq(_named_by("toad"), ["hydraulic_propulsion", "poison_breath"])

func test_a_spore_moth_carries_both_halves_of_spore_cloud() -> void:
	var named := _named_by("spore_moth")
	assert_true(named.has("spore_cloud"))
	assert_true(named.has("echolocation"))

func test_a_black_spider_names_sticky_thread_because_it_is_the_creature_to_eat() -> void:
	assert_true(_named_by("spider").has("sticky_thread"))

func test_a_vine_snake_no_longer_names_sticky_thread() -> void:
	var named := _named_by("vine_snake")
	assert_false(named.has("sticky_thread"), "its thread is gone and it is not the source the unlock names")
	assert_true(named.has("poison_breath"))

func test_an_eel_carries_both_halves_of_jolt() -> void:
	assert_true(_named_by("glass_eel").has("jolt"))
```

In `tests/test_skill_screen.gd`, replace the condition-text expectations (the `Absorb sound essence ×3` line) and extend them:

```gdscript
	assert_eq(SkillScreenModel.condition_text(by_id["echolocation"], by_id), "Absorb air essence ×6")
	assert_eq(SkillScreenModel.condition_text(by_id["poison_breath"], by_id), "Absorb water essence ×4 and Absorb dark essence ×4")
	assert_eq(SkillScreenModel.condition_text(by_id["sticky_thread"], by_id), "Eat a Spider ×3")
```

In `tests/test_def_validator.gd`, append (using the file's existing helpers; the file builds defs with `TestDefs.skill` and calls `DefValidator.validate(skills, creatures)`; mirror the nearest existing unknown-source test for the exact call shape):

```gdscript
func test_an_unknown_source_in_an_unlock_is_rejected() -> void:
	var s := [TestDefs.skill("s", {"unlock": [TestDefs.counter("predated", 3, {"source": "spidr"})]})]
	var errs := DefValidator.validate(s, TestDefs.all_creatures())
	assert_string_contains("\n".join(errs), "unknown source 'spidr'")

func test_an_unknown_element_in_an_unlock_is_rejected() -> void:
	var s := [TestDefs.skill("s", {"unlock": [TestDefs.counter("absorbed", 3, {"essence": "poison"})]})]
	var errs := DefValidator.validate(s, TestDefs.all_creatures())
	assert_string_contains("\n".join(errs), "unknown essence 'poison'")
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools/run_tests.sh test_creature_hints`
Expected: FAIL (the bat names Spore Cloud and Jolt under the old any-element rule; `sticky_thread` is not named).

- [ ] **Step 3: Implement**

In `scripts/skills/skill_def.gd`, add after `essences_used()`:

```gdscript
## Creature ids named by `predated` counters in the unlock ("eat a spider"), for the Compendium hint and the unlock wording.
func sources_used() -> Array:
	var out: Array = []
	for c in unlock:
		if c.get("event", "") == Events.PREDATED and c.get("tags", {}).has("source"):
			_add(out, c["tags"]["source"])
	return out
```

In `scripts/compendium/compendium_model.gd`, in `creature_report` replace

```gdscript
				for ess in d.essences_used():
					if c.essences.has(ess):
						raise(id, State.NAMED)
```

with

```gdscript
				if _hints(d, c):
					raise(id, State.NAMED)
```

and add, below `creature_report`:

```gdscript
## A creature hints a power when it carries EVERY element of the power's recipe, or is the creature the unlock says to eat. (With
## shared elements, "any one element" would name almost every power from almost every creature.)
static func _hints(d: SkillDef, c: CreatureDef) -> bool:
	if d.sources_used().has(c.id):
		return true
	var needed := d.essences_used()
	if needed.is_empty():
		return false
	for ess in needed:
		if not c.essences.has(ess):
			return false
	return true
```

In `scripts/ui/skill_screen_model.gd`, in `_event_text` add a `predated` arm between `absorbed` and `damaged`:

```gdscript
		"predated":
			if tags.has("source"):
				return "Eat a %s" % str(tags["source"]).capitalize()
```

(When the arm has no `source` tag it falls out of the `match` to the existing `return EVENT_TEXT.get(event, event)`.)

- [ ] **Step 4: Run the tests**

Run: `tools/run_tests.sh test_creature_hints`, `tools/run_tests.sh test_skill_screen`, `tools/run_tests.sh test_def_validator`, `tools/run_tests.sh test_compendium`
Expected: `PASS: <n> tests` for each. (`test_compendium_model` builds fake defs with one element each, so the every-element rule gives the same answer there.)

- [ ] **Step 5: Commit**

```bash
git add scripts/skills/skill_def.gd scripts/compendium/compendium_model.gd scripts/ui/skill_screen_model.gd tests/test_creature_hints.gd tests/test_skill_screen.gd tests/test_def_validator.gd
git commit -m "feat: a creature hints a power only when it carries the whole recipe or is the creature to eat"
```

---

### Task 4: The calibration walk, its tool, its pins and its ledger

A tool and a test share one walk of the shipped map so the unlock points the plan reports are the ones the suite enforces.

**Files:**
- Create: `tests/support/calibration_walk.gd` (and its `.uid`)
- Create: `tools/calibrate_essences.gd`
- Create: `docs/ledgers/essence-calibration.md`
- Test: `tests/test_content.gd`

**Interfaces:**
- Consumes: `SkillRulesEngine` (`setup`, `start_run`, `handle_event`, `level_of`), `SkillDef.source` and `levels_on`, `RoomDef.area` and `spawns`, `CreatureDef.essences`, `CreatureDef.untackleable`.
- Produces: `CalibrationWalk.AREAS`; `CalibrationWalk.order(rooms: Dictionary, start_area: String) -> Array`; `CalibrationWalk.unlock_points(skills: Array, creatures: Dictionary, rooms: Dictionary, start_area: String) -> Dictionary` (essence-skill id → the eat, counting from 1, at which it unlocked; absent if never); `CalibrationWalk.levels_by_area(skills, creatures, rooms) -> Dictionary` (area → {skill id → level}, for skills that `levels_on` an absorbed element, on the Cave-start walk).

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_content.gd` (below the minimums test):

```gdscript
func _creature_map() -> Dictionary:
	var out := {}
	for c in creatures:
		out[c.id] = c
	return out

## The Cave-start unlock points before the element vocabulary: the eat, counting from 1, over every spawn of the shipped rooms
## (area order cave, grotto, flooded, deep; room-id order within an area; the jelly, which a tackle cannot down, is skipped).
## The calibration holds each within one eat. Spore Cloud was 28 (the fourth Grotto moth); the Cave's bats and toads now meet air 8
## and dark 4 first, a deliberate move the design accepted, pinned below.
const CAVE_START_BEFORE := {"body_armor": 13, "echolocation": 3, "hardened_shell": 27, "hydraulic_propulsion": 7, "jolt": 57,
	"poison_breath": 7, "regeneration": 11, "sticky_thread": 14, "tremor": 73}
const SPORE_CLOUD_NOW := 16

func test_every_power_unlocks_within_one_eat_of_where_it_did_on_a_cave_start() -> void:
	var points := CalibrationWalk.unlock_points(skills, _creature_map(), ShippedRooms.load_all(), "")
	for id in CAVE_START_BEFORE:
		assert_almost_eq(float(points.get(id, 0)), float(CAVE_START_BEFORE[id]), 1.0, id)
	assert_eq(points["spore_cloud"], SPORE_CLOUD_NOW, "the one deliberate move: Spore Cloud is reachable in the Cave")

func test_every_power_is_reachable_from_every_start_by_some_walk() -> void:
	for start in ["", "grotto", "flooded", "deep"]:
		var points := CalibrationWalk.unlock_points(skills, _creature_map(), ShippedRooms.load_all(), start)
		for d in skills:
			if d.source == "essence":
				assert_gt(int(points.get(d.id, 0)), 0, "%s from the %s start" % [d.id, start if start != "" else "cave"])

func test_echolocation_levels_from_air_so_the_grottos_moths_speed_it_up() -> void:
	var levels := CalibrationWalk.levels_by_area(skills, _creature_map(), ShippedRooms.load_all())
	var by_area: Array = []
	for a in CalibrationWalk.AREAS:
		by_area.append(levels[a]["echolocation"])
	assert_eq(by_area, [1, 4, 5, 5], "was 2, 2, 2, 5 on sound; a deliberate move recorded in docs/ledgers/essence-calibration.md")
```

- [ ] **Step 2: Run to verify they fail**

Run: `tools/run_tests.sh test_content`
Expected: `FAIL: engine error or empty run` (`CalibrationWalk` does not exist).

- [ ] **Step 3: Write the walk helper and the tool**

Create `tests/support/calibration_walk.gd`:

```gdscript
class_name CalibrationWalk
extends RefCounted
## Walks the shipped rooms and eats every spawn once, through a real SkillRulesEngine, so a tool and a test report the same
## unlock points. A creature a tackle cannot down (the jelly) is skipped.

const AREAS := ["cave", "grotto", "flooded", "deep"]

## Room ids in the order a walk meets them: the start area first (room-id order), then the later areas, then the earlier ones
## nearest first (a life may walk back). An empty start area is the Cave start: cave, grotto, flooded, deep.
static func order(rooms: Dictionary, start_area: String) -> Array:
	var areas: Array = AREAS.duplicate()
	if start_area != "":
		var i := AREAS.find(start_area)
		areas = AREAS.slice(i)
		var back: Array = AREAS.slice(0, i)
		back.reverse()
		areas.append_array(back)
	var out: Array = []
	for a in areas:
		var ids: Array = []
		for id in rooms:
			if (rooms[id] as RoomDef).area == a:
				ids.append(id)
		ids.sort()
		out.append_array(ids)
	return out

static func eat(rules: SkillRulesEngine, c: CreatureDef) -> void:
	rules.handle_event("predated", {"source": c.id, "kind": "creature" if c.id != "water_pool" else "terrain"})
	for e in c.essences:
		for i in int(c.essences[e]):
			rules.handle_event("absorbed", {"essence": e, "source": c.id})

## essence-skill id -> the eat (counting from 1) at which it unlocked on this walk; absent when it never did.
static func unlock_points(skills: Array, creatures: Dictionary, rooms: Dictionary, start_area: String) -> Dictionary:
	var rules := SkillRulesEngine.new()
	rules.setup(skills)
	rules.start_run()
	var watched: Array = skills.filter(func(d: SkillDef) -> bool: return d.source == "essence")
	var out := {}
	var eats := 0
	for id in order(rooms, start_area):
		for s in (rooms[id] as RoomDef).spawns:
			var c: CreatureDef = creatures[s["id"]]
			if c.untackleable:
				continue
			eats += 1
			eat(rules, c)
			for d in watched:
				if not out.has(d.id) and rules.level_of(d.id) > 0:
					out[d.id] = eats
	rules.free()
	return out

## area -> {skill id -> level} at the end of each area on the Cave-start walk, for skills that level on an absorbed element.
static func levels_by_area(skills: Array, creatures: Dictionary, rooms: Dictionary) -> Dictionary:
	var rules := SkillRulesEngine.new()
	rules.setup(skills)
	rules.start_run()
	var levelled: Array = skills.filter(func(d: SkillDef) -> bool: return d.source == "essence" and d.levels_on.get("event", "") == "absorbed")
	var out := {}
	for a in AREAS:
		var ids: Array = []
		for id in rooms:
			if (rooms[id] as RoomDef).area == a:
				ids.append(id)
		ids.sort()
		for id in ids:
			for s in (rooms[id] as RoomDef).spawns:
				var c: CreatureDef = creatures[s["id"]]
				if not c.untackleable:
					eat(rules, c)
		var row := {}
		for d in levelled:
			row[d.id] = rules.level_of(d.id)
		out[a] = row
	rules.free()
	return out
```

Create `tools/calibrate_essences.gd`:

```gdscript
extends SceneTree
## Prints, per skill that unlocks from eating, the eat at which it unlocks on four walks of the shipped map, and the level each
## absorbed-levelled skill has reached by the end of each area (Cave-start walk). Read-only.
##   env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/calibrate_essences.gd
## An optional `-- --data=res://some/dir` reads skills and creatures from `<dir>/skills` and `<dir>/creatures` instead.

## The twenty-three rooms the game shipped with: a room the editor adds later is not part of the calibration.
const SHIPPED := ["C1", "C2", "C3", "C4", "C5", "C6", "G1", "G2", "G3", "G4", "G5", "F1", "F2", "F3", "F4", "F5", "F6", "D1", "D2", "D3", "D4", "D5", "D6"]
const WALKS := {"cave": "", "G1": "grotto", "F1": "flooded", "D1": "deep"}

func _init() -> void:
	var root := "res://data"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--data="):
			root = a.trim_prefix("--data=")
	var skills: Array = DefLoader.load_dir(root.path_join("skills"))
	var creatures := {}
	for c in DefLoader.load_dir(root.path_join("creatures")):
		creatures[c.id] = c
	var rooms := {}
	for r in DefLoader.load_dir("res://data/rooms", "RoomDef"):
		if SHIPPED.has(r.id):
			rooms[r.id] = r
	var table := {}
	for walk in WALKS:
		table[walk] = CalibrationWalk.unlock_points(skills, creatures, rooms, WALKS[walk])
	print("skill | cave | G1 | F1 | D1   (the eat, counting from 1, at which the skill unlocks; 0 = never)")
	for d in skills.filter(func(s: SkillDef) -> bool: return s.source == "essence"):
		var row := [d.id]
		for walk in WALKS:
			row.append(int(table[walk].get(d.id, 0)))
		print(" | ".join(PackedStringArray(row.map(func(x): return str(x)))))
	print("level reached at the end of each area, Cave-start walk (the stage-1 cap is %d)" % SkillRulesEngine.BASE_STAGE_CAP)
	var levels := CalibrationWalk.levels_by_area(skills, creatures, rooms)
	for a in CalibrationWalk.AREAS:
		var parts := [a]
		for id in levels[a]:
			parts.append("%s %d" % [id, levels[a][id]])
		print(" | ".join(PackedStringArray(parts)))
	quit()
```

Register the new class and generate its `.uid`:

```bash
env HOME="$PWD/.tmp/gdhome" godot --headless --import
ls tests/support/calibration_walk.gd.uid
```

- [ ] **Step 4: Run the tests, then the tool**

Run: `tools/run_tests.sh test_content`
Expected: `PASS: <n> tests`.

Run: `env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/calibrate_essences.gd`
Expected output (exactly these numbers; they are what Step 1 pins):

```
skill | cave | G1 | F1 | D1   (the eat, counting from 1, at which the skill unlocks; 0 = never)
body_armor | 13 | 5 | 12 | 3
echolocation | 3 | 3 | 8 | 16
hardened_shell | 27 | 12 | 22 | 9
hydraulic_propulsion | 7 | 31 | 8 | 28
jolt | 57 | 35 | 6 | 28
poison_breath | 7 | 16 | 44 | 44
regeneration | 11 | 10 | 10 | 10
spore_cloud | 16 | 6 | 44 | 44
sticky_thread | 14 | 85 | 85 | 85
tremor | 73 | 57 | 52 | 52
level reached at the end of each area, Cave-start walk (the stage-1 cap is 5)
cave | echolocation 1
grotto | echolocation 4
flooded | echolocation 5
deep | echolocation 5
```

If a number differs, change the matching threshold in `tools/build_content.gd`, regenerate, and rerun until the Cave column is within one eat of the `CAVE_START_BEFORE` table; then update the ledger below and any pin that moved.

- [ ] **Step 5: Write the ledger**

Create `docs/ledgers/essence-calibration.md`:

```markdown
# Essence calibration (2026-10-03)

What the element vocabulary did to unlock timing. Produced by `tools/calibrate_essences.gd`; the Cave-start column is pinned in `tests/test_content.gd`. A number is "the eat, counting from 1, at which the skill unlocks" over every spawn of the shipped rooms (the jelly skipped), walking the Cave start in area order, and the three rebirth starts (G1, F1, D1) by their own area first, then forward, then back.

| Skill | Cave before | Cave after | G1 before | G1 after | F1 before | F1 after | D1 before | D1 after |
|---|---|---|---|---|---|---|---|---|
| Body Armor | 13 | 13 | 52 | 5 | 23 | 12 | 3 | 3 |
| Echolocation | 3 | 3 | 55 | 3 | 26 | 8 | 6 | 16 |
| Hardened Shell | 27 | 27 | 5 | 12 | 14 | 22 | 36 | 9 |
| Hydraulic Propulsion | 7 | 7 | 33 | 31 | 4 | 8 | 26 | 28 |
| Jolt | 57 | 57 | 35 | 35 | 6 | 6 | 28 | 28 |
| Poison Breath | 7 | 7 | 16 | 16 | 56 | 44 | 56 | 44 |
| Regeneration | 11 | 11 | 10 | 10 | 10 | 10 | 10 | 10 |
| Spore Cloud | 28 | **16** | 6 | 6 | 48 | 44 | 48 | 44 |
| Sticky Thread | 14 | 14 | 15 | **85** | 42 | **85** | 22 | **85** |
| Tremor | 73 | 73 | 55 | 57 | 36 | **52** | 19 | **52** |

Echolocation's level by the end of each area (Cave start, stage-1 cap 5): before 2, 2, 2, 5 on sound; after 1, 4, 5, 5 on air with `level_curve` 9, because the Grotto's moths now carry air.

## The deliberate moves

- **Spore Cloud** unlocks in the Cave (eat 16, was 28): air 8 from bats and dark 4 from toads and spiders. Accepted by Sean.
- **Sticky Thread** from G1, F1 and D1 needs a walk back to the Cave's Black Spiders (eat 85): the only creature its `source` condition counts. Reachable, later than before (a vine snake or the Taratect supplied thread).
- **Tremor** holds its Cave-start point (earth 59) and so unlocks later on F1 and D1 lives (52, was 36 and 19): an F1 or D1 life holds 50 earth in one forward pass and walks back for the rest.
- **Echolocation** and **Body Armor** unlock earlier on G1 and F1 lives (the Grotto's moths carry air; its crabs carry earth).
- **Echolocation** reaches the stage-1 cap by the end of the Flooded instead of staying at level 2.
```

- [ ] **Step 6: Full suite and commit**

Run: `TEST_TIMEOUT=900 tools/run_tests.sh`
Expected: `PASS: <n> tests` with no `SCRIPT ERROR`.

```bash
git add tests/support/calibration_walk.gd tests/support/calibration_walk.gd.uid tools/calibrate_essences.gd docs/ledgers/essence-calibration.md tests/test_content.gd
git commit -m "test: pin the Cave-start unlock points and rebirth-start reachability

CalibrationWalk eats every spawn of the shipped map through a real engine; the
tool prints the table and the ledger records the deliberate moves."
```

---

## Self-Review

**Spec coverage** (essence overhaul spec; the rows part 2 owns):

| Spec requirement | Task |
|---|---|
| `Essences.ALL` is the five first-pass elements | 2 |
| The derived creature table in `tools/build_content.gd` | 2 |
| Mix unlocks (Poison Breath water and dark, Spore Cloud air and dark, Jolt light and air) with no engine change | 2 |
| Sticky Thread unlocks on `predated {"source": "spider"}` ×3; no `family` field | 2 |
| `SkillDef.sources_used()`; hint needs every element or the source; unlock wording for `source` | 3 |
| Validator rejects an unknown source or element (already enforced; now tested) | 3 |
| Calibration: priority rule, Cave-start within one eat pinned, rebirth reachability, Echolocation levels, the ledger of moves | 4 |
| Minimums census retuned, with a `source` branch for Sticky Thread | 2 |
| Tools and tests that fed trait essences updated (`aim_shots`, `vfx_shots`, `evolution_shots`, the listed tests) | 2 |
| Closing grep for retired names | 2 |

Not in this part (part 3): price, `held`, `essence_spent`, EP removal, the HUD line, status text showing held.

**Placeholder scan:** none. Task 3's `test_def_validator` additions say to mirror the nearest existing test's call shape: the two functions are given in full and use only `TestDefs.skill`, `TestDefs.counter`, `TestDefs.all_creatures()` and `DefValidator.validate(skills, creatures)`, all of which exist.

**Type consistency:** `CalibrationWalk.unlock_points(skills, creatures: Dictionary, rooms: Dictionary, start_area: String) -> Dictionary` and `levels_by_area(skills, creatures, rooms) -> Dictionary` are defined in Task 4 and used only there (test and tool); `TestDefs.satisfy(rules, id)` is defined in Task 1 and used in Task 2; `SkillDef.sources_used()` is defined and used in Task 3.
