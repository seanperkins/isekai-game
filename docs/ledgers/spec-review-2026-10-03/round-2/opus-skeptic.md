# Opus Skeptic: re-review of the revised Essence Overhaul and Skill Tree Screen specs (round 2)

I checked the revised plan against the repo on `docs/design-direction`. Every file:line below comes from a read or grep in this session. Spawn counts are the same as in round 1 (Cave: bat 6, toad 5, lizard 4, spider 5, pool 2; Grotto: spore_moth 10, crab 12, vine_snake 6, pale_moth 1; Flooded: glass_eel 8, jelly 5, crayfish 5, lizardman 6, storm_eel 1; Deep: ant 9, wolf 9, drake 3, taratect 1).

## Round-1 concerns: what the revision fixed

| Round 1 | Status | Evidence |
|---|---|---|
| M1 Spore Cloud farmable in the Cave | Fixed. It is now Open Q5 | |
| M2 Rebirth-start lives | Partly fixed. The walks are added, but see N1: three moves are forced, and the spec could state them now | |
| M3 Echolocation level rate | Fixed. Area-end levels are printed and pinned | `level_curve: 3` on air confirmed at `tools/build_content.gd:104` |
| M4 Ranking bias | Fixed. The ranking and the cap are removed. N2 covers what follows from that | |
| M5 Price numbers | Fixed | Arithmetic checked: 6+10+12+14; dark sum 36 > 29 for Cave and Grotto, and > 31 for a full four-area clear (taratect +2, the Flooded 0) |
| M6 Hint flood | Fixed. Every-element or family | Today's any-element loop confirmed at `compendium_model.gd:162-166` |
| M7 Unlisted tests | Mostly fixed. N4 and N7 list the misses | |
| M8 Input file | Fixed | `BINDINGS`, `PAD_BUTTONS`, `PAD_AXES` and `ensure_actions` all exist (`autoload/controls.gd:7,31,54,182`). The stick clicks are absent from `PAD_BUTTONS` (`controls.gd:31-48`) |
| M9 Tab arithmetic | Mostly fixed. N5 is the six-tab case | |
| M10 Tree vs offers | First half fixed: no cap, so open equals offered. Second half (Greater Slime) not fixed, see N3 | |

Minors 1-9, 11, 12, 13 and 14 are addressed. I confirmed each claim below:

- `room_edit_model.gd:625` comment.
- `skill_screen_model.gd:177` `_event_text`.
- `def_validator.gd:116-125` `_check_event_ref`.
- `profile.gd:49-57` `list_section`, which checks that every element is a string, warns and drops a bad section.
- `game.gd:55` editor Play gets `WorldProgress.new()`.
- `event_bus.gd:5` world_event is "audio-only … Never counted".
- `player.gd:596` `advance_form`.
- `skill_screen.gd` is 789 lines.
- `_armed` is reset in `close()` (`skill_screen.gd:107-108`).
- `hud.gd:96` sets `_evolve.text = evolve_text()` in `_process`.
- `test_content.gd:54` `test_essence_minimums_satisfy_every_essence_skill`.

Minor 10 (the EP sweep) is still incomplete; see N6.

---

## CRITICAL

None.

## MAJOR

### N1. The calibration's "within one eat" target is provably unmeetable for three powers. The spec could name the forced moves now (spec 1, Calibration)

The Cave-start point pins each threshold low. Each element's supply in a later area then meets that threshold an area or two early, or never.

**Echolocation.**
- On a Cave start it must stay at about air 6 (the 3rd bat, ±1 eat: 4 to 8).
- G1 life: the Grotto gives 10 moths × 2 = 20 air, so it unlocks at the 3rd moth. Today's G1 life has no sound until the Deep's wolves (sound 3 at the 3rd wolf). It moves **Deep → Grotto**.
- F1 life: eels and jellies give 16 air. It moves **Deep → Flooded**.
- No threshold in 4 to 8 avoids this.

**Body Armor.**
- On a Cave start it must stay at about earth 6 (today armor 3 is the 3rd lizard, `build_content.gd:116`).
- G1 life: the Grotto gives 36 earth, so it unlocks at the 2nd crab. Today armor exists only on lizards, ants and drakes, so a G1 life gets it in the Deep. It moves **Deep → Grotto**.
- F1 life: the Flooded gives 11 earth ≥ 6. It moves **Deep → Flooded**.

**Tremor.**
- Today it needs earth 24 (`build_content.gd:163`) and unlocks at the 2nd ant on a Cave start.
- Holding that point needs 8 + 36 + 11 + 4 = **59**.
- But an F1 one-pass life holds only 11 + 39 = **50**. So does the pinned minimums test: 3 lizards × 2 + 2 crabs × 3 + 9 wolves + 9 ants × 2 + 3 drakes × 4 = 6 + 6 + 9 + 18 + 12 = **51**, while `test_content.gd:55-69` asserts that the totals meet every `absorbed` threshold.
- So the threshold has a hard ceiling of 50 if F1 must stay reachable. At 50, a Cave start meets it in the Flooded: 44 + 6 = 50, at the 6th earth eat there. That moves **D1 → Flooded**, a whole area early.

**Fix.** List these as the deliberate moves in the spec now, so Sean decides on them instead of meeting them in the script's output. The forced moves are:

- Echolocation for G1 and F1.
- Body Armor for G1 and F1.
- Tremor ≤ 50, with its Cave-start point moving into the Flooded.

Alternatively, keep a separate rule for the earth trio. Also note that `test_essence_minimums_satisfy_every_essence_skill` puts its own ceiling of 51 on Tremor.

### N2. With no cap, a full Cave clear opens all five lineages, so the first evolution is the same five-way offer for nearly everyone (spec 1, Forms)

Each opening power unlocks inside the Cave at the thresholds that hold today's points:

| Power | Lineage | Unlocks at | Cave supply |
|---|---|---|---|
| Echolocation | Echo | air 6, the 3rd bat | 6 bats × 2 = 12 |
| Hydraulic Propulsion | Tide | water 8, the 4th toad | water 10 + 5 + 4 |
| Poison Breath | Toxic | dark 4, the 4th toad | dark 10 |
| Body Armor | Bulwark | earth 6, the 3rd lizard | earth 8 |
| Sticky Thread | Weaver | the 3rd spider | 5 spiders |

The stage-1 cap is reached only after the Cave and the Grotto (`form_offers.gd:11-13`, `test_first_evolution_areas`). So any player who clears the Cave is offered all five lineages, and the Greater Slime fallback (`< 2`, `form_offers.gd:92`) appears only for a player who skipped most of the Cave. Today's offers are 0 to 3 lineages gated at ≥ 60% of supply (`form_offers.gd:8-9,85-91`), which vary by play.

This may be what the design doc intends ("sees every evolution … possible"). But the spec's own success line says "a life plays as it does today", and nowhere states that the offer becomes constant.

**Fix.** Say it explicitly, either in the Forms decision or as an Open-for-Sean item, so that dropping the ranking is a choice made knowing that it makes the offer the same five every time. Also, "The Form tab holds five lineage rows and the fallback" describes a combination that cannot happen: the fallback is added only when fewer than two lineages are open, so the maximum is 5 rows, not 6.

### N3. Greater Slime's lineage (four forms) has no visibility rule on the tree (spec 2, Growing; round-1 M10 second half)

- Spec 2 shows a stage-2 form "whenever any power that opens it is shown".
- `greater_slime` lists no powers: it is excluded from `lineage_essences` (`form_offers.gd:31`) and is not in the spec-1 lineage table. So it is never shown unless reached, and the rules for stage 2 only cover named-vs-stub for shown forms.
- Its children and sovereign are stubs "once the parent is named". The parent never is, so they never appear.
- Meanwhile the Form tab offers it whenever fewer than two lineages are open, and the slime → each stage-2 form edge is declared.

The model test "every form appears as a node when fully discovered" is undefined for it.

**Fix.** Add a rule, for example: Greater Slime is shown and named when reached or currently offered (`open_lineages(...).size() < 2`), and is otherwise a stub always present under the slime.

### N4. `ESSENCE_SPENT` cannot be added to `Events` without breaking three pinned tests, and putting it in `INTERNAL` silently breaks `held` (spec 1, Eaten and held; Engine changes)

- `SkillRulesEngine._drain` records into the ledger only `if not Events.INTERNAL.has(ev)` (`skill_rules_engine.gd:234-235`). So `ESSENCE_SPENT` must not be internal, or `held` never decreases.
- If it goes into `Events.ALL`:
  - `tests/test_constants.gd:11-18` pins `Events.ALL` to exactly 14 names (`assert_eq(Events.ALL.size(), expected.size())`).
  - `tests/test_audio_catalog.gd:106-109` requires a `data/audio/cues.json` `events` entry for every name in `Events.ALL`.
  - `def_validator.gd:116-121` would then let any skill **count** `essence_spent`.
- None of these surfaces is in the spec's test lists or file list.

**Fix.** State whether `evolve()` records through the queue (then it needs `Events.ALL` membership, a cues.json entry, and the `test_constants` update) or calls `_ledger.record` directly (then the name is a ledger-only constant outside `Events.ALL`). Also say whether it is emitted on `EventBus.game_event`. The Compendium and Audio both listen there (`autoload/compendium.gd:13`, `autoload/audio.gd:51`).

## MINOR

1. **Six-tab strip has no stated layout or test (spec 2, Where).**
   - The Form tab is appended only when `form.stage > 1 or can_evolve()` (`skill_screen.gd:120-127`), so the common stage-1 strip is six tabs, not seven.
   - The spec shows the six-tab overflow (634) but gives numbers and a test only for seven: `7s − 4 ≤ 584`.
   - Either use the seven-tab layout for both counts, or give six its own bound: 6s − 4 ≤ 584, so s ≤ 98, w ≤ 94, ending at 28 + 5·98 + 94 = 612.
   - Add "the six-tab strip ends at or before x = 612" to the Screen tests.
2. **Pad-only actions are skipped by `ensure_actions` (spec 2, Input).** `ensure_actions` iterates `BINDINGS` and reads `PAD_BUTTONS.get(action)` inside that loop (`controls.gd:183-190`). A zoom action with only a stick click and no key would never be registered. The spec gives both a key and a stick click, which is fine. State the constraint so a plan doesn't drop the key.
3. **Keyboard keys taken, listed incompletely (spec 2, Input).** Besides those named, these are taken: J and Shift, K and F, I and R, U, O, H, L, F3, F11 (`controls.gd:15-26`). Minus and equals are indeed unbound.
4. **Hint-rule side effects not listed (spec 1, Display).**
   - Under "every element", a Vine Snake (water 1, dark 1, no family) stops hinting Sticky Thread. Today its thread 1 hints it (`compendium_model.gd:162-166`).
   - A Black Spider newly hints Poison Breath and Hydraulic Propulsion.
   - Fine, but record it, and add "a vine snake does not name Sticky Thread" to the hint test.
5. **`family` reaches only one of two `PREDATED` tag dicts (spec 1, Thread).** `_complete_predation` builds the tags twice: `_emit.call(Events.PREDATED, {...})` at `player.gd:812` and `skillset.heal_on(Events.PREDATED, {...})` at `player.gd:818`. Add `family` to both, or build the dict once, so a future `heal_on` keyed on family works.
6. **EP sweep still incomplete (spec 1, EP; round-1 minor 10).** "The EP wording in skill_screen.gd (the card and the hint)" misses several surfaces:
   - The stats column `"Lv %d    EP %d"` (`skill_screen.gd:382`).
   - Both list-row labels `"EVOLVE %d EP"` (`skill_screen.gd:205` and `:439`).
   - The affordability check in `accept` (`skill_screen.gd:172`, `progression.ep >= evolution_cost`).
   - The `seeded` doc comment (`progression.gd:24`).
   - The `rebirth_kit.gd:48` comment about seeded affinity.
7. **Tools that feed `thread` essence are missing (spec 1, Engine changes).** Only `tools/evolution_shots.gd` is listed. `tools/aim_shots.gd:41` and `tools/vfx_shots.gd:34` also unlock Sticky Thread with `absorbed {"essence": "thread"}`, and would silently stop granting it. The grep checklist should catch them, but the file list should name them.
8. **The minimums test goes blind to Sticky Thread (spec 1, Testing).** `test_essence_minimums_satisfy_every_essence_skill` checks only `absorbed` conditions (`test_content.gd:68`). Once Sticky Thread unlocks on `predated {"family": "spider"}`, its reachability (3 spiders among the minimums) is untested. Add a family branch that counts minimum spawns per family.
9. **Thread price exceeds the Cave's whole dark supply (spec 1, Price).**
   - Sticky Thread is ready at level 3 (`build_content.gd:175`, curve 8: 16 casts), plausibly inside the Cave.
   - The Cave holds dark 10 (toads 5, spiders 5), so dark 14 cannot be paid until about 4 dark from the Grotto.
   - Hydraulic (water 6 against Cave water 19) can be paid in the Cave.
   - That asymmetry may be intended. State it against "a full clear affords any one family at its ready moment", because for Weaver "ready" can come before the Grotto.
10. **Per-frame affordability poll (spec 1, Evolving). HYPOTHESIS, unmeasured.**
    - `Ledger.counter` is a linear scan (`ledger.gd:12-17`; its doc says "a few thousand events").
    - `held(e)` is two scans: `ABSORBED` and `ESSENCE_SPENT`.
    - Per frame: up to 4 ready parents × 2 elements × 2 scans × ~3000 entries ≈ 48k `_matches` calls, which is about 2.9M per second at 60 fps in GDScript.
    - Measure it, or recompute only when the ledger grows (cache keyed on the log size).
11. **Secret-slot rationale overstated (spec 2, Growing).** "The Skills screen already keeps secrets out of every `???` teaser" is true of the Skills rows (`skill_screen_model.gd:19-22`). The Compendium tab's `compendium_rows` does not filter `secret` (`skill_screen_model.gd:55-75`), so Glutton already shows as a `???` row there. The tree rule is still reasonable. The claim that an empty slot "would reveal one" is weaker than stated, given the Compendium already does.
12. **Retained-view rationale (spec 2, Rendering).** The stated reason ("pan and zoom state must survive a selection change") conflicts with "no free pan; the camera follows the selection". The camera is derived from the selection, so only the zoom level (one int) needs to survive, and that can live on the screen across a rebuild like the Map tab does. The separate retained `SkillTreeView` may still be right for line-count reasons, but the justification as written does not hold.

## Test coverage gaps (new or still open)

- The forced rebirth-start moves for Echolocation, Body Armor and Tremor, as pinned values (N1).
- That a full Cave clear opens all five lineages, if accepted (N2).
- Greater Slime and its line on the tree (N3).
- `Events.ALL` and cues.json for `ESSENCE_SPENT`, and that `held` actually decreases through the engine path (N4).
- The six-tab strip bound (minor 1).
- The Sticky Thread family-minimum reachability (minor 8).
- The Vine Snake losing the Sticky Thread hint (minor 4).

## Security

No change from round 1. `forms_reached` is read through `Profile.list_section`, which type-checks every element as a string (`profile.gd:53`). No profile or content string reaches a shell, query, template or eval.

VERDICT: REVISE — concerns above should be addressed first
