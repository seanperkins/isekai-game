# Skill Evolution Branches — Design

Status: revised after debate round 3 and its verification pass (2026-09-29). Answers Sean's two notes: "the evolved skill should replace the skill
that it evolved from" and "we could maybe choose two or three directions that an evolved skill could go towards", plus the
request to look at other Metroidvanias for abilities (`docs/research/metroidvania-reference.md`). Held/channelled casting
and new visual effects are a separate spec that follows this one (see "Not here").

## What I understood

Today an evolution is an extra skill that unlocks beside its parent (both stay castable), and only Swing Thread takes its
parent's slot (`replaces`). Sean wants the opposite default: evolving **turns** the skill into the new one. And the choice
should be a real choice between distinct directions, not one fixed upgrade.

Success: when a base skill reaches its evolution level the player is offered **all** of its directions at once, picks one
(EP is spent, with a confirming second press), and from then on has that skill where the old one was; the others are closed
for this life (a rebirth is the way to try another). Every base active skill that can evolve has two directions that play
differently, each built from behaviour the game already has or one small new piece.

## Decisions

| Topic | Decision |
|---|---|
| Replace | Evolving **retires** the parent. It stays in the engine's ledger (`_owned`, so its unlock and level cannot re-fire) but is hidden from `owned()`, its slot goes to the child (`ActiveSlots.replace`, already there), and it can never be cast, levelled or granted again this life. `owned()` means **held now**; `level_of(id)` means **level reached** (what `skill_level` prerequisites and `tests/test_scripted_run.gd:67-68` mean by it). Both meanings are written in the engine's doc comments |
| Branches | Siblings are the evolutions that share a `replaces`. No new branch field and **no stored branch state**: retired and closed are derived from `_owned` and `replaces`, so kits, forms, `reset_run()` and grant order cannot desynchronise anything. Taking one branch **closes** its siblings for the run |
| Offered together | All branches of one parent have the **same** `unlock`: exactly one `skill_level` condition, on the parent, at one shared level, enforced by the validator. So they become ready in the same drain and the player always chooses among every direction. Cross-skill pairings (Swing Thread needing Wall Cling, Jet Dash needing Leap) are removed for this reason: staggered unlocks would offer one branch first and silently close the ones not yet seen. Evolution cost is one EP for every branch |
| Only `evolve()` evolves | `grant()` of an evolution returns false, quiet or announced. `RebirthKit.apply` already slots an id only when `grant` returned true, so a kit naming an evolution is inert, and `RebirthKit.validate` (which `WorldValidator` calls) now rejects an evolution id so the silent no-op is caught at data time. Body forms must grant **base** skills only: `tools/build_forms.gd` stops granting `water_blade` and `jet_dash` from Tempest and Tidal Sovereign, and a data test in `tests/test_forms.gd` asserts that no form grants an evolution (`FormValidator` has no production caller, so its signature does not change; `grant()` is the runtime guard) |
| Levels | Evolutions are **single-level**, as the three that exist are today: `max_level` 1, no `levels_on`, one value. The validator enforces it. The three evolutions that exist keep the numbers they ship with; the new ones are set near the parent's mid-game (levels 5 to 8). The retired parent's growth track stops. Per-skill levelling for evolutions is a later, data-only change if play asks for it |
| Choosing | The Skills tab lists each ready evolution as today ("Name  EVOLVE 1 EP"). The detail card adds "Replaces X" and "Closes: Y". Because it is permanent for the life, `accept()` needs two presses: the first arms that row (the card says "Press again to choose"), the second evolves. The card's "Level up to earn EP" takes precedence over "Press again", so an EP-short row never shows a prompt that cannot succeed (`Player.try_evolve` already refuses when short, and the game is paused while the menu is open) |
| Owned card | An evolved skill's card says "Evolved from X". A retired parent is not a row, and neither a retired parent nor a closed evolution counts toward the "???" row |
| Compendium | An evolution is Named when it is first offered (already true); it stays Named after its branch closes. Appraisal's Lv4 line (`CompendiumModel.self_report`) skips closed evolutions. A parent granted by a kit and evolved before its own unlock is met never fires "You understand" (`skill_discovered`): accepted, since no shipped kit grants such a parent |
| Audio, icons, labels | Each new active needs an icon, a `skill_used` cue in `data/audio/cues.json` (it may point at a similar existing cue: Spore Cloud maps to `skill_poison_breath`), an `ACTIVE_LABEL` entry in `SkillScreenModel`, and its MP cost in the table in `tests/test_mana.gd`. Icons follow the `icon_spore_cloud` precedent: the five prompts are appended to `tools/art/skill_icons_grotto_frames.json` (the name is historical: `make_icons.py` reads only `art_source/frames/skill_icons_grotto`, `make_icons.py:14`), each icon is one PNG per frame written by `generate_frames.py skill_icons_grotto <frame>`, then `make_icons.py` runs; there is no manifest entry to add |
| Forms | `FormEffects.THREAD_SKILLS` gains `binding_web`, so a thread form still boosts the whole thread family. The Form card's "Grants:" line lists only grants the player can still receive (not a retired parent) and is **omitted when that list is empty** (the guard tests the filtered list, not `sel.grants`), and Tempest's blurb no longer says "it cuts" |

## The trees

Two directions per base skill (Sean: "two or three"). The research's templates: Ori's Charge Flame has three modifiers
(Burn, Blast, Efficiency), Hollow Knight replaces a spell with one upgrade. Each base skill gets one branch per *role*.
Numbers are starting values, tuned by play. Every branch unlocks at the parent's level shown, alone.

| Parent (evolves at) | Branch (MP) | Behaviour | Built from |
|---|---|---|---|
| **Sticky Thread** (level 3) | **Swing Thread** (4) | Exists: 200 px rope, swing, strong launch, holds enemies at once (its value is tier 2) | `thread_ability.gd` |
| | **Binding Web** (4) | Never ropes. The thread holds an enemy at once (tier 2, like Swing Thread) and leaves a web patch (radius 40 px, 4 s, damage 0, slowing) where the thread ends: at the enemy it hit, else at the rock it met, else at full range (120 px, the parent's). It webs a corridor or a floor, not a swing anchor | `ThreadAbility` gains `ropes := true` and a `_land(end)` hook called with that end point (the base `_land` does nothing, so Sticky and Swing Thread are unchanged); Binding Web sets `ropes = false` and drops the zone in `_land` |
| **Hydraulic Propulsion** (level 3) | **Water Blade** (5) | Exists: instant blade, 160 px, 3 damage | `water_blade.gd` |
| | **Jet Dash** (5) | Exists: long dash, 700 px/s | `jet_dash.gd` |
| **Poison Breath** (level 4) | **Miasma** (5) | The cone as today (56 px, `targets_in_front(56, 24)`) at 9 damage (the parent's level-8 value), and where it ends a poison cloud lingers (radius 36 px, 3 s, 1 poison a second, no slow). The cloud's centre is the cone's end clamped by `terrain_hit`, so it is never inside or behind a wall | `poison_breath.gd` plus the zone |
| | **Venom Bolt** (5) | An instant line along the aim, 260 px, that pierces (`targets_in_front(260, 20)`, cut at the first rock): every enemy on it takes 9 poison once. The moving bolt is drawn by the effects spec; only the hit is gameplay | `targets_in_front` plus `terrain_hit` |
| **Spore Cloud** (level 4) | **Healing Spores** (4) | A cloud that does not poison or damage: the slime heals 1 HP a second while inside it, enemies inside are still slowed. Radius 40 px, 4 s (its own duration, not `SporeCloud.duration_for`), dropped at the caster plus aim x 32 like Spore Cloud, so the slime is inside at cast time | the zone with `heals` |
| | **Puffball** (5) | A pod lobbed along the aim bursts where it lands into a cloud of radius 64 px, 3 s that poisons and slows like Spore Cloud. The pod's velocity is `aim * 220 + Vector2(0, -150)` with gravity 600 (a horizontal aim lands 110 px away at launch height in 0.5 s; an up-forward aim, whose vertical launch speed is 150 + 220/sqrt(2) = 305.6 px/s, is back at launch height after 1.02 s and on a floor 12 px lower after 1.06 s). The pod starts at `actor.global_position`. The landing point is computed at cast time by stepping the arc in 1/30 s segments, at most **40 segments** (1.33 s: straight up needs 1.23 s to return to launch height), stopping at the first rock (`terrain_hit`); the cloud goes at that point, or where the last segment ends | the zone plus a short arc loop in the ability |

Five abilities are new (Binding Web, Miasma, Venom Bolt, Healing Spores, Puffball). The three that exist (Swing Thread,
Water Blade, Jet Dash) keep their behaviour and numbers and gain only `replaces` and the shared unlock. They share **one** new piece, the **zone**: `SporeCloudArea` made general,
`launch(at, radius, seconds, actor, opts := {})`, where `opts` holds `damage` (default 1; 0 means no `receive_hit` at all,
since `Damage.direct_hit` floors at 1 and a hit sets the hurt timer), `slow` (default true), `heals` (default 0) and
`color`, so `SporeCloud` and the six 4-argument calls in `tests/test_spore_cloud.gd` are unchanged. Slowing runs **every
physics frame** for anything inside (`Enemy.slow_for` is idempotent), so a fast enemy crossing between ticks is still slowed;
damage and healing stay on the 1 s tick. `_physics_process` now processes a due tick **before** it checks expiry, so a zone
of N whole seconds ticks exactly N times whatever the float drift (today the last tick is skipped or kept by the sign of a
1e-15 remainder, and a 1 s zone ticks zero times). A test pins 1, 2, 3 and 4 s driving real physics frames. Healing finds the caster (`_actor`, whose team the zone otherwise skips) within the radius and calls
`health.heal`. `terrain_hit` moves from `ThreadAbility` up to `Ability` (unchanged behaviour, one move; `tests/test_grapple.gd`
covers its rock branch and its `_solid` and `_cast` fixtures serve the new tests).
A third branch per parent is possible later. Two candidates were cut because they are new subsystems, not small changes: a
**Zip Line** thread (`Player._stay_on_rope` pays out any reel on the floor, and the launch is `Rope.release_velocity`) and a
**Torrent** wave (enemies have no knockback: `Enemy.receive_hit` only damages). Also deferred, from the research: a Weaver,
Sporelings, a Thread Recall teleport, a charged Jet Dash and a held Water Blade (the last two belong to the channelling
spec). Miasma and Puffball are close to Spore Cloud on paper (a cloud, a bigger cloud); they earn their place by being
reachable from the other parent and by replacing it in the slot, and if one is cut later the model does not change.

## Engine and data changes

- `SkillRulesEngine`: build `_children` (parent id to the evolution ids whose `replaces` is it) in `setup()`, with public
  `siblings_of(id)` for the screen. Two pure predicates: `is_retired(id)` (an evolution that replaces it is owned) and
  `is_closed(id)` (an unowned evolution whose parent `is_retired`). Five write-site edits establish everything:
  - `owned()` excludes retired ids.
  - `_evaluate` returns first for a retired or closed id (no levelling, no discovery, no readiness, no re-grant).
  - `recheck_levels()` iterates `owned()`, not `_owned.keys()`: it calls `_check_level` directly, bypassing `_evaluate`, and
    `Player.advance_form` runs it right after raising the stage cap, so a retired parent with casts banked past the cap
    would otherwise level and announce "Your skills grew."
  - `evolve()` erases the siblings' ready flags (the `_evaluate` guard stops anything re-adding them while the drain that
    `evolve()` itself runs handles the queued `SKILL_UNLOCKED`). It already returns false for an id that is not ready, so it needs no
    separate closed check.
  - `grant()` refuses an evolution (its `_ready_evolutions.erase(id)` becomes dead and is deleted in the same edit).
  Nothing else in the engine needs a guard: every screen row goes through `owned()`, `_ready_evolutions` has one adder
  (`_evaluate`), and `grant()` and `_evaluate` already refuse an id in `_owned`, which is why a retired parent cannot come
  back. Regression tests still pin each.
- `SkillDef`: the `replaces` comment says it is the branch key and the slot to take.
- `DefValidator`, added to the existing checks (an enemy-only `skill_level` parent is rejected at `def_validator.gd:70-71`
  and `replaces` must be one of the `skill_level` parents at `:78`, so the parent is already a player skill): every
  evolution has a non-empty `replaces`; the parent is not itself an evolution and has an active scene; the evolution has an
  active scene; it is not `starting` (`start_run()` would grant it directly, past the EP choice and the `grant()` guard); its `unlock` is exactly one `skill_level` condition whose id is its `replaces` (so cost is one by
  construction and "parent alone" holds); evolutions that share a `replaces` share that condition's `n`; every evolution has
  `max_level` 1 and an empty `levels_on`. A content test pins that each shipped parent has exactly two evolutions.
- `RebirthKit.validate` rejects an evolution id (with a case in `tests/test_rebirth_kit.gd`). `tools/build_forms.gd` and
  `data/forms/*.tres` change as above; `FormValidator` is unchanged and `tests/test_forms.gd` gains the assertion that no
  form grants an evolution.
- `CompendiumModel.self_report` skips closed evolutions. `SkillScreenModel.skill_rows`: rows are `owned()` skills, and
  `locked` counts a skill that is non-secret, not ready, **not closed** and has `level_of == 0` (so neither a retired parent
  nor a closed evolution turns on "???"); `ACTIVE_LABEL` gains the five ids. Each skill's one `values` entry (`Ability.value()`) is: Binding Web `[2]` "Hold tier", Miasma and
  Venom Bolt `[9]` "Damage", Healing Spores `[40]` and Puffball `[64]` "Radius"; the other numbers are constants in the script,
  as `RANGE` is in `poison_breath.gd` (Jet Dash has no `values` today and keeps none).
- `SkillScreen`: `_armed` is an evolution **id** held beside `_sel`. One rule in `_refresh()`, in the skills path right
  after `_selectable` is rebuilt and before `_build_detail()`: if `_armed != selected_id()` clear it (this covers a move
  that changes the selection, a refresh that drops the row, and a tab switch, which holds only because `switch_tab` resets
  `_sel` to 0; a comment says so); `close()` clears it explicitly, and so does a successful `try_evolve` (after the first evolution the clamped selection can
  land on the child's own row, whose id equals `_armed`). Detail card lines "Replaces X", "Closes: Y" (from
  `siblings_of`), "Evolved from X"; the doc on `accept()` is updated.
- `tools/build_content.gd`: the five new skills; `replaces` set on Water Blade and Jet Dash; all three existing evolutions
  reduced to `skill_level` of their parent at 3 (Water Blade from 2, Jet Dash and Swing Thread lose their second condition);
  the section comment "parents kept" corrected. `data/skills/*.tres` regenerated. Each new skill gets a scene and script
  under `scenes/abilities/` and `scripts/abilities/` (the validator requires the scene).
- **Tests that change**, with why: `test_levels.gd:93-142` (Water Blade needs 12 casts, not 6, since Hydraulic Propulsion
  levels every 6; `evolution_cost("jet_dash")` is 1; both branches ready together; the one-press evolve becomes two
  presses; the row text) and the stale comments at `:154-164`, `test_scripted_run.gd:53-55` and `:67-68` (the Lv2-ready
  assertion moves to Lv3; the `level_of("hydraulic_propulsion") >= 1` assertion stays and is why `level_of` means
  reached), `test_content.gd:42` (Jet Dash's two parents), `test_skill_screen.gd:71` (its condition text),
  `test_def_validator.gd:144-149` (the fixture that sets `replaces = "leap"`), `test_skill_rules_levels.gd:75-90` (a
  two-parent evolution the one-condition rule now forbids; it is engine-only, so it still passes and is rewritten only to stop
  pinning a shape the data rule forbids), `test_rebirth_kit.gd:143-147` (a stale message, and the new
  rejection case), `test_mana.gd:70-77` (five costs), `test_content.gd:23` and `test_autoloads.gd:4` (each pins the skill total, 24, which becomes
  29), `test_forms.gd` (the no-evolution-grant assertion). `test_audio_catalog.gd` and
  `test_art_assets.gd:48-51` loop over every skill, so they fail on their own until the five cues and icons exist and
  need no edit.
- **Doc surfaces**: `skill_rules_engine.gd` comments at the `evolution_cost`, `grant`, `is_capped`, `recheck_levels` and
  `owned` docs; the `compendium_model.gd` Lv4 doc; `skill_screen_model.gd`'s `skill_rows` doc; `enemy.gd`'s `slow_for` doc
  ("a thread and Spore Cloud both call it"); the `SporeCloudArea` header ("never touches the player") and the `ThreadAbility`
  header; `docs/playtest-checklist.md`'s evolution lines.

## Failure modes and edge cases

- Two evolutions ready in the same drain: the design; the first `evolve()` closes the other, and no `evolution_ready` is
  emitted for it during that call.
- An "Evolution available" announcement queued for a sibling before the choice still plays after it. Accepted: it is a line
  of text and the sibling stays Named.
- Death and rebirth: `reset_run()` clears `_owned`, which is all the state there is, so every branch reopens.
- A retired parent's essence keeps being eaten: its counters keep counting, and it neither levels nor unlocks again.
- The four base actives fill the four slots and each evolution replaces its parent in place, so slot eviction (LRU) cannot
  fire on an evolution and the slot keeps its position, so muscle memory holds.
- A player with 0 EP reaches the evolution level: the rows show, the card says how to earn EP, and a second press does nothing.
- Puffball, Venom Bolt or Miasma aimed into a wall at point-blank: `terrain_hit` finds rock in the first segment and the
  cloud or the line ends at the slime; nothing is placed inside or behind rock.
- A cloud placed where an exit opens to the room below: the arc simply runs its 40 segments and the cloud goes at the end.
- Thin ledges are one-way, so `terrain_hit` from below may pass through them (the thread already shares this): one test
  pins a ray cast upward through a one-way ledge, whichever way the engine goes.

## Testing

Engine (RED first): evolving retires the parent (`owned()`, slot, `level_of` stays reached), closes siblings
(`ready_evolutions()` omits the closed ids after `evolve`, `evolve` of one is false, `siblings_of`), a **retired parent does
not level**: bank casts past the stage cap, evolve, `set_stage_cap(8)`, then call `recheck_levels()` as `advance_form` does
and assert no `skill_leveled` and `rechecked(0)` (a test that only casts again would pass with the hole open), `grant()` of
an evolution is false, plus regression pins that a retired parent is not granted again by an `absorbed` event or by `grant()`
and that `reset_run` reopens. Validator: each new rule with a bad def (an empty `replaces`, a `starting` evolution, a second unlock condition, an
evolution without an active scene, a levelling evolution, siblings with different unlock levels) and the pinned "two per
parent" content test. Forms and kits: `RebirthKit.validate` rejects an evolution id; advancing to Tempest or Tidal changes no
branch; no shipped form grants an evolution; the Form card omits an empty "Grants:" line and lists only receivable grants; a
form with `binding_web` still gets the thread-family boost (`THREAD_SKILLS`). Compendium: `self_report` omits a closed
evolution. UI model: a retired parent is not a row and does not turn on "???", a closed branch does not either. UI: arm by
id, the second press evolves, a move that changes the selection, a tab switch, `close` and a refresh that drops the row
disarm, row and card text fit their labels. Zone: an enemy **moving at 90 px/s across** a 40 px patch is slowed (a 1 s tick
would miss it), damage 0 leaves an enemy's HP untouched and does not set its hurt timer, healing heals the slime only while
inside and on the 1 s tick, zones of 1, 2, 3 and 4 s tick 1, 2, 3 and 4 times (driving real physics frames) and expire. Each ability: Binding Web holds an enemy,
never attaches a rope, and puts the patch (damage 0) at the enemy, at rock and at full range; Miasma leaves a poisoning,
non-slowing cloud at the cone's end clamped at rock; Venom Bolt hits two enemies once each, stops at rock and at 260 px, and
takes an enemy at the segment's edge; Puffball lands at the floor on a horizontal aim **and on a 45 degree aim on flat
ground**, bursts against a wall, and stops at the 40-segment cap; `terrain_hit` still passes its `ThreadAbility` tests from
`Ability`. Data: every new skill loads, has a scene, an icon, a cue, a label and a pinned MP cost, and its evolution unlock
is the parent alone. One end-to-end test loops over the parents and their branches: each evolves in a fresh run, the
sibling closes and the slot holds the child.

## Rulings I made

1. **Exclusive per life**, not re-pickable. The game's loop is reincarnation, so trying the other branch is a rebirth away.
   Cost if wrong: an unhappy player restarts; a later respec is small because the state is derived (drop the owned child).
2. **Siblings unlock together, on the parent alone, and the validator enforces it.** A permanent choice should be made among
   all its options, and it removes the reachability and "Closes: a name you have not seen" problems. Cost if wrong: less
   build flavour than cross-skill pairings; they can come back by relaxing the one-condition rule to "equal conditions".
3. **Only `evolve()` evolves.** Kits and forms grant base skills. Cost if wrong: a form that wanted a free evolved skill
   gives an EP-bought one instead.
4. **Evolutions are single-level, set near the parent's mid-game.** Avoids about seven value tables and levelling data now.
   Cost if wrong: the parent would have out-scaled the evolution (Hydraulic push is 741 px/s at level 6 and 1140 at level 15
   against Jet Dash's shipped 700; Poison Breath is 16 at level 15 against Venom Bolt 9; Spore Cloud's radius is 52 at its
   level-8 ceiling against Healing Spores 40), and evolving is permanent for the life. The remedy is data only (`levels_on`
   and a value table per skill), and because `level_of(parent)` is kept, an evolution could also scale by the parent's
   reached level without new state.
5. **Derived state, one `replaces`.** `owned()` is held, `level_of` is reached; a second table for the "ghost" is not
   needed if the two words are used consistently. If a future evolution should coexist with its parent or become a
   passive, that is the point to add a separate field for the slot; nothing needs it now.
6. **No `direction` label.** The card shows each branch's description. Cost if wrong: one string field later.
7. **Two branches per tree now**; Zip Line and Torrent wait for the rope and enemy-knockback work they need.
8. **Two presses to evolve**, because the choice is permanent for the life.
9. **Venom Bolt is an instant line and Puffball computes its landing at cast time, capped by segment count**, so no
   projectile class is added. Cost if wrong: nothing can dodge or block a bolt in flight; the effects spec draws the flight
   and a real projectile can replace the line without changing what the skill hits.

## Not here

Hold-to-channel casting, the water stream that becomes a blade, the web that can be held, and the new visual effects for web,
water and blade (a separate spec, next). Passive evolutions. Summons. A respec. Third branches (Zip Line, Torrent).
