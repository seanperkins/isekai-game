# Evolution Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (native, inline; Sean's standing choice) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A run has an arc: four stages, ten levels each, then a choice of body (a branching tree of 24 forms), with skill levels held back until you evolve. The Weaver lineage is drawn end to end; every other form uses a tinted, scaled slime.

**Architecture:** `Progression` gains a stage and a level cap. Static `FormDef` resources (data-only, hand-written) describe the tree; a small `Form` state on the player tracks stage and form and is the only thing that changes them. Offers come from a pure function over what the run absorbed and the supply in the room data. The skill engine reads the stage cap when levelling and re-checks every owned skill on evolving. A fifth Form tab in the skill screen lists the offers; choosing one plays an evolution animation and swaps the slime's sprite set (the lineage's own sheet, or the base sheet tinted).

**Tech Stack:** Godot 4.7 GDScript, GUT 9.7.1 (`tools/run_tests.sh [substr]`), Python 3.12 + Pillow for `tools/art`, Codex `$imagegen` (one image per frame).

**Spec:** `docs/superpowers/specs/2026-09-28-slime-forms-and-animation-design.md`, section 3 (3.1 XP and stages, 3.2 tree, 3.3 offers, 3.4 skill caps, 3.5 code). Section 5.5's `start_at` and `grant` belong to Reincarnation (Plan 5); this plan only leaves room for them.

## Global Constraints

- Four stages. Level cap 10 per stage; XP is discarded at the cap ("Your body can evolve."); evolving resets level to 1.
- Stage XP curve: `floor((10 + 5 * (level - 1)) * m)` with `m` = 1, 1.5, 2, 2.5 for stages 1 to 4 (270, 403, 540, 673 XP per stage).
- First-time rewards: each spawn point pays full XP once for the first down and once for the first eat (`"<room id>:<index>"`, keys `key:down`, `key:eat`, held on `Progression`, marked only when XP is actually awarded); any repeat pays `floor(xp / 4)`.
- Level bonuses (+2 max HP, +1 max MP per level) and EP persist across the level reset.
- Skill stage caps: 5, 8, 12, 15. A skill above the cap stops levelling but its counters keep counting; evolving re-checks every owned skill one at a time and levels it straight to its new cap. During the re-check individual level-up lines are suppressed and "Your skills grew" is shown once.
- Tree: 5 lineages (Weaver, Tide, Toxic, Bulwark, Echo) + neutral Greater Slime at stage 2; stage 2 to 3 always offers the form's two children; stage 3 to 4 has exactly one child (the lineage's Sovereign, or Prime Sovereign); every branch reaches stage 4. 24 forms in all.
- Stage 1 to 2 offers: affinity = units of the lineage's essences absorbed this run divided by that lineage's supply across all spawns in the shipped areas (from room data). Eligible at 0.6 or more; the three highest offered, ties by lineage order (Weaver, Tide, Toxic, Bulwark, Echo); Greater Slime is added until there are at least two offers.
- Only skills with a `levels_on` rule get a higher `max_level` (up to 15, per skill, each reachable in a run but not trivially). Enemy-only skills stay at 1; the three skill evolutions stay at 1.
- Naming keeps the two systems apart: skills say "Evolution available ... EP", `evolve()`, `try_evolve()`; the body says "Your body can evolve" and uses `Form.advance()`.
- Forms never change the slime's collision box (world geometry cannot change): `size` scales the sprite only. Every room exit still fits.
- The Form tab appears only once `stage > 1` or a body evolution is available; five tabs use width 100 at pitch 106; four keep today's layout.
- Commit messages carry no attribution lines.

## Review Focus

1. Evolving at the exact moment XP arrives, or with a skill event queued: no XP double-counted, no dropped level-up (the engine's 64-item queue).
2. Restarting a run resets stage, form, level, claimed spawns and skill caps, and restores the base sheet.
3. A form whose art is missing (or partly missing) still renders (tinted base sheet); a form id that does not exist never crashes.
4. Evolving while airborne, spread, roped, eating or stunned: the sheet swap never leaves the slime invisible or stuck in a stale state, and the collision box is unchanged.
5. Stat and trait changes are applied once per advance (no stacking), and removed on a new run.

---

### Task 1: Progression: stages, cap, first-time XP

**Files:** Modify `scripts/actors/progression.gd`, `scripts/enemies/enemy.gd` (`spawn_key`), `scripts/game.gd` (pass the key), `scripts/player/player.gd` (`award_xp`, `on_enemy_downed`, eat award), `scripts/ui/hud.gd`, `scripts/ui/skill_screen.gd` (callers of `xp_to_next`). Test: `tests/test_progression_stages.gd`; update `tests/test_levels.gd`.

**Interfaces — Produces:** `Progression.stage := 1`, `const LEVEL_CAP := 10`, `const STAGE_MULT := [1.0, 1.5, 2.0, 2.5]`, `static xp_to_next(from_level: int, stage: int = 1) -> int`, `static stage_total(stage: int) -> int`, `at_cap() -> bool`, `can_evolve() -> bool` (level at cap, stage below 4), `evolve_stage() -> void` (stage+1, level=1, xp=0; bonuses and EP kept), `claimed: Dictionary`, `award(key: String, kind: String, xp: int) -> int` (returns XP granted: full the first time, `floor(xp/4)` after; only marks claimed when XP is actually added), signal `can_evolve_changed`-free: the HUD reads `can_evolve()`. `Enemy.spawn_key: String`.

Tests (write first): the four stage curves and totals (270, 403, 540, 673, sum 1886) and per-level flooring; `add_xp` at the cap discards the excess and does not level; `at_cap`/`can_evolve` at level 10 (and not at stage 4); `evolve_stage` resets level and xp but keeps `ep`, and the player's max HP/MP bonuses (`Player._on_leveled_up` bonuses persist because stats are not reset on `evolve_stage`); `award` pays full once per `key:down` and once per `key:eat`, then `floor(xp/4)` (bat 2 and toad 3 pay 0, lizard 5 pays 1); a spawn killed at the cap keeps its first-time reward for after evolving; a full first pass of the Cave (data-driven from the room files and creature xp) pays under 270 XP; keys look like `"C1:3"`.

### Task 2: `FormDef`, the tree, `Form` state

**Files:** Create `scripts/forms/form_def.gd`, `scripts/forms/form.gd`, `scripts/forms/form_loader.gd`, `data/forms/*.tres` (24, generated once by `tools/build_forms.gd` from one table then committed; hand-editable afterwards), `tests/test_forms.gd`.

**Interfaces — Produces:**
- `FormDef` (Resource): `id`, `display_name`, `stage: int`, `lineage: String`, `parents: Array` (form ids), `essences: Array` (for stage-2 forms), `stats: Dictionary` (stat id -> add), `traits: Array` (ids), `grants: Array` (skill ids), `tint: Color`, `size: float` (sprite scale, 1.0 to 1.5), `sprite_set: String` (`""` = tinted base), `blurb: String`.
- `FormLoader.load_all(dir := "res://data/forms") -> Dictionary` (id -> FormDef), `children_of(forms, id) -> Array`, `stage2_forms(forms) -> Array`.
- `Form` (RefCounted): `stage := 1`, `form_id := "slime"`, `advance(id: String, forms: Dictionary) -> bool` (only legal transition: `id` is a child of the current form, or a stage-2 form from `slime`), `cap() -> int` (`STAGE_CAPS[stage - 1]`), `const STAGE_CAPS := [5, 8, 12, 15]`, `reset()`.
- A validator `FormValidator.validate(forms) -> PackedStringArray`.

The 24 forms (stage 1 is the base `slime`, not a `FormDef` file): stage 2: `weaver`, `tide`, `toxic`, `bulwark`, `echo`, `greater_slime`; stage 3: `snare`, `arachne` (weaver), `brook`, `tempest` (tide), `acid`, `blight` (toxic), `golem`, `crystal` (bulwark), `phantom`, `sky` (echo), `vast`, `radiant` (greater_slime); stage 4: `silkbound`, `tidal`, `venom`, `stone`, `storm`, `prime`.

Tests: every form id unique; every form's parents exist and are one stage below; each stage-3 form has exactly one child (its Sovereign) and both stage-3 forms of a lineage share it; every branch reaches stage 4 (walk the tree from `slime`); `advance` rejects skipping stages, wrong children and unknown ids; `cap()` per stage; stats only name known stats; grants only name known player skills; `tint`/`size` in range; sizes grow with stage.

### Task 3: Offers

**Files:** Create `scripts/forms/form_offers.gd`. Test `tests/test_form_offers.gd`.

**Interfaces — Produces:** `FormOffers.supply(rooms: Dictionary, creatures: Dictionary) -> Dictionary` (lineage -> units of its essences over every spawn in the given rooms), `affinity(absorbed: Dictionary, supply: Dictionary) -> Dictionary` (lineage -> ratio), `ELIGIBLE := 0.6`, `LINEAGE_ORDER := ["weaver","tide","toxic","bulwark","echo"]`, `LINEAGE_ESSENCES`, `offers(forms: Dictionary, form: Form, absorbed: Dictionary, supply: Dictionary) -> Array` (form ids: stage 1 from affinity; stage 2 its two children; stage 3 its one Sovereign; stage 4 empty), `absorbed_units(rules: SkillRulesEngine) -> Dictionary` (essence -> units this run, from the ledger).

Tests: a full first pass of the Cave eating everything gives every lineage 1.0 and offers Weaver, Tide, Toxic first by order; eating only bats offers Echo and Greater Slime; no eligible lineage offers only Greater Slime; one eligible offers it plus Greater Slime; two or more never adds Greater Slime; ties break by lineage order; supply is computed from room data (adding a spawn changes it); stage 2 offers exactly the two children, stage 3 exactly one, stage 4 none; the ratio (not raw units) is what makes Weaver reachable with 5 thread.

### Task 4: Skill caps and raised maxima

**Files:** Modify `scripts/skills/skill_rules_engine.gd` (`stage_cap`, cap-aware `_check_level`, `recheck_levels()`), `tools/build_content.gd` (each levelling skill's `max_level`, `level_curve` and extended `values`), regenerate `data/skills/*.tres`, `scripts/ui/announcer_queue.gd` (the single "Your skills grew" line). Tests `tests/test_skill_caps.gd`; update tests that pin old maxima (`tests/test_content.gd`, `tests/test_def_validator.gd` as needed).

**Interfaces — Produces:** `SkillRulesEngine.stage_cap := 5`, `set_stage_cap(n: int) -> void`, `recheck_levels() -> void` (each owned levelling skill in turn, its own drain; emits `skill_leveled` per level; sets a `rechecking` flag the announcer reads), `is_capped(id) -> bool` (owned, at the stage cap, with progress stored beyond it).

The per-skill table (each top level must be reachable in a run yet not trivial; counters keep counting past the cap): fill in from the build script's current curves: `leap` max 10 (curve 20), `wall_cling` 8 (curve 12), `poison_resistance` 12 (curve 6), `pain_resistance` 6 (curve 2), `toughness` 12 (curve 20), `appraisal` 5 (curve 2, needs 8 first inspections), `glutton` 8 (curve 5), `mana_recovery` 8 (curve 60), `echolocation` 8 (curve 3), `poison_breath` 15 (curve 8), `body_armor` 8 (curve 10), `sticky_thread` 15 (curve 8), `hydraulic_propulsion` 15 (curve 6), `regeneration` 6 (curve 8). Values arrays extended to the new maxima, monotonic.

Tests: a skill above the stage cap stays at the cap while its counter keeps counting; `level_progress` reports the stored progress; `set_stage_cap` then `recheck_levels` levels every owned skill straight to the new cap, one `skill_leveled` per level; the re-check with every levelling skill owned and far past caps drops no event (the 64-item queue never overflows); appraisal's max 5 is reachable by 8 first-time inspections and no more; every skill's top level is reachable within its source's supply (a table test) and its curve is not trivially small; `values.size() == max_level` for every skill (the validator agrees); enemy-only and evolution skills stay at 1.

### Task 5: Applying a form: stats, traits, grants, sprite set

**Files:** Modify `scripts/player/player.gd` (`form`, `forms`, `advance_form`, `_apply_form`, `_draw` sheet swap, reset on a new run), create `scripts/forms/form_effects.gd`. Test `tests/test_form_effects.gd`.

**Interfaces — Produces:** `Player.form := Form.new()`, `Player.advance_form(id: String) -> bool` (validates via `Form.advance`, pays nothing, calls `Progression.evolve_stage`, `SkillRules.set_stage_cap`, `recheck_levels`, applies stat changes and traits, grants the form's skills through `SkillRules.grant(id)`, swaps the sprite set), `FormEffects.apply(player, def)` / `remove(player, def)`, `Player.trait_active(id) -> bool`, `Player.body_sheet() -> SpriteSheet` (the form's own sheet, or the base sheet), `Player.body_tint() -> Color`, `Player.body_scale() -> float`. New `SkillRulesEngine.grant(id: String) -> bool` (adds an owned skill without an unlock, announced, idempotent).

Tests: advancing to `weaver` sets stage 2, resets level to 1, keeps EP and level bonuses, raises the skill cap to 8 and re-checks skills, applies the form's stat mods once (advancing again does not stack; a new run removes them), grants its skills, and never changes the collision box (`body_rect().size` unchanged, every room exit still fits); an illegal advance changes nothing; a form with no sheet renders the base sheet tinted and scaled (`body_tint`, `body_scale`); a form with its own sheet uses it; `_draw` after a swap keeps the sprite standing on the floor line.

### Task 6: Weaver lineage art

**Files:** `tools/art/form_<id>_frames.json` (4 sets, 21 frames each, generated from the slime list), generator support for cross-set references, assembled `assets/sheets/form_<id>.{png,json}`. Test `tests/test_form_sheets.gd`.

- [ ] Extend `generate_frames.py`: a reference containing `/` resolves under `art_source/frames/` (so a form frame can use the slime's same-named frame as its pose reference).
- [ ] Build the four frame lists from `slime_frames.json`: each frame's prompt is the form's description plus the slime pose text, refs `[<form>/idle_1, slime/<frame>]`, widths scaled by the form's size (1.12, 1.25, 1.25, 1.4), `attack_from` kept for the tackle. Generate all frames of a form in parallel after its `idle_1`.
- [ ] Contact sheets; regenerate weak frames alone; assemble; import; tests: each sheet has all 21 frames at the scaled width, on the floor line, shapes inside the frame, every clip frame exists.

### Task 7: The Form tab, HUD and skill screen

**Files:** Modify `scripts/ui/skill_screen.gd`, `scripts/ui/skill_screen_model.gd`, `scripts/ui/hud.gd`, `scripts/ui/announcer_queue.gd`. Tests `tests/test_form_tab.gd`, update `tests/test_skill_screen.gd` (`test_tabs_cycle_through_all_four`).

- [ ] HUD: `Lv %d/10 XP a/b  EP n`, and "Your body can evolve" (one line, once) when `can_evolve()`; at the cap the XP text says so.
- [ ] Skill screen: the level as a number plus a compact bar; "capped until you evolve" on a skill at the stage cap with progress stored; five tabs at width 100, pitch 106 (four tabs keep today's layout); the Form tab (only once `stage > 1` or `can_evolve()`) shows the current form, its traits and stats, and, when evolving is possible, the offered forms with their look and changes; choosing one calls `Player.advance_form`.
- [ ] Tests: tab cycle length with and without the Form tab; the Form tab is absent at stage 1 before the cap and present at the cap; the offer list matches `FormOffers.offers`; choosing an offer advances the form; the capped indicator; the level number and bar.

### Task 8: The evolution animation, run flow and pacing

**Files:** Create `scripts/forms/evolution_fx.gd`; modify `scripts/game.gd`, `scripts/player/player.gd` (debug XP), `tools/`. Tests `tests/test_evolution_flow.gd`.

- [ ] `EvolutionFx`: the slime glows, swells and splits into the new shape over about 1.2 s; the player is invulnerable and input-locked for its duration, and the sheet swap happens at the swell's peak. Ending always leaves the slime visible.
- [ ] A debug command grants XP (`Player.debug_grant_xp(n)`, used by tests and a `--evolve` launch shortcut) so evolution can be reached without a grind.
- [ ] Scripted run: level to the cap, evolve to Weaver, gain skills, reach stage 4 through the tree; a restart resets everything. Data-only pacing test: a first-time Cave pass stays under 270 XP (the Grotto half belongs to Plan 5).

### Task 9: Review, the gate and the merge

- [ ] In-game screenshots of each Weaver-lineage stage and a tinted fallback form, the Form tab, the HUD prompt; playtest-checklist lines; show Sean; regenerate or retune what he dislikes.
- [ ] Final whole-branch review (opus subagent), one fix pass with a failing test first, merge to main, push, clean the worktree.
