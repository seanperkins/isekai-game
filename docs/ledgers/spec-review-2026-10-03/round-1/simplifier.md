# The Simplifier, round 1: essence overhaul + skill tree screen specs

Lens: Ousterhout (deep modules, accidental complexity, pass-through, YAGNI, complexity budget).
Every file:line below came from a tool result in this session.

## One-paragraph take

Spec 1 is mostly sound in its core (elements as data, mix unlocks via the existing AND, essence-priced evolution). It is
carrying four ideas that make it bigger and riskier than it needs to be: a lineage ranking and 3-offer cap that the design doc
contradicts, a kit invariant that forces new power grants, a per-sibling price that the validator must then keep equal, and
three "changes" that are already true in the code. Spec 2 builds the maximal interpretation of an unresolved question (forms in
the graph) and invents the pan/zoom/mouse/pad scheme the doc explicitly left open, on top of data that is mostly 15 isolated
nodes and four 3-node trees. The boring alternative for both is below under "The one proposal".

## Citations checked (what held and what did not)

Held: `Essences.ALL` is the 10 trait names (`scripts/core/essences.gd:16`); `Ledger._matches` is a superset tag match
(`scripts/skills/ledger.gd:33-37`), so `predated {"family": "spider"}` needs no engine change; the engine comment "The caller has
already paid its EP" (`skill_rules_engine.gd:134`); `FormOffers.supply/affinity/absorbed_units/ELIGIBLE/FIRST_EVOLUTION_AREAS`
(`form_offers.gd:8,14,36,54,66`); `Progression.ep/spend_ep/seeded` (`progression.gd:20,25,92`); `RebirthKit.ESSENCES` and
`eligible_lineages` (`rebirth_kit.gd:7,50`); `DefValidator._check_siblings` (`def_validator.gd:104`); the creature table in
Spec 1 is the mechanical mapping of `tools/build_content.gd:248-308` (I recomputed every row, all correct); 24 forms plus the
slime root (`tools/build_forms.gd:22-69`); 27 non-enemy skills = 19 base + 8 evolutions, 4 parents with exactly 2 branches each;
`SkillDef.secret`; `compendium_rows` shows conditions only at OWNED_ONCE (`skill_screen_model.gd:70-71`); `map_view` returns whole-world
bounds (`skill_screen_model.gd:201`); `Profile.dict_section` exists; `FONT_SMALL = 8`, `layer = 20`, `COL_BORDER`, `COL_DIM` exist in
`skill_screen.gd`; the kits in `data/rooms/G1.tres:111-117`, `F1.tres:65-70`, `D1.tres:52-57` match the spec's description.

Did not hold, see findings F6, F7, S1, S2, S3: three Spec 1 "changes" that are no-ops or target a thing that does not exist, and
Spec 2 cites `project.godot` for input actions that live elsewhere.

---

## SPEC 1 (essence overhaul)

### F1 [MAJOR] The lineage ranking and the 3-offer cap are accidental complexity, and the ranking is structurally biased

Spec 1 ranks open lineages "by the total levels reached across the lineage's powers", cap 3. Problems:

- The sum favours lineages with more powers. Bulwark lists 3 powers, Toxic 2, Weaver/Tide/Echo 1 each. At stage 1 every power caps at
  level 5 (`BASE_STAGE_CAP`, `skill_rules_engine.gd:22`), so a one-power lineage tops out at 5 and Bulwark at 15. Worse, Body Armor
  and Hardened Shell level on `damaged` (`build_content.gd:117,147`), i.e. passively, while Sticky Thread, Hydraulic Propulsion, Poison
  Breath and Spore Cloud level only when the player casts them (`skill_used`). The offer would be set by which lineage took the most
  hits, not by what the player chose. Echo and Weaver would be the ones routinely cut.
- Almost every lineage is open after the Cave and Grotto (echolocation at 3 air, hydraulic at 4 water, three spiders, a lizard), so
  the cap and ranking are doing the real work, not the "open" rule.
- It contradicts the doc: `docs/isekai-chronicles-design-doc.md:143` says "the player sees every evolution their current essence
  makes possible and picks one" and "A lineage is offered when you own one of its powers." No ranking, no cap.
- Today the full-pass case is already degenerate (`test_form_offers`: a full pass offers weaver, tide, toxic by LINEAGE_ORDER because
  `MAX_OFFERS := 3` at `form_offers.gd:9` cuts bulwark and echo). Spec 1 would replace one arbitrary cut with a different arbitrary cut.

Delete the ranking, the `MAX_OFFERS` cap and the "levels across the lineage" computation. Offer every open lineage in
`LINEAGE_ORDER`, plus the Greater Slime fallback when fewer than two are open. The Form tab can hold 5 rows: at stage 1 `d == null`
so `_build_form` starts rows at `LIST_TOP + 52` (`skill_screen.gd:663-722`), 5 rows x 22 = 110 px, well inside the 274 px list.
`FormOffers._first_offers` becomes about 6 lines.

### F2 [MAJOR] The "non-default pool opens at least two lineages" invariant is what forces Open Q2, and it is not worth its cost

The invariant existed because affinity needed 60% of supply. Under "open = you own a power" it buys nothing: one open lineage plus
Greater Slime is exactly what the default pool gives. To keep it, Spec 1 hands G1/F1/D1 new powers (`echolocation`, `sticky_thread`,
`hydraulic_propulsion`), which the kit then slots (`rebirth_kit.gd:70-73`), so pools change what the slime can do on arrival, and
rewrites `eligible_lineages` and `test_rebirth_kit`. Open Q2 then offers a second addition (a new kit field) to avoid that.
There is a third option that deletes work: drop the invariant. Kits keep `skills` and `level`, lose `affinity`, and nothing replaces it.
D1 already grants Tremor, which opens Bulwark. This removes `eligible_lineages`, the kit-grant data edits, a validator rule and the
rewritten test. If Sean wants pools to open lineages, that is a later decision, not one a test invariant should force.

### F3 [MAJOR] Spec 2's "forms open this life" cannot be reconciled with Spec 1's offers

Spec 2 says a form node shows when "its lineage is open this life (the same rule that decides the first offers)". Spec 1 defines no
function that returns open lineages, only `offers` with a cap and ranking. If the cap stays, the tree shows 5 open lineages while
the Form tab offers 3 (Echo or Weaver visible in the tree, impossible to choose). Deleting the cap (F1) removes the contradiction.
Either way Spec 1 must name one public `FormOffers.open_lineages(forms, rules)` that both read.

### F4 [MAJOR] `family` unlock has two unaddressed display regressions

- `condition_text` -> `_event_text` (`skill_screen_model.gd:177-183`) maps `predated` to the generic "Eat creatures"
  (`EVENT_TEXT`, line 14-17) and ignores tags. Sticky Thread's recipe line would read "Eat creatures x3", same as Regeneration's.
  The spec only specifies wording for mixes.
- `CompendiumModel.creature_report` names a power at appraisal level 2 only through `d.essences_used()`
  (`compendium_model.gd:160-166`). Sticky Thread no longer has an `absorbed essence` condition, so a spider stops naming it at
  level 2 (it still names it at level 3 via the creature's skill list). Spec 1 does not say how family-unlocked powers get hinted.
  Also `DefValidator._check_event_ref` (`def_validator.gd:116-125`) validates `source` and `essence` tags but would accept any
  `family` string, so a typo silently makes a power unobtainable.

### F5 [MINOR] Echolocation's leveling rate changes and is outside the calibration

Spec 1's calibration pins only the unlock point. Echolocation also `levels_on` the absorbed essence (`build_content.gd:105`).
Bat goes from sound 1 to air 2, moths add air 2 and 5, eels add air 1-3, so Echolocation levels at least twice as fast per bat
and from sources it never had. `test_skill_caps.gd:187` (`sound += int(c.essences.get("sound", 0))`) pins the Cave lap economy
for exactly this and is not in the spec's changed-test list. Add `level_curve` to the calibration or accept and record the change.

### F6 [MINOR] Three "changes" are already true or point at nothing (delete them from the spec)

- "`SkillDef.essences_used()` returns every element a mix names": it already loops every unlock condition and returns all
  essence tags (`skill_def.gd:51-56`). No change.
- "`compendium_model.gd` currently asks for an exact match on one ... any-element creature hint": the loop is
  `for ess in d.essences_used(): if c.essences.has(ess): raise(...)` (`compendium_model.gd:164-166`), already any-of. It
  becomes "any of the mix" for free. No change. (Design note: with shared elements this names almost everything from almost
  everything; a toad names Hydraulic Propulsion, Poison Breath and Spore Cloud. Worth a sentence.)
- "The room editor's kit fields drop `affinity`": the editor has no affinity field. Its kit fields are `kit_level` and
  `kit_skills` only, and it deliberately preserves other kit keys (`room_edit_model.gd:592-595, 625, 765-778`). Only a comment
  at line 625 mentions G1's affinity. The real impact is the tests that use `kit.affinity` as the probe for "unrelated keys
  survive an edit": `test_room_edit_model.gd:19-29` (asserts "a shipped room has a rebirth pool with a kit affinity", fails once
  G1's affinity is gone), `test_room_edit_fields.gd:73-79`, `test_room_editor_scene.gd:353-370`.

### F7 [MINOR] The impact list for tests is incomplete; use a grep-derived checklist

Spec 1 lists about 25 test files. Verified additional files that break and are not listed:
`test_first_evolution_areas.gd` (whole file is about `supply` and `FIRST_EVOLUTION_AREAS`), `test_rebirth_flow.gd:171,176`
(`affinity`, `seeded`), `test_rebirth_pool.gd:69,79,80,87` (affinity validation), the three room-editor tests in F6,
`test_pale_moth.gd:24`, `test_deep_slice.gd:18`, `test_skill_caps.gd:187`, `test_defs.gd:17,21`, `test_skill_rules_levels.gd:46,52`,
`test_player.gd:68`, `test_accessors.gd:7,9`, `test_audio_runtime.gd:66,71,82`, and `test_web_tether.gd:152`, which unlocks Sticky
Thread by absorbing `thread` and will need `predated {"family": "spider"}`. `tools/evolution_shots.gd` feeds `"thread","water",
"poison","sound"` absorbs and hard-codes `switch_tab(5)`; it breaks too. Many of these use an essence event only as shorthand to
unlock a skill. A shared `TestDefs`/helper `unlock(rules, id)` would turn this churn into one place.

### F8 [MINOR] Price: put it on the parent power, not on each sibling

Spec 1 stores `evolution_price` on every evolution and adds a validator rule that siblings must be equal. The invariant is
structural ("the player chooses among branches that cost the same"), so store it once where it is structural: on the parent
(4 prices instead of 8, no sibling rule, no way to drift). `can_afford(id)` reads `get_def(def.replaces).evolution_price`.
Same validator weight otherwise (present iff the skill has evolutions). Also:
- "An empty price is free" exists only so hand-built test defs keep working, while shipped content must be non-empty. That is a
  production special case for test convenience; let the test defs supply a price (`tests/support/test_defs.gd`).
- `evolution_price(id)` on the engine would forward to the def, as `evolution_cost` does now. Callers already have `get_def`.
- The table gives elements but no amounts. The data test and validator cannot be written without them, and affordability
  against supply is unchecked (rooms respawn per `test_skill_caps.gd`, so it is pacing, not a hard cap).

### F9 [MINOR] The persistent HUD indicator duplicates an existing one

`Hud` already has a persistent `_evolve` label driven by `evolve_text()` ("Your body can evolve (Esc, Form tab)"). Spec 1 adds a
second persistent indicator for power evolution and does not mention the first. Fold both into `evolve_text()`/one label.
Also, `accept()` and the detail card are the only places that call `evolution_cost` besides `core_wiring.gd:23`,
`skill_screen_model.gd:43` and `player.gd:551,553`; list them (EP text also lives at `skill_screen.gd:205,382,439,477-479` and
`hud.gd:228-229`).

### F10 [MINOR] Scope and sequencing

Spec 1 bundles four independent changes: (a) forms-by-powers (a net deletion of `supply`, `affinity`, `absorbed_units`, `seeded`,
`default_supply`, `FIRST_EVOLUTION_AREAS`, `ELIGIBLE`), (b) the element vocabulary and creature table, (c) price/spend and EP removal,
(d) kit changes. (a) depends on no element. Ship (a) first: smallest diff, deletes code, keeps the suite green, and Spec 2's forms
questions disappear from the critical path. The one-off calibration script plus a committed docs table is also heavier than needed:
`test_content.gd` already has `test_essence_minimums_satisfy_every_essence_skill` (builds per-essence totals from placement minimums,
`test_content.gd:63-64`). Extend it to mixes and keep "within one eat" as a pinned table in that test, not a script.

---

## SPEC 2 (skill tree screen)

### S1 [MAJOR] Wrong file for the new input actions, and key choices are unspecified

"project.godot: the zoom (and free-pan) actions" is ungrounded. `project.godot` has no `[input]` section (sections are
`[application]`, `[autoload]`, `[rendering]`, `[display]`). Actions are registered at startup in `autoload/controls.gd`
(`BINDINGS`, `PAD_BUTTONS`, `PAD_AXES`, `ensure_actions()` called from `_ready`). The spec says "keys" but the obvious ones are taken:
W/S/A/D and arrows move or adjust, Q/E are `tab_prev`/`tab_next` (and `active_3`/`active_4` aliases per the comment in `controls.gd`),
Enter/Space accept, Backspace/Esc back. Pad triggers are free in a menu (they are `active_3`/`active_4` axes), so that claim holds.

### S2 [MAJOR] The tab insertion churns every existing tab-index test, and none are listed

Inserting Tree second shifts every numeric index: `test_skill_screen.gd:158-198`, `test_audio_ui.gd:48-64` (also pins
`TABS.size() == 5` at line 58), `test_map.gd:55,75`, `test_form_tab.gd:47-72` (pins `tab_layout(5)` as "today's layout" and the
Form tab at index 5), `test_evolution_screen.gd:163-164`, and `tools/evolution_shots.gd:38`. Spec 2's test section lists none.
Seven tabs also need a new stride (six already ends at x=552 of a 640 canvas, seven at the old stride would end at 640).

### S3 [MAJOR] The graph machinery is sized for structure the data does not have

Of 19 base powers, none has a `skill_level` unlock (only the 8 evolutions do; `build_content.gd:170-206`). The upper band is
15 isolated nodes plus four 3-node trees, drawn "one per row" (19 rows x about 14 px is about 270 px against a 274 px list,
with 4 stage columns of forms beside it in a 244 px column). That is a list with extra steps. The legibility bar ("no edge
crosses a node") is also unlikely to hold with "opens" edges running from arbitrary rows of the upper band down to the lower band.
The elements (the actual recipe structure) are not nodes at all.

### S4 [MAJOR] Pan/zoom/mouse scheme is invented and the mouse part is untested

The doc leaves "Pan and zoom controls for the tree" open (`design-doc.md:160, 232`). Spec 2 fills it with three zoom levels, a
selection-follow camera, wheel zoom, drag pan, click select, right-stick free pan, two new actions, and `neighbor(id, dir)`.
`scripts/ui` has no mouse handling today (grep for `InputEventMouse` in `scripts/ui` finds nothing), so this adds the screen's
first mouse path (hit-testing through camera offset in a stretched 640x360 canvas), and the test list has no mouse test.
Several parts are redundant with each other: the camera follows the selection, so free pan adds nothing; "close" zoom shows name,
pips and a detail line, which the card beside the graph already shows. Only overview ("see the shape") adds information.

### S5 [MAJOR] The forms band is built on an unresolved reading, with the cost front-loaded

Spec 2 asks (Open Q1) whether "evolutions" means body forms, then builds the forms band, `opens` edges, `FormLog`, and the
`forms_focus` fallback anyway. Dropping the band is a strict subset of the work, so default to the small reading and add the
band when Sean confirms. That removes `FormLog`, the species-keyed persistence, `forms_focus`, the cross-band edges, the dependency on
Spec 1's `FormDef.powers`, and the F3 inconsistency. Persistence detail: `FormLog` stores a dictionary whose only value is the
constant string "reached" under a species key "so the spider adds a branch instead of a migration". A new Profile section needs no
migration (sections are independent, `profile.gd:45-60`), so the species key is speculative. `WorldProgress` already persists "what
the player has found" and the species (`world_progress.gd:27-31,97-101`); a list there is smaller than a new class.

### S6 [MAJOR] Persistence trigger listens on the audio-only bus

"`reached` is written when ... the `evolved_body` event the player already emits." That event is emitted on
`EventBus.world_event` (`player.gd:613`), documented as "audio-only semantic moments ... Never counted; only Audio listens"
(`autoload/event_bus.gd:5-6`). Saving game state off it violates that contract. Record it in `Player.advance_form` directly
(the one place `form.advance` succeeds) or via a Player signal.

### S7 [MINOR] A second evolve entry point contradicts Spec 1's restraint

Spec 1 defers the in-world chooser because the controller has no free button. Spec 2 adds a third evolve surface (Skills tab, Tree,
later the HUD prompt), a shared helper, and arm state that must be disarmed correctly across tabs (`_armed`, `skill_screen.gd:59`, reset in `close()` at line 108). Make the tree read-only in v1 (Open Q3's own fallback). The shared helper then goes away.

### S8 [MINOR] Secret skills leak through the full-tree layout

Layout is "computed from the full tree, discovered or not ... an undiscovered node leaves its slot empty". Secret skills
(`SkillDef.secret`, e.g. Glutton at `build_content.gd:87-94`) are deliberately excluded from every "???" teaser
(`counts_as_locked`, `skill_screen_model.gd:22`; `self_report`, `compendium_model.gd:124`). An empty slot at Glutton's row reveals that
something is there. Exclude secret skills from the layout until owned. The spec never mentions `secret`.

### S9 [MINOR] Other grounding gaps

- The Form tab card is imperative code inside `SkillScreen._build_form`, not model code; "reuses the Form
  tab's card" requires extracting it first.
- All tree code lands in `skill_screen.gd` (already 789 lines): `_build_tree`, camera, zoom, input, evolve helper. A separate
  `SkillTreeView` node keeps `SkillScreen` from growing a second, unrelated responsibility.
- The existing screens rebuild widgets on every `_refresh` (the Map tab calls `_clear(_list)` then rebuilds). A retained `world`
  node with camera-as-position and a `_draw` edge pass is a different idiom; either is fine but the spec should pick one deliberately.
- The unlock-condition wording for mixes ("Absorb water and dark essence") needs a rule when the two thresholds differ.

---

## The one proposal (delete this / merge these)

1. **Spec 1: delete the ranking, the cap, and the two-lineage kit invariant.** Offer every open lineage in `LINEAGE_ORDER` (plus
   Greater Slime if fewer than two). Kits keep `skills` and `level`, lose `affinity`, gain nothing. This removes `eligible_lineages`,
   three kit-data edits, one validator rule, a test rewrite, and Open Q2. It also matches `design-doc.md:143`.
2. **Spec 1: remove the three non-changes** (`essences_used`, the compendium any-element hint, the editor "affinity field"), put the price on
   the parent power, and ship forms-by-powers as its own first milestone (it only deletes code).
3. **Spec 2: build the pure `SkillTreeModel` for powers only** (nodes, edges, states, stubs, secret-aware), and render it first as an
   indented tree list (parent with its branches below, "???" stub rows, price/held in the existing detail card), read-only. That
   delivers the doc's "tree grows as you find it", stubs and hidden ingredients with no layout, camera, mouse or new input actions.
   The 2D canvas becomes a second renderer over the same model once forms, elements and a second species give the graph structure.
   If the canvas is kept now: selection-follow camera, one overview/normal toggle, no mouse, no free pan, actions added in
   `autoload/controls.gd`.
4. **Spec 2: replace the Compendium tab with Tree rather than adding a seventh tab.** Both views are the same Compendium state;
   `compendium_rows` and `condition_text` already feed the card. Base tabs stay at five, `tab_layout` and every tab-index test stay
   as they are. If Sean wants Compendium kept, append Tree at the end instead of inserting it second.
5. **Forms band, `FormLog`, `forms_focus`: defer** until Open Q1 is answered. If they ship, persist from `Player.advance_form`, not the
   audio bus.

## Complexity budget

Value delivered by Spec 2's full design (a navigable picture of 27 powers and 25 forms) is real, but about 60% of its machinery
(three zoom levels, mouse, free pan, shared evolve helper, `FormLog`, `forms_focus`, two-band layout with cross-band edges) serves
interactions the doc left open or a reading Sean has not confirmed. Spec 1's budget is justified once F1, F2, F6 and F8 are applied.

VERDICT: REVISE — concerns above should be addressed first
