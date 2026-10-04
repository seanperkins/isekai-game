# The Simplifier, round 1: essence overhaul (spec 1) and skill tree screen (spec 2)

Repo root: /Users/sean/sites/isekai-game, branch docs/design-direction. Every citation below was read or grepped this session.
Element-supply numbers come from a script I ran over `data/rooms/*.tres` spawns and the creature table in `tools/build_content.gd`. Nothing was written to the repo.

## Citations checked

Confirmed as written:
- The skill, creature, form and UI files, classes and functions the specs cite.
- `evolution_cost` (`scripts/skills/skill_rules_engine.gd:130`) and the "caller has already paid its EP" comment (`:134`).
- HUD `EP %d` (`scripts/ui/hud.gd:228-229`) and the announcer text "— %d EP in Skills" (`scripts/core/core_wiring.gd:23`).
- `Progression.seeded`, `kept_ep` and `spend_ep` (`scripts/actors/progression.gd:25,62,66,92`).
- `RebirthKit.ESSENCES` and `eligible_lineages` (`scripts/world/rebirth_kit.gd:7,50`).
- `Profile.dict_section` and `list_section` (`scripts/persistence/profile.gd:49,60`).
- The `evolved_body` event (`scripts/player/player.gd:613`).
- `Controls.using_joypad`, `COL_BORDER`, `COL_DIM`, `FONT_SMALL` and `layer = 20` (`scripts/ui/skill_screen.gd:34,38,44,84`).
- `SkillScreenModel.map_view` and `detail` (`scripts/ui/skill_screen_model.gd:193,122`).
- `tools/evolution_shots.gd`.
- The creature mapping table in spec 1: all 19 rows match `tools/build_content.gd` and the mapping rules.
- The counts: 27 non-enemy skills (19 base plus 8 evolutions) and 24 forms.
- "No save migration": Profile and Bestiary hold no essence names.

Wrong or ungrounded claims are listed in the findings below.

## Proposals

These come first because this review's lens is "delete this / merge these".

1. **Delete `CreatureDef.family`, the `family` PREDATED tag and its tests (spec 1).** `Player._complete_predation` already emits `PREDATED {"source": c.id, "kind": kind}` (`scripts/player/player.gd:812`). `Ledger._matches` matches any tag subset (`scripts/skills/ledger.gd:33-37`). Sticky Thread can unlock on `predated` with `{"source": "spider"}` and no new code. The Black Spider is placed 5 times, all in the Cave (my spawn count), so the third spider is always a Black Spider. The Taratect is placed once, in the Deep, and is irrelevant to the first unlock. Add `family` when a second spider-like source needs it (the playable spider, or an OR group).
2. **Delete three "changes" that describe code that already behaves that way.**
   - `SkillDef.essences_used()` already returns every distinct essence across all `absorbed` unlock conditions (`scripts/skills/skill_def.gd:50-56`). It already returns `[water, dark]` for a mix.
   - The Compendium creature hint already raises a skill when the creature carries any of `d.essences_used()` (`scripts/compendium/compendium_model.gd:164-166`). The spec's "currently asks for an exact match on one" is false.
   - "Creature cards list their elements" is already true (`scripts/ui/skill_screen_model.gd:110-111`, `scripts/ui/status_text.gd:50-54`).
3. **Put `evolution_price` on the parent skill, not on each evolution.** That is 4 entries (Sticky Thread, Hydraulic Propulsion, Poison Breath, Spore Cloud) instead of 8 identical ones. The "siblings must share one price" validator rule and its test disappear because it is true by construction. `evolve(id)` reads `_defs[d.replaces].evolution_price`.
4. **Offer every open lineage instead of ranking by summed levels (spec 1, Forms).** See finding S1-3. Drop the ranking sort. If a cap is kept, rank by the highest single power level, not the sum.
5. **Spec 2: shrink the tree to what is actually a graph.**
   - Show only the 8 base powers that have an edge (the 4 with evolutions, plus Echolocation, Body Armor, Hardened Shell and Tremor, which open lineages) plus the 8 evolutions plus forms.
   - Delete mouse (wheel, drag, click) and right-stick free pan.
   - Delete the `close` zoom level.
   - Delete the `forms_focus` fallback until a screenshot proves it is needed.
   - Delete evolve-from-tree and its shared helper.
   - Delete the `FormLog` class and its species-keyed dict.
   - Put the drawing, camera and zoom in a new `SkillTreeView` control instead of growing `scripts/ui/skill_screen.gd` (789 lines).

## Spec 1: findings

### S1-1 MAJOR: the "Changed tests" list is incomplete, and the missing tests hit hard errors

Removing `Progression.seeded` and the kit `affinity` key makes these tests fail. They are not on the spec's list.

- `tests/test_first_evolution_areas.gd`:
  - It is entirely about `FormOffers.supply`, `FIRST_EVOLUTION_AREAS` and `default_supply` (`:29-36`, `:51-54`).
  - It must be deleted, and the spec never says so.
- `tests/test_rebirth_flow.gd:171,176`: applies a kit with `affinity` and asserts `player.progression.seeded.is_empty()`.
- `tests/test_rebirth_pool.gd:69,79,80,87`: validates kit `affinity` errors ("essence", "units", "affinity").
- `tests/test_room_edit_fields.gd:73-79`, `tests/test_room_edit_model.gd:19-29` and `tests/test_room_editor_scene.gd:350-370`: all assert that G1 ships a kit `affinity` and that edits preserve it.
- `tests/test_deep_slice.gd:18`: pins the Taratect's `{"thread": 3, "poison": 2}`.
- `tests/test_pale_moth.gd:24`: pins `{"spore": 3, "flight": 2}`.
- `tests/test_skill_caps.gd:187`: sums `c.essences.get("sound")` (see S1-2).

Reading a missing property such as `progression.seeded` is a GDScript runtime error, and `tools/run_tests.sh` treats any `SCRIPT ERROR` in the log as a whole-run failure. The spec's sentence "the full suite passes" therefore depends on a complete list.

Fix:
- Replace the enumerated list with "grep tests/ and tools/ for the removed names and old essence strings", and give the grep.
- Add `tools/evolution_shots.gd`. It feeds `["thread", "water", "poison", "sound"]` as essences and hard-codes `switch_tab(5)`. After the change it would silently offer Greater Slime only.

### S1-2 MAJOR: Echolocation's levelling rate is not calibrated, and an existing test pins it

Echolocation unlocks and levels on the same counter (`tools/build_content.gd:104-105`: unlock `absorbed sound 3`, `levels_on absorbed sound`, `level_curve` 3, `max_level` 8). Spec 1 re-points both at air (table row "Levels on: air absorbed"). Its calibration only measures unlock points.

Air is far more plentiful than sound:
- Per Cave lap, sound is 6 and air is 12.
- Bat, Spore Moth, Pale Moth, the eels and the wolf all carry air.
- The Pale Moth alone is air 5, about 1.7 levels per eat.

`tests/test_skill_caps.gd` already asserts Echolocation's top level is "more than one lap, within six laps of the Cave", and it will fail on the `sound` sum. This is a rate regression that the "within one eat" criterion does not catch. Add a `level_curve` retune, or an explicit acceptance, to the calibration. Add `test_skill_caps` to the changed list.

### S1-3 MAJOR: ranking lineages by total levels rewards passive levelling and lineages with more powers

Under the new rule the stage-1 ranking is the sum of `level_of` across a lineage's powers.

- Bulwark has three powers, Toxic two, and Weaver, Tide and Echo one each.
- At stage 1 every power is capped at `BASE_STAGE_CAP` 5 (`scripts/skills/skill_rules_engine.gd:22`). Maximum sums are Bulwark 15, Toxic 10, the rest 5.
- Body Armor levels on every `damaged` event, and Hardened Shell on physical `damaged` (`tools/build_content.gd:117,147`). Echolocation levels on eating air. Neither needs deliberate use.
- Weaver and Tide level only by use.

Bulwark will almost always take the first offer slot, because taking hits is passive and it has three powers. That is not intent. Most lineages will be open by the end of the first two areas, so with the cap at three, Weaver, Tide and Echo compete for one slot. This also makes the Greater Slime fallback nearly dead code.

The design doc's direction is "a lineage is offered when you own one of its powers" (line 243 of `docs/isekai-chronicles-design-doc.md`) and "the player sees every evolution their current essence makes possible" (line 143). The Form tab list fits 12 rows (`LIST_TOP` 46 to `LIST_BOTTOM` 320 at `ROW_H` 22), so five open lineages plus the fallback fit. Offer all open lineages, in `LINEAGE_ORDER`, with the fallback when fewer than two are open. This deletes `MAX_OFFERS` and the sort. If the three-offer cap is kept, rank by the highest single power level.

### S1-4 MINOR: the calibration criterion is route-dependent, and area-gating of powers is lost

Two parts.

**The criterion is route-dependent and its description is wrong.**
- The spec says unlock points are computed "walking the rooms and spawns in order, the way `FormOffers.supply` already does". `FormOffers.supply` (`scripts/forms/form_offers.gd:36-51`) sums essence units per lineage over spawns. It has no order and no unlock point.
- With AND recipes, the unlock position is the later of two counters. A different route moves it by several eats, so "within one eat" holds only for one named walk. State that walk (the room order and "eat everything").
- Concrete case, per Cave lap: air 12, dark 10, water 19, earth 8. Spore Cloud (air and dark) must stay Grotto-gated to match today. That forces thresholds above the Cave supply of both (roughly 14 dark and 20 air, on a full clear, from my spawn counts). Those are cumulative-clear numbers, not recipe numbers.

**Area-gating is silently lost.**
- Rooms respawn on every entry (`scripts/world/room_builder.gd:120`; `tests/test_skill_caps.gd` also says "rooms respawn, so laps of the Cave farm it").
- Once elements are shared across creatures, a player can unlock Spore Cloud by farming Cave bats and toads. Today it needs Grotto spore creatures.
- That follows from the doc's design and may be fine. Say so in the spec rather than presenting "within one eat" as behaviour preserved.

### S1-5 MINOR: Sticky Thread loses its text and its creature hints

- `SkillScreenModel.condition_text` and `_event_text` render `predated` as "Eat creatures" (`scripts/ui/skill_screen_model.gd:14-17,177-183`). Sticky Thread would read "Eat creatures ×3". Regeneration reads the same today. The spec only specifies the mix wording.
- `essences_used()` is empty for a `predated` condition, so no creature card will ever hint Sticky Thread (`scripts/compendium/compendium_model.gd:164`). The spiders hinted it through `thread` before. This is a regression the spec does not mention.

If proposal 1 is taken, add one `{"source": ...}` line to `_event_text`. A hint rule that reads the source of a `predated` condition restores the creature hints.

### S1-6 MINOR: `tools/build_forms.gd` is not a safe source of truth

- `tools/build_forms.gd:2` says "Run once (then edit the .tres freely)", and `scripts/forms/form_def.gd:3-4` says the same.
- The review header and spec 1's file list treat it as the generator for `data/forms/*.tres`.
- `git log` shows only two commits touch `data/forms` (`4b6cd53`, `4305281`), and both also touch the generator. So the two are in sync today.

The spec should say which one is authoritative before regenerating. Otherwise a regeneration can clobber hand edits. Hand-editing 24 `.tres` files is the other option.

### S1-7 MINOR: smaller items

- "Every creature carries elements" in the Success list is false by the spec's own table. The Cave Serpent carries none.
- The spec gives no price numbers (every price cell reads "water + dark" and the like) and no threshold numbers. An implementer cannot write the data pin or the tuned values. Give starting numbers, or a rule such as "price equals the element's unlock threshold".
- The calibration table "committed under docs/" goes stale. A data test that walks the rooms and pins each power's unlock point also guards the next creature or area, and is worth more than a one-off script.
- Spec 2 needs a public `FormOffers` predicate for "lineage is open", independent of the cap and fallback. Spec 1 never lists it as API.
- `FormValidator` (`scripts/forms/form_validator.gd`) has no rule for the new `powers` field: known skill ids, stage-2 only.
- Kits: granting `sticky_thread` to G1, F1 and D1 makes every non-default pool open Weaver. That removes the variety the three pools had. Open question 2 should say this.

## Spec 2: findings

### S2-1 MAJOR: the legibility bar cannot be met with the stated layout, and the fallback fixes the wrong axis

- The upper band lists powers "one per row" in **name order**. All 19 base powers are included, but only 8 of them have any edge: the 4 with evolutions, plus Echolocation, Body Armor, Hardened Shell and Tremor, which open lineages.
- Eleven are edgeless: Appraisal, Glutton, Jolt, Leap, Mana Recovery, Pain Resistance, Poison Resistance, Regeneration, Swim, Toughness and Wall Cling. The Skills and Compendium tabs, which the spec keeps, already list them. They add 11 rows to the band for nothing.
- "Opens" edges run from a power row in an alphabetical list down to a stage-2 form in the lower band. Body Armor, Hardened Shell and Tremor are alphabetically far apart. Their edges to one form row must cross the nodes between them. "No edge crosses a node" is the spec's own bar, and it cannot hold with that ordering.
- `forms_focus` filters only the forms, so it cannot fix crossings in the power band. The bar is checked "everything discovered", so the check is guaranteed to fail the first time.

Fix: show only powers with edges (proposal 5) and order those rows by lineage. The band becomes 8 rows.

### S2-2 MAJOR: camera ownership is undefined, and mouse is a new paradigm

- "The camera follows the selection" and "the right stick pans freely" and "drag pans" contradict. The spec never says when a pan offset resets, or what the next selection move does.
- No other tab handles mouse. `scripts/ui/*.gd` has no `InputEventMouse` handling (the only "mouse" hits are `Controls.mouse_aim` debug text in the HUD).
- The rest of the plan reaches every node by direction keys (`neighbor`) and zooms by action. Free pan and mouse add input paths, InputMap actions and tests, and they conflict with follow-selection.

Delete them (proposal 5). The camera is a function of `(selection, zoom)`.

### S2-3 MAJOR: inserting "Tree" second shifts roughly 35 hard-coded tab indexes in tests

Tests call `switch_tab(n)` with fixed numbers:
- `tests/test_skill_screen.gd:158-198`
- `tests/test_map.gd:55,75`
- `tests/test_audio_ui.gd:48-111`
- `tests/test_evolution_screen.gd:163-164`
- `tests/test_form_tab.gd:49-244`

Compendium, Bestiary, Map, Sound and Form all shift by one. The spec's test list names none of these files. `TABS` is at `scripts/ui/skill_screen.gd:8` and `tab_layout` at `:130-131`.

Fix: append Tree last in `TABS` so only the Form index moves, and have tests look up tabs by name. Say which in the spec.

### S2-4 MAJOR: the Tree grows an already large screen class

- `scripts/ui/skill_screen.gd` is 789 lines and `extends CanvasLayer`. `_unhandled_input`, `_refresh`, `accept` and `_build_*` each already branch on the active tab.
- Spec 2 adds the Tree to the same class: `_build_tree`, camera, three zoom levels, mouse, pad axes and evolve. That is a fourth view's state in a class that currently owns four.

Put drawing, camera and zoom in `scripts/ui/skill_tree_view.gd` (a Control with `select`, `move(dir)`, `zoom(±1)` and `selected()`). `SkillScreen` hosts it in one tab branch. The interface grows by a few lines, and nearly everything else is hidden.

### S2-5 MINOR: Greater Slime is unplaced

- Layout rows come from `FormOffers.LINEAGE_ORDER` (`scripts/forms/form_offers.gd:10`): weaver, tide, toxic, bulwark, echo. It excludes `greater`.
- `build_forms.gd` defines four Greater forms (`greater_slime`, `vast`, `radiant`, `prime`). That is 4 of the "25 form nodes".
- No power lists them in `FormDef.powers`, so the "open this life" rule never shows them. They are reachable only by the fallback, so the spec never says when they appear.

### S2-6 MINOR: evolve-from-tree and the persistence design are heavier than they need to be

- Spec 1 keeps evolving in the Skills tab, with the HUD indicator. Spec 2 adds a second entry point plus "one shared helper so the two cannot drift". Dropping the second entry point drops the helper, the second `_armed` state and the tests. Open question 3 already offers this.
- `FormLog` is a wrapper class over `Profile` for a set of form ids. `scripts/world/world_progress.gd` already holds visited rooms, shortcuts, tablets, rebirths and `rebirth_choice` (including species) over `profile.list_section`. A `reached_forms` list there is about 6 lines.
- The species-keyed dict and the `species` parameter of `build()` are for a spider that does not exist yet. Spec 2 itself defers per-species Compendium.
- `Profile.dict_section` checks only the top-level type (`scripts/persistence/profile.gd:60-68`). The spec's "a malformed section is dropped and warns" will not catch a bad nested value. `FormLog` would have to validate.

### S2-7 MINOR: remaining items

- The `close` zoom level (name, pips and a detail line) duplicates the right-hand detail card shown at every level. Two levels (overview and normal) are enough.
- Node states have `ready` but no `affordable` (spec 1 separates them). "Say what is short" needs the state or an on-demand query.
- `neighbor()` ("nearest node in that direction") does not guarantee that every node is reachable by direction moves. The planned test needs a fallback rule or a graph-edge navigation scheme.
- "Reuse the Form tab's card" is not a reuse. That card is built inside `scripts/ui/skill_screen.gd` (`_build_form`), not in the model. It needs extracting.
- What wires the `evolved_body` event to the reached-forms write is unspecified.

## Contradictions between the two specs

- Spec 1 keeps evolving in the Skills tab and defers the in-world chooser. Spec 2 adds the tree as another evolve entry point. Three UIs would then hold one action: the tab, the HUD prompt and the tree.
- Spec 2 says its "open" rule is "the same rule that decides the first offers". Spec 1 limits offers to three and adds a fallback, so "open" is not "offered". Spec 1 does not expose the open predicate.

## Verdict

The two specs are well grounded, and the mapping table checks out. The EP and affinity removal is a net deletion and is the right direction. The problems are:
- Spec 1 under-counts the test and tool fallout and ignores Echolocation's levelling.
- Spec 1 specifies a ranking rule with a structural bias.
- Spec 1 describes two changes that are already true.
- Spec 1 adds `family` where an existing tag does the job.
- Spec 2 puts a legibility bar on a layout that cannot meet it, with a fallback on the wrong axis.
- Spec 2 has contradictory camera rules and a tab-index fan-out.
- Spec 2 piles mouse, pan, a third zoom level, evolve and a persistence wrapper onto a screen class that is already large.

VERDICT: REVISE — concerns above should be addressed first
