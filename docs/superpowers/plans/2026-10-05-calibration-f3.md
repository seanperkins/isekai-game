# Calibration of the full world (F3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use ml:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Say, with numbers pinned in tests, what the world with all its new areas and 169 placed creatures does to the essence thresholds (the slime's lineages, the powers' unlocks) and to the other species' gates, and change the data only where the numbers say it must.

**Architecture:** `CalibrationWalk` gains a diet: a copy of the rooms keeping only the creatures a class of eater would meet (the old hand-made ones, the commons, the elites, the rares, from `tools/creature_areas.json`). The pinned expectations of the hand-made world (`tests/test_lineage_gate_calibration.gd`, `tests/test_content.gd`) are the spec: the full world on a diet of the common creatures must reproduce them; richer diets may only reveal more, sooner. A feasibility test checks every gate atom that names a creature, a part, a bond, a species or an element against what the world holds.

**Tech Stack:** Godot 4.7 GDScript, GUT (`tools/run_tests.sh [filter]`).

**Spec:** `docs/research/species-form-branches.md` section 8 (opening thresholds, reveal and offer), `docs/research/areas-f2.md`.

## Global Constraints

- The method of the design doc stands: a read-only walk that eats the spawns of the four shipped areas (cave, grotto, flooded, deep) once, in the walk's order, through a real rules engine; XP counts a creature's `xp` once per eat. Thresholds change only when a pinned property of the hand-made world fails on the common diet.
- No change to a creature's stats, XP or essence, to `Progression`, or to a form's gate unless a feasibility finding says it cannot be met.
- No push. No attribution lines in commits. No time or effort estimates.

## Review Focus

- A threshold is not tuned to make a test pass: if a number moves, the ledger says which property of the design it restores.
- A diet is a filter of rooms, not of the engine: the walk, the rules and the forms are the real ones.
- A gate atom the feasibility test cannot check (it names no creature, part, bond, species or element) is listed, not silently skipped.

### Task 1: The diets and the common diet's pins

**Files:** Modify `tests/support/calibration_walk.gd`; Test `tests/test_world_calibration.gd`

**Interfaces:**
- Produces: `CalibrationWalk.diet(rooms: Dictionary, plan: Dictionary, classes: Array) -> Dictionary` (copies of `rooms` whose spawns keep only the creatures whose plan class is in `classes`; a creature the plan does not list is `"old"`, so `["old", "common"]` is the common diet).

- [ ] **Step 1: Tests** in `tests/test_world_calibration.gd` on the world's four shipped areas (the full checked-in rooms): the diet of `["old"]` reproduces the hand-made world exactly (the same unlock points as the hand-made pins); the common diet reveals after the first area what the hand-made world did on all four starts (Cave: tide, toxic, echo, offered toxic; Grotto: toxic, bulwark, echo, offered none; Flooded: tide, echo; Deep: bulwark, echo, offered none), offers at the first evolution all five on a Cave start and the four without Weaver on the others, and unlocks every power within 10 eats of the hand-made Cave-start pins (the Cave-start unlock of each power, `CAVE_START_BEFORE` in `tests/test_content.gd`, with Jolt and Tremor given their own measured numbers); each richer diet (no rares, all) reveals a superset of the common diet's lineages at the end of every area, on every start.
- [ ] **Step 2: Run** `tools/run_tests.sh test_world_calibration`. Expected: FAIL (no `diet`).
- [ ] **Step 3: Implement** `diet`; change a threshold in `data/forms/*.tres` or `tools/build_content.gd` only if a pin fails, and record why in the ledger.
- [ ] **Step 4: Run** it with `test_lineage_gate_calibration` and `test_content`. Expected: PASS.
- [ ] **Step 5: Commit** `test: the common diet of the full world keeps the lineage and power calibration`.

### Task 2: Every gate can be met in the world

**Files:** Test `tests/test_gate_feasibility.gd`

- [ ] **Step 1: Tests:** for every form's gate atoms (an `any` group by its alternatives: at least one alternative is feasible): a `held` atom's element has at least `n` units in the whole world's spawns; a `lesson_learned`, `defeated`, `predated` or `bond_formed` atom that names a `creature`, `source` or `species` is met by a creature of the world (the species of the data's `species` field), a `part_harvested` or `graft_attached` atom's `part` is dropped by a creature of the world, a `bond_formed` atom's `kind` is a bond some creature of the world accepts, a `lesson_learned` atom's `element` is carried by at least `n` kinds of creature of the world; the atoms none of these can check are listed and counted (a pinned number).
- [ ] **Step 2: Run** it. Expected: FAIL or PASS; a failing atom is a finding: place the creature it needs or change the gate in `tools/form_gates.json` (and rebuild the forms), with a ledger line.
- [ ] **Step 3: Commit** `test: every gate that names a thing can be met by the world`.

### Task 3: The tool, the docs

**Files:** Modify `tools/calibrate_essences.gd`, `docs/research/species-form-branches.md`, `docs/research/areas-f2.md`, `docs/superpowers/plans/2026-10-05-species-evolutions-roadmap.md`

- [ ] **Step 1: Make** `tools/calibrate_essences.gd` read the whole world and print each diet's table (`--diet=old|common|elite|all` and the default of all of them).
- [ ] **Step 2: Write** the results into the design doc's section 8: the diet model, the full-world tables, what changed (nothing, or what), and what the richer diets do.
- [ ] **Step 3: Run** `TEST_TIMEOUT=1700 tools/run_tests.sh`. Expected: PASS.
- [ ] **Step 4: Commit** `docs: the calibration of the full world`.
