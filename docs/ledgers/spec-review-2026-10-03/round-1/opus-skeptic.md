# Opus Skeptic review: Essence Overhaul plus Skill Tree Screen specs (round 1)

I checked the specs against the repo on `docs/design-direction`. Every file:line below comes from a read or grep in this session.

## What checks out (verified, not assumed)

- **Derived creature table.** All 19 rows match the mapping when applied to `tools/build_content.gd:249-307`. For example, Storm Eel goes from shock 3, water 2 to light 3, air 3, water 2, and Taratect goes from thread 3, poison 2 to water 2, dark 2.
- **AND semantics.** `SkillDef.unlock` already means all conditions must hold: the comment is at `skill_def.gd:14` and the check is `_conditions_met` at `skill_rules_engine.gd:269-273`.
- **Superset tag matching.** `ledger.gd:41-45` matches on a subset of tags, so a `family` tag added to `PREDATED` does not break Regeneration's `{"kind":"creature"}` counter.
- **Retired parents count.** `level_of` counts a retired parent: `_owned` keeps the parent (`skill_rules_engine.gd:97-109`).
- **Unlock points.** The "within one eat" target can be met for the Cave-start full clear on these skills:
  - Echolocation: today it needs sound 3, which is the 3rd bat. Air 6 is also the 3rd bat.
  - Hydraulic Propulsion: today it needs water 4, which is the 4th toad in C1. Water 8 is also the 4th toad.
  - Body Armor: earth 6 is the 3rd lizard.
  - Hardened Shell: earth 14 is the 2nd crab, after the Cave's 8.
  - Poison Breath: dark 4 is the 4th toad.
  - Jolt: light count equals today's shock count.
  - Sticky Thread: Cave spiders only, so the 3rd spider.
- **Node counts in spec 2.** 9 proficiency + 10 essence = 19 base skills, plus 8 evolutions = 27. There are 24 form `.tres` files, plus the slime = 25.
- **Cited files and APIs that exist.** `Profile.dict_section`, the `evolved_body` event (`player.gd:613`), `SkillScreenModel.detail`, `compendium_rows`, `map_view`, `FormOffers.LINEAGE_ORDER`, `Controls.using_joypad`, `tools/evolution_shots.gd`, `tools/run_tests.sh`, and every test file named in spec 1's "Changed" list. The skill screen is a `CanvasLayer` at layer 20 (`skill_screen.gd:84`).

Spawn counts behind the arithmetic below come from `data/rooms/*.tres`:

| Area | Spawns |
|---|---|
| Cave | bat 6, toad 5, lizard 4, spider 5, water_pool 2 |
| Grotto | spore_moth 10, mushroom_crab 12, vine_snake 6, pale_moth 1 |
| Flooded | glass_eel 8, drift_jelly 5, cave_crayfish 5, bog_lizardman 6, storm_eel 1 |
| Deep | armed_ant 9, gloom_wolf 9, stone_drake 3, taratect 1 |

---

## CRITICAL

None. Nothing here makes either spec unbuildable. The MAJOR items below are the ones that would produce wrong behaviour or a red suite.

## MAJOR

### M1. Spore Cloud can now be farmed in the Cave, and the calibration criterion hides it (spec 1, Thresholds)

- **Cave supply after the change:**
  - air = 6 bats × 2 = 12
  - dark = 5 toads × 1 + 5 spiders × 1 = 10
  - Today the Cave gives 0 spore.
- **Spore Cloud's recipe is air and dark,** and both elements exist in the Cave. Any `n ≤ 10` on both conditions unlocks it in the Cave, without ever meeting a moth.
- **Holding today's unlock point (the 4th Grotto moth)** needs air ≈ 12 + 4×2 = 20 or dark ≈ 10 + 4 = 14. Even then, rooms respawn on every entry (`room_builder.gd:120`, and `test_skill_caps.gd:192` relies on Cave laps), so bats and toads farmed in the Cave unlock Spore Cloud anyway.
- **The gap:** the "unlock point on a full clear" criterion is blind to this, because a full clear never farms. The spec's own list of "new sources" omits bats and toads feeding Spore Cloud.
- **Fix:** pick one and state it.
  - Make one ingredient Grotto-exclusive (a new element, or earth as the doc's open question suggests).
  - Or accept Spore Cloud as Cave-farmable and record it as a deliberate move.
  - Either way, add a test that Spore Cloud's recipe is not satisfiable from Cave-only creatures, or the decision note.

### M2. One earth threshold cannot hold Tremor across the different starting points (spec 1, Thresholds)

- **Earth per area:**

  | Area | New earth | Old earth |
  |---|---|---|
  | Cave | 4 lizards × 2 = 8 | 4 |
  | Grotto | 12 crabs × 3 = 36 | 12 |
  | Flooded | 5 crayfish × 1 + 6 lizardmen × 1 = 11 | 6 (lizardmen only) |
  | Deep | 9 ants × 2 + 9 wolves × 1 + 3 drakes × 4 = 39 | 27 |

- **Cave-start full clear in Cave → Grotto → Flooded → Deep order:** today Tremor (24) unlocks at the 2nd ant in D1 (4 + 12 + 6 + 2 = 24). Holding that point needs a new threshold of 8 + 36 + 11 + 4 = **59**.
- **F1 rebirth life with that threshold:** one pass gives 11 + 39 = **50 < 59**, so Tremor is unreachable without farming. Today the same life has 6 + 27 = 33 ≥ 24.
- **Side effects of the same mismatch on an F1 life:**
  - Body Armor at 6 now unlocks in the Flooded. Today armor exists only on lizards, ants and drakes, so it waits for D1.
  - Hardened Shell at 14 moves from the 4th crayfish into D1.
- **Root cause:** the new-to-old earth ratio differs by area: Cave plus Grotto is 44/16 = 2.75, the Deep is 39/27 ≈ 1.44.
- **The gap:** the spec calibrates only the Cave-start full clear. It never names the G1, F1 and D1 rebirth lives.
- **Fix:** add the rebirth-start walks to the calibration script and state which one wins when they conflict.

### M3. Echolocation's levelling rate changes a lot and nothing calibrates it (spec 1, The powers)

- **Full Cave and Grotto clear:**
  - air = 12 (Cave) + 10 moths × 2 + 5 (pale moth) = 37
  - Unlock at air 6, so `base` = 6 and gained = 31.
  - Level = 1 + ⌊31/3⌋ = 11, which hits the stage cap of 5.
  - Today: sound 6, base 3, gained 3, so level **2**.
- **The Flooded adds more:** eels and jellies now carry air (8 + 5 + 3 = 16). The spec's "new sources" list leaves out the eels and the jelly feeding Echolocation, both its unlock and its levels.
- **The test does not catch it:** `test_skill_caps.gd:179-195` still passes after renaming sound to air (21 > 12 and 21 ≤ 72), so it gives no signal.
- **Fix:** have the calibration script print level-at-end-of-area for every `levels_on: absorbed` skill, not only unlock points.

### M4. Ranking by summed levels is structurally biased (spec 1, Forms)

- **Maximum summed level at the stage-1 cap of 5 per skill:**

  | Lineage | Powers | Maximum summed level |
  |---|---|---|
  | Bulwark | 3 | 15 |
  | Toxic | 2 | 10 |
  | Weaver, Tide, Echo | 1 each | 5 |

- **Passives level on their own:**
  - Body Armor (`damaged`, curve 10) and Hardened Shell (`damaged` physical, curve 10) both level from the same hits.
  - Echolocation reaches its cap on a full clear (M3).
  - Actives level only on `skill_used` (curve 6 to 8).
- **Result:** Bulwark and Echo will top the first offers for most players regardless of playstyle.
- **Fix:** rank by the maximum level within each lineage, or by mean level, or normalise by power count. Add a test using a scripted "typical full clear" ledger that asserts the offers are not always Bulwark plus Echo.

### M5. The evolution price never binds unless it exceeds what you have eaten; the spec gives no starting numbers (spec 1, Price)

- **Why it never binds:** recipes read eaten, and `held = eaten − spent`. Until some evolution spends, held ≥ every unlock `n`, so any price ≤ the unlock `n` is always affordable.
- **Dark eaten by the end of the Grotto** (when Poison Breath plausibly reaches level 4 after 24 casts): Cave 10 + Grotto moths 10 + snakes 6 + pale moth 3 = **29**.
- **Other elements at the same point:** water 19 + 6 = 25, air 37.
- **Three evolution families draw on dark:** Poison, Spore and Thread (if Open Q1 lands on dark). A price only matters if the sum of those prices exceeds about 29, or one price alone exceeds it.
- **Blocking gap:** the table's "starting values" column names elements but no units. `DefValidator` will require non-empty prices, so the implementation plan cannot proceed without numbers.
- **Fix:** give starting units, and state the target ("about N eats past the ready point").

### M6. The "any element" creature hint floods discovery, and spec 2 makes it visible (spec 1, Display, and spec 2, Growing)

- **The claim is false:** `compendium_model.gd:162-166` already loops `d.essences_used()` and raises on any `c.essences.has(ess)`. No code change is needed there. The change takes effect by itself once `essences_used()` returns two elements.
- **What changes in discovery:**
  - A Cave Bat (air) at Appraisal 2 names Echolocation, Spore Cloud and Jolt.
  - Any water creature (toad, spider, snake, eels, jelly, crayfish, lizardman, taratect) names Hydraulic Propulsion and Poison Breath.
- **Spec 2 consequence:** it shows any node at Named or higher, so appraising the first bat in the Cave puts Jolt (a Flooded power) and Spore Cloud on the tree.
- **The opposite problem for thread:** Sticky Thread now has no elements, so no creature hints it at Appraisal 2. It is still named at Appraisal 3 through the spider's skill list.
- **Fix:** hint only when the creature carries every element of the recipe, or the rarest one. Add a hint rule for `family` unlocks.

### M7. Tests that will break and are not listed (spec 1, Testing)

Grepped for `affinity`, `FIRST_EVOLUTION_AREAS`, trait names and `.essences`:

- `tests/test_first_evolution_areas.gd:34,51,54` uses `FormOffers.FIRST_EVOLUTION_AREAS` and `FormOffers.supply`, both of which the spec removes, so the script will not parse. Its third test (Cave plus Grotto reach the stage-1 cap) is still worth keeping, so the constant needs a new home rather than deletion.
- `tests/test_rebirth_pool.gd:69,79,80`: affinity kits, and expects an "essence" validation error.
- `tests/test_rebirth_flow.gd:171`: `RebirthKit.apply` with `affinity`.
- `tests/test_room_edit_model.gd:19-27`, `tests/test_room_edit_fields.gd:73-79`, `tests/test_room_editor_scene.gd:350-370`: all assert that G1 ships an affinity and that it survives edits.
- `tests/test_deep_slice.gd:18`: Taratect `{"thread": 3, "poison": 2}`.
- `tests/test_pale_moth.gd:24`: `{"spore": 3, "flight": 2}`.
- `tests/test_web_tether.gd:152`: unlocks Sticky Thread by feeding `absorbed {"essence": "thread"}`, which must become a `predated {"family": "spider"}` event.
- `tests/test_skill_caps.gd:187-195`: reads `c.essences.get("sound")`, which needs to become air (see M3).
- `tests/test_rebirth_kit.gd:177-178,205-226`: `eligible_lineages` signature and seeds. This file is already listed, but the rewrite is total, not an "EP assertion".

### M8. Spec 2 names the wrong file for input bindings (spec 2, Zoom and pan; Engine changes)

- **The claim is false:** `project.godot` has no `[input]` section. All actions are registered at runtime from `autoload/controls.gd` (`KEYS` at lines 15-29, `PAD_BUTTONS` at 31-48, `PAD_AXES` at 54-61, `InputMap.add_action` at 185 and 210). The new zoom and pan actions belong there.
- **Triggers are not free:** both are already `active_3` and `active_4` (`controls.gd:59-60`). They are "free in a menu" only because the game is paused. Say that explicitly, and make sure the tree handler consumes the event.
- **No keyboard zoom keys are named.** Q and E are taken twice over (tabs and `active_3`/`active_4`, `controls.gd:20-25`).

### M9. Spec 2 tab change: layout arithmetic and unlisted tests (spec 2, Where)

- **The threshold moves with the list:** `tab_layout(n)` switches on `n <= TABS.size()` (`skill_screen.gd:130-131`). Adding `"tree"` to `TABS` moves the threshold to 6, so six tabs use the 102 stride: 28 + 5×102 + 96 = **634**. That overruns the right margin (five tabs end at 532 per `skill_screen.gd:10`).
- **Seven tabs at the existing six-tab layout:** 28 + 6×88 + 84 = **640**, flush with the screen edge.
- **What fits:** a symmetric 28 px margin needs 7s − 4 ≤ 584, so s ≤ 84 and w ≤ 80.
  - "COMPENDIUM" (10 glyphs at `FONT_MAIN` 10) must fit in 80 px.
  - HYPOTHESIS: this fits only if a glyph is 8 px wide or less. Check by screenshot.
- **Inserting Tree second shifts every hard-coded index.** Unlisted tests that need updating:
  - `test_skill_screen.gd:158-198`
  - `test_evolution_screen.gd:163-164`
  - `test_map.gd:55,75`
  - `test_audio_ui.gd:48-111` (including `assert_eq(SkillScreen.TABS.size(), 5)` at line 58)
  - `test_form_tab.gd:47-49` (`switch_tab(5)` for Form)
- **Spec 2 has no Testing line for these.**

### M10. The tree shows lineages the Form tab will not offer (cross-spec)

- **Two different sets:** spec 2 shows a stage-2 form when its lineage is "open this life". Spec 1's offers are the open lineages capped at `MAX_OFFERS = 3`. With five open lineages, which is likely on a full clear (M4), the tree advertises two forms the Form tab never offers.
- **The fallback goes missing:** Greater Slime has no powers, so it is never "open" and never appears until reached, yet the Form tab offers it whenever fewer than two lineages are open.
- **Fix:** have the tree show "offered" (call the same `FormOffers` function), not "open", for the next stage.

## MINOR

1. **Room editor (spec 1).** "The room editor's kit fields drop `affinity`" is inaccurate. The editor has no affinity field. `room_edit_model.gd:625` merges the kit so every other key (G1's affinity) survives, and `inspector_panel.gd:16` lists only level and skills. The change is a doc comment plus the three editor tests in M7.
2. **Controller claim (spec 1, Open Q4).** "A controller whose buttons are all taken in play" is false. L3 and R3 (`JOY_BUTTON_LEFT_STICK`, `JOY_BUTTON_RIGHT_STICK`) are unmapped (`controls.gd:31-48`), and Back is only `debug_input`. That weakens the reason for deferring the in-world prompt.
3. **No validation for `family` (spec 1).** `_check_event_ref` (`def_validator.gd:116-125`) validates only `source` and `essence` tags. A typo like `{"family": "spidr"}` makes Sticky Thread silently unreachable. Add a rule that every `family` an unlock names is carried by at least one `CreatureDef`, plus a test.
4. **Sticky Thread's unlock text (spec 1).** It will read "Eat creatures ×3", because `EVENT_TEXT["predated"]` at `skill_screen_model.gd:15` ignores tags. It needs a `family` branch in `_event_text` (`skill_screen_model.gd:178-183`).
5. **Mix wording (spec 1).** `conditions_text` joins one phrase per condition (`skill_screen_model.gd:168-176`), giving "Absorb water essence ×n and Absorb dark essence ×n". Getting "Absorb water and dark essence" needs a merge rule that the spec does not describe.
6. **Affordability has no signal (spec 1).** `evolution_ready` fires once (`skill_rules_engine.gd:247-250`). An evolution that becomes affordable later produces no event, so the persistent HUD indicator must re-poll `can_afford` on every `ABSORBED`. The pop-up at ready time will say "Evolution available" while the player cannot pay. Say which event drives the indicator, and test the unaffordable-to-affordable transition.
7. **Redundant data test (spec 1).** "Every creature's elements are in `Essences.ALL`" is already enforced by `DefValidator._check_creatures` (`def_validator.gd:175-177`). Keep only the table-match half.
8. **Calibration has no regression guard (spec 1).** The output is a committed doc. Pin the per-skill unlock points (±1 eat) in a test so later content edits can't silently move them.
9. **Kit grants have side effects (spec 1).** Open Q2 should note that granted actives go into slots (`rebirth_kit.gd:69-72`). D1 then holds three actives out of `SLOT_COUNT = 4` (`active_slots.gd:8`). D1 also goes from two eligible lineages (thread, water seeds) to three, because `tremor` now opens Bulwark. Spec 1 lists this; it is a behaviour change, not a like-for-like swap.
10. **Leftover EP comments to sweep (spec 1).** Code: `skill_rules_engine.gd:12,129,134`, `progression.gd:4-5,59,69`, `player.gd:549,593,644`, `rebirth_kit.gd:60`, `skill_screen.gd:159` (the doc comment above `accept`). Tests: `test_skill_rules_levels.gd:69` (comment), `test_rebirth_flow.gd:187` (message), `test_rebirth_kit.gd:3` (doc).
11. **Shared Profile instance (spec 2).** `FormLog` must use the one `Profile` in `autoload/compendium.gd:10`. `WorldProgress._save` and the Compendium both write through it. HYPOTHESIS: a second `Profile.new` on the same path would clobber sections on save. The spec also never says who calls `save()` after `reached` is written.
12. **Malformed-section claim (spec 2).** `dict_section` checks only the top-level type (`profile.gd:60-68`). A nested `{species: "x"}` or `{species: {form: 3}}` passes it, so `FormLog` needs its own inner validation. "As Profile already does" overstates what exists. Profile JSON is user-editable, but it reaches no shell or eval, so this is robustness, not security.
13. **Missing node states (spec 2).** There is no state for a Named-but-locked power (the common case) or for a ready-but-unaffordable evolution. Spec 1 has the latter ("Ready — needs 2 more dark"), so the two specs should agree.
14. **Layout size (spec 2).** At normal zoom with 8 px labels (about 16 px per row), the power band is about 19 to 23 rows (two-branch powers need two rows), roughly 300 to 370 px. The form band (stage 3 has two children per lineage) is about 11 to 12 rows, roughly 190 px. The graph box height is at most about 274 px (`LIST_TOP` 46 to `LIST_BOTTOM` 320). The legibility bar checks overlap and truncation but never whether an "opens" edge and both of its endpoints fit on one screen. HYPOTHESIS: they don't, so the tree's main new information needs panning.

## Test coverage gaps

These behaviours have no proposed test:

- Spore Cloud or any other recipe becoming satisfiable from an earlier area (M1).
- Unlock points for rebirth-start lives (M2).
- Level-by-area for `absorbed`-levelled skills (M3).
- Offer balance under realistic ledgers (M4).
- Price binding: at least one evolution unaffordable at its ready moment for a full-clear ledger (M5).
- The hint scope rule (M6).
- A validator rule for unknown `family` (minor 3).
- The HUD indicator turning on from an `ABSORBED` event alone (minor 6).
- Seven-tab layout bounds expressed as numbers, not only "lay out inside the strip" (M9).
- Tree offers matching the Form tab's offers (M10).

## Security

There is no path from user input to a shell, query, template or eval. The calibration script and the content builders read shipped data, and `FormLog` reads the user's profile JSON as data only. See minor 12 for its robustness.

VERDICT: REVISE — concerns above should be addressed first
