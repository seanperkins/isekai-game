# Reincarnation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, inline; Sean's standing choice) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dying no longer always sends you back to the Cave's first room. Rebirth pools found in the world unlock as places to be reborn, each with a small head start, and the choice is decided by pure logic that the Grotto's menu UI will render.

**Architecture:** A `rebirth_pool` room feature attunes a pool (saved in the Profile through `WorldProgress`). A pure `RebirthChoice` turns the unlocked pools and the last choice into either a direct start or a list to pick from. The choice lives in `Compendium.progress` (`pending_start`, in memory) and the Profile (last choice, species), because the scene is rebuilt on every death. The game enters the chosen room, calls `SkillRules.start_run()`, then applies the pool's kit (granted skills, a starting level, seeded affinity). The menu UI ships with the second pool (Plan 7).

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`).

**Spec:** `docs/superpowers/specs/2026-09-28-slime-forms-and-animation-design.md`, section 5 (5.1 pools, 5.2 the choice, 5.3 the head start, 5.4 species, 5.5 code). The menu UI part of 5.2 (item 3) belongs to Plan 7.

## Global Constraints

- The Cave's C1 has a rebirth pool that is already unlocked, so the game always has a default spawn; its kit is nothing.
- Pool ids are validated against the room data when the world loads; an unknown id, or a last choice whose pool no longer exists, falls back to C1.
- A kit is data on the pool: `{"skills": [ids], "level": int, "affinity": {essence: units}}`. Level is the character level, at most `Progression.LEVEL_CAP`; skills start at skill level 1; a starting level gives its stat bonuses but no EP; the stage is always 1.
- Kit skills are granted without `skill_unlocked` (that signal reveals the Compendium and is the only path into a slot), so the game refreshes the skill set, adds actives to slots and raises the Compendium to `NAMED`. Their counters start from zero. When their unlock conditions are met the engine emits `skill_discovered(id)` (raising the Compendium to `OWNED_ONCE`) and the ticker says "You understand [Skill]."
- Every pool except the default leaves at least two lineages eligible for the first evolution (seeded affinity counts).
- Granted skills' dependants stay locked until earned (a granted Wall Cling does not unlock Swing Thread).
- The `Run` node is rebuilt on reload: nothing about the choice may live on it.
- `species` (`"slime"`) is carried on the pending start and saved in the Profile; no `SpeciesDef`, no species row.
- Glow Pools stay rest-only. Commit messages carry no attribution lines.

## Review Focus

1. A profile that lists an unknown pool id, holds a malformed `rebirths` section, or a last choice for a pool that was removed: the game starts at C1, never crashes.
2. Dying in the middle of the menu or twice in a row: the run starts once, and the pending start is cleared so an unrelated reload does not replay a kit.
3. A kit applied after `start_run()`: EP stays 0, stage 1, level bonuses match the level, skill counters start from zero, slots and Compendium states are right, and `start_run()` running again (a second death) clears it all before the next kit.
4. Granting a skill whose dependants have their own unlock rules: no early unlock, no double announcement, no double slot.
5. A pool in a room the player has not visited or attuned to: unattuned pools never appear as choices except as "???".

---

### Task 1: Persistence: attuned pools, the last choice, species

**Files:** Modify `scripts/world/world_progress.gd`. Test `tests/test_rebirth_progress.gd`.

**Interfaces — Produces:** `WorldProgress.rebirths: Array` (attuned pool ids, from Profile section `rebirths`), `attune(id: String)`, `is_attuned(id: String) -> bool` (`DEFAULT_POOL` "C1" is always attuned), `const DEFAULT_POOL := "C1"`, `last_choice() -> Dictionary` (`{"pool": String, "species": String}`, default `{DEFAULT_POOL, "slime"}`), `set_last_choice(pool: String, species := "slime")`, `pending_start: Dictionary` (in memory, `{}` when none), `sanitize(pool_ids: Array) -> void` (drops attuned ids and a last choice not in `pool_ids`, falling back to the default), `take_pending() -> Dictionary` (returns and clears).

Tests: attune persists through a saved Profile and reload; attuning twice stores once; C1 is attuned with an empty profile; unknown ids are dropped by `sanitize`; a last choice for a vanished pool falls back to C1; a malformed section (a number, a dict) is dropped without a crash; `take_pending` returns once and clears; the profile save has one writer (the sections `map`, `shortcuts`, `tablets`, `rebirths` and the last choice survive a round trip together).

### Task 2: The `rebirth_pool` feature and its validation

**Files:** Create `scripts/world/rebirth_pool.gd`; modify `scripts/world/room_features.gd`, `scripts/world/world_validator.gd`, `tools/build_world.gd` (C1 gets its pool), regenerate `data/rooms/C1.tres`, `scripts/ui/skill_screen_model.gd` (map flag), `scripts/ui/skill_screen.gd` (map icon), `data/audio/cues.json` (cue for attuning). Tests `tests/test_rebirth_pool.gd`.

**Interfaces — Produces:** `RebirthPool` (Node2D, group `interactable`): `id`, `area`, `kit`, `prompt() -> "attune"` (or "attuned" once done), `interact(player)` (attunes via the progress in ctx, emits `pool_attuned`, announces "Your body will remember this place."), a pale violet-white glow with a ring of motes (distinct from the Glow Pool's teal). `WorldValidator` errors: duplicate pool ids, a pool with no `id`/`area`/`kit`, a kit naming an unknown or enemy-only skill, a kit level above the cap or below 1, an unknown affinity essence, no pool in the start room's area entrance (C1 must hold the default).

Tests: the feature builds from data; interacting attunes and persists; a second interaction announces nothing new; the prompt changes after attuning; the validator names each mistake; the shipped rooms validate; C1's pool exists with an empty kit; the map view flags rooms that hold a rebirth pool and shows attuned ones differently; every emitted world event has an audio cue.

### Task 3: `RebirthChoice` (pure logic)

**Files:** Create `scripts/world/rebirth_choice.gd`. Test `tests/test_rebirth_choice.gd`.

**Interfaces — Produces:** `RebirthChoice.pools(rooms: Dictionary) -> Array` (`[{"id", "area", "room", "pos", "kit", "name"}]` in a stable order, C1's first), `decide(pools: Array, attuned: Array, last: String) -> Dictionary` returning `{"direct": pool_id}` when exactly one pool is attuned, else `{"options": [{"id", "name", "locked": bool}], "selected": int}` (attuned first in stable order, then locked as `"???"` entries with `locked: true`, the last choice pre-selected, falling back to the first attuned), `accept(decision: Dictionary, index: int) -> String` (the pool id for an unlocked index; `""` for a locked or out-of-range one).

Tests: one attuned pool starts directly; two or more return the list; locked pools appear as "???" after the unlocked ones; the last choice is pre-selected and a vanished last choice falls back to the first attuned; a locked entry cannot be accepted; out-of-range indexes return nothing; the order is stable.

### Task 4: The kit: granting, discovery, starting level, seeded affinity

**Files:** Modify `scripts/skills/skill_rules_engine.gd` (`grant(id, announce := true)`, `_granted`, `skill_discovered`, the `_evaluate` branch), `scripts/actors/progression.gd` (`start_at`, `seeded`), `scripts/forms/form_offers.gd` (`absorbed_units(rules, seeded)`), `scripts/player/player.gd` (`apply_kit`, `form_offers` passes the seeded units), `scripts/core/core_wiring.gd` (discovery line, NAMED raise), create `scripts/world/rebirth_kit.gd`. Tests `tests/test_rebirth_kit.gd`.

**Interfaces — Produces:** `SkillRulesEngine.grant(id, announce := true) -> bool`; `skill_discovered(id: String)` signal; `is_granted(id) -> bool`. `Progression.start_at(level: int)` (fires `leveled_up` per level so bonuses apply, grants no EP, clamps to the cap), `Progression.seeded: Dictionary` (essence -> units, counts toward affinity only). `RebirthKit.apply(player: Player, rules, compendium, kit: Dictionary)`: grants each skill unannounced, refreshes the skill set, adds actives to slots, raises the Compendium to `NAMED`, starts at the level, seeds the affinity units. `RebirthKit.validate(kit, skill_defs) -> PackedStringArray`.

Tests: a granted skill is owned at level 1 with no `skill_unlocked`; actives land in slots once; the Compendium reads `NAMED`, not `OWNED_ONCE`; its counters start from zero; earning its unlock later emits `skill_discovered` (once) and the Compendium reads `OWNED_ONCE` and the ticker says "You understand ..."; a skill with a dependant (Wall Cling then Swing Thread) leaves the dependant locked; `start_at(3)` gives the level 3 bonuses, no EP, stage 1, and never exceeds the cap; seeded units count toward `FormOffers.affinity` and never toward skill unlocks; applying a kit after `start_run()` twice does not stack; for each shipped pool except the default, at least two lineages are eligible from its seeded affinity.

### Task 5: The run flow: choice, pending start, entering at a pool

**Files:** Modify `scripts/world/world.gd` (`enter_at`), `scripts/game.gd` (read the pending start, enter, apply the kit after `start_run()`), `scripts/run.gd` (decide on death, set `pending_start`, save the last choice). Tests `tests/test_rebirth_flow.gd`.

**Interfaces — Produces:** `World.enter_at(room_id: String, pos: Vector2)`. `Run` gains `signal choice_needed(decision: Dictionary)` and `func choose(pool_id: String)`; with one attuned pool it sets the pending start and emits `restart_requested` directly; with more it emits `choice_needed` and waits (a second `died` does nothing). `Game._ready` uses `Compendium.progress.take_pending()`.

Tests: death with only the default pool restarts at the start room with no kit; with a second attuned pool `choice_needed` fires with the options and `choose()` restarts there with its kit applied after `start_run()`; a second death during the choice does nothing; the pending start is cleared after use (an unrelated reload starts at C1); a saved last choice pre-selects; a vanished pool falls back to C1; the kit never survives a second death into a different pool; species is carried (`"slime"`).

### Task 6: Review, the gate and the merge

- [ ] Real-game check with a temporary second pool: die, choose, arrive with the kit. Playtest-checklist lines. Final whole-branch review (opus subagent), one fix pass with a failing test first, merge after `feat/evolution`, push, clean the worktree.
