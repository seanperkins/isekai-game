# The Simplifier, round 2: revised essence overhaul + skill tree screen specs

Lens: Ousterhout (deep modules, accidental complexity, pass-through, YAGNI, complexity budget).
Every `file:line` below came from a tool result in this session (repo root /Users/sean/sites/isekai-game).

## One-paragraph take

The revision took the round-1 feedback seriously and the plan is materially smaller and better grounded. All five of my round-1
MAJOR deletions on Spec 1 landed (ranking and cap gone, kit invariant gone, price on the parent, HUD folded into one label, the three
non-changes removed), and Spec 2 dropped the mouse, free pan, the third zoom level, the second evolve entry point, the species-keyed
`FormLog` and the audio-bus trigger, and fixed the input file. What is left is plan-time polish plus a handful of new claims
the revision introduced that are wrong or unsupported (below). None blocks implementation planning; most are one-sentence fixes.

## Round-1 concerns: status

| R1 | Status |
|---|---|
| F1 ranking + 3-offer cap | Fixed: no ranking, no cap, public `open_lineages` |
| F2 two-lineage kit invariant | Fixed: kits lose `affinity`, gain nothing (recommended; Q2 keeps the alternatives) |
| F3 spec 1 / spec 2 disagree on "open" | Fixed: both read `FormOffers.open_lineages` |
| F4 `family` wording / hint / validator | Addressed (wording branch, hint rule, validator rule). See N8 on whether `family` is worth it |
| F5 Echolocation leveling | Fixed: area-end levels pinned in `tests/test_content.gd` |
| F6 three non-changes | Fixed: removed |
| F7 incomplete test list | Fixed: grep-derived checklist; I re-grepped the EP and `affinity`/`seeded`/`MAX_OFFERS` sets and every file is in the lists |
| F8 price on the parent | Fixed (the "empty price is free" test special case survives, see N9) |
| F9 duplicate HUD indicator | Fixed: second line on `_evolve` |
| F10 sequencing | Fixed for Spec 1 (three steps); Spec 2 has none, see N6 |
| S1 wrong input file | Fixed: `autoload/controls.gd` |
| S2 tab-index churn | Fixed: test list and strip arithmetic stated |
| S3 graph sized for absent structure | Partly: grid packing added; canvas kept (design call, accepted) |
| S4 pan/zoom/mouse invented | Fixed: two levels, selection-follow, no mouse, no free pan |
| S5 forms band on unresolved reading | Partly: persistence shrank to a list and a signal; band still built before Q1 is answered, see N6 |
| S6 audio-bus trigger | Fixed: `Player.form_advanced` signal |
| S7 second evolve entry | Fixed: read-only v1 |
| S8 secrets leak through layout | Fixed: excluded from layout |
| S9 grounding gaps | Fixed: `SkillTreeView`, `form_card` extraction, mix wording rule |

## Citations re-checked (held)

- `Essences.ALL` ten trait names; `Ledger` superset-tag counter, linear scan (`scripts/skills/ledger.gd:5` says "Linear scans are fine at prototype scale"); `Ledger.clear()` via `reset_run()` (`skill_rules_engine.gd:71`), so a held projection from the ledger does reset with the run.
- `SkillRulesEngine.evolve` / `evolution_cost` (`skill_rules_engine.gd:136`, `:130`); `level_of` counts a retired parent (`_owned` keeps it; `is_retired` only checks owned children), so `open_lineages` via `level_of(id) > 0` is right.
- `Player._complete_predation` emits `PREDATED {"source","kind"}` then one `ABSORBED` per unit over `Essences.ALL` (`player.gd:807-812`); `try_evolve` EP check (`player.gd:550-557`); `form_offers()` (`player.gd:561`); `advance_form` is the only body-evolution success path (`player.gd:596`; the only other callers are `skill_screen.gd:163` and two shot tools).
- `hud.gd:96` sets `_evolve.text = evolve_text()` every frame; `level_text` carries EP (`hud.gd:225-229`); `core_wiring.gd:23` announcer EP text; `rebirth_kit.gd` `ESSENCES`, `eligible_lineages`, `apply` seeding.
- The numbers: I recomputed from `data/rooms/*.tres` spawns. Cave dark 10 (5 toads + 5 spiders), Grotto 10 moths + 6 snakes + 1 pale moth = 10 + 6 + 3, total 29, and the Flooded and Deep add only the one Taratect (2), so the full-game dark is 31 against prices summing to 36. Earth new-to-old: Cave+Grotto 44/16 = 2.75, Deep 39/27 = 1.44. Echolocation air on Cave+Grotto is 37 (level 13 against a stage cap of 5). All the spec's figures are correct.
- Spec 2: `TABS` has five entries and `TAB_STRIDE_SIX` 88/84 is used for the Form tab case (`skill_screen.gd:8,12-15,130-131`); six tabs at 102/96 end at 28 + 5*102 + 96 = 634 (spec correct), seven at 84/80 end at 612 (correct). Stick clicks are unmapped (no `JOY_BUTTON_*_STICK` anywhere); Q/E, W/A/S/D, arrows, Enter, Space, Backspace, Esc are all bound (`controls.gd:9-30`). `list_section` validates strings and warns (`profile.gd:49-57`). Editor Play builds a fresh `WorldProgress.new()` with no profile (`game.gd:55`). `Profile.save` warns on failed writes. No mouse handling under `scripts/ui`. All test files named in both specs exist, and the index-shift tests are the ones that call `switch_tab` with literals (`test_audio_ui`, `test_map`, `test_form_tab`, `test_evolution_screen`, `test_skill_screen`, `tools/evolution_shots.gd:38`).

No fabricated identifiers found.

---

## NEW findings

### N1 [MINOR] The reason for a retained `SkillTreeView` is voided by the spec's own "no free pan"

The Rendering section justifies a retained view because "pan and zoom state must survive a selection change, which a rebuild would
reset". But Decisions now say the camera **follows the selection**, with no free pan and no mouse. Then camera position is a pure
function of (selected node position, zoom level). Nothing needs to survive a rebuild except the selected id and one zoom int,
which can sit on `SkillScreen` next to `_sel`/`_scroll` (`switch_tab` already resets them). The Map tab idiom (rebuild into a box on
`_refresh`, ~52 panels at most) then works and the view becomes a builder function, not a node with its own camera, clipped
viewport, world node, and input forwarding. Keep the separate file for the size reason (789 lines in `skill_screen.gd`), keep a small
`_draw` helper for edges (needed either way), but drop the retained-state design and its stated rationale. If smooth camera motion is
the real reason, say that instead.

### N2 [MINOR] "left stick moves the selection" is not what the screen's stick path does

Spec 2 says the direction keys, left stick or D-pad move the selection. Today `nav_step(stick_y, delta)` takes the **y axis only**
(`skill_screen.gd:218`), `_process` passes only `Controls.last_stick.y` (`:237-243`), and `_unhandled_input` swallows every
`InputEventJoypadMotion` at `:254-255`, so stick-X never reaches `move_left`/`adjust`. A 2D tree needs a two-axis step (or the
D-pad only). The D-pad works unchanged (button events). This changes `nav_step`'s signature, which `tests/test_menu_input.gd:62-64`
pins, and neither the Engine-changes list nor the changed-tests list mentions it. Either say "D-pad and keys in v1, stick in
a follow-up" (simplest, the D-pad already covers pad users) or add the `nav_step` generalization and `test_menu_input` to the lists.

### N3 [MINOR] Two zoom levels do not need two actions (nor a clamp test)

With exactly two levels, "two zoom actions step the level" plus the test "zoom clamps at both ends" is a pair of bindings, a pair of
stick clicks, and a clamp, to do what one toggle does. One `tree_zoom` action (one key, one stick click, press to flip) removes
a binding, a hint-line entry, the clamp logic and its test. Add the second action when a third level exists.

### N4 [MINOR] The tab-strip fix covers only the seven-tab case, and the threshold becomes dead code

Adding `tree` makes `TABS.size()` six, so `tab_layout`'s `n <= TABS.size()` branch (`skill_screen.gd:130-131`) now owns the six-tab
strip, which is the **common** state (the Form tab is appended only at the level cap or after a body evolution, `:121-125,
:127-128`). The spec identifies that six tabs would end at x = 634 but states the numbers and the test only for seven. Since base tabs
can no longer drop below six, the two-stride switch has no remaining job: one constant stride and width of 84 and 80 serves both
(six end at 528, seven at 612, inside the 28 to 612 margin), and `TAB_STRIDE_SIX`, `TAB_W_SIX` and the branch go. Then the test is
"every strip size we can reach ends at or before 612", not one case.

### N5 [MINOR] `forms_focus` is a speculative branch with its own tests

"Off unless the screenshot check requires it" means it is built, tested (edge pruning, "every edge endpoint visible with and without
`forms_focus`", "keeps the current form, its parents and its next stage only") and probably never shipped on. Defer it: if the
`tools/tree_shots.gd` check fails, add it then, with the same pruning rule that the spec already states clearly. As a conditional
step 2b of the plan it costs nothing now.

### N6 [MINOR] Spec 2 has no sequencing, and Open Q1 still gates a third of it

Spec 1 got a three-step sequence "so the plan can stop or reorder". Spec 2 has the same shape and the same open question: Q1 says
that if "evolutions" means power branches only, the lower band, `forms_reached`, `form_advanced`, the form edges (and in effect
`form_card`, `forms_focus`, the form states `current`/`reached` and the `FormOffers.open_lineages` dependency) are dropped. Write that
as the plan order: (1) power graph (model, view, tab, controls, shots), then (2) forms band (persistence signal, `form_card`,
stage-2 "opens" edges, form stubs). Sean's answer to Q1 then deletes step 2 and nothing is wasted. Zero design cost; it also
lets Spec 2's first step start without Spec 1's step 1.

### N7 [MINOR] The calibration criterion cannot be met for Spore Cloud, and Open Q5 states only one of the two costs

Success says each power unlocks "within one eat of where it does now ... on each rebirth start, or the move recorded as deliberate".
For Spore Cloud (today `spore` 4, `build_content.gd:140`) no threshold pair satisfies both life kinds. Cave alone holds air 12 and
dark 10 (6 bats at air 2; 5 toads and 5 spiders at dark 1), so any recipe with dark at most 10 and air at most 12 unlocks in the Cave.
To keep the Grotto's 4th moth on a Cave-start walk, dark must be 11 to 14 (or air 13 to 20). From a G1 start the 4th moth gives only
dark 4, so any such threshold moves G1's unlock from the 4th moth to the 11th eat or later. Q5 presents only the Cave-reachability
cost ("accept it, or let earth join"). State both, and then relax the rule up front instead of discovering the deliberate move in the
script: keep "within one eat" for the **Cave-start full clear** (the pinned numbers) and make the rebirth-start criterion
**reachability** (every power obtainable from each start, or listed as not). That halves the constraint set the one-off script and the
pinned test must carry; Tremor from F1 (Flooded 11 + Deep 39 = 50 earth against a Cave-start-calibrated threshold near 55) is the
same conflict, which the spec already notices.

### N8 [MINOR] `family` buys one creature; `source` is already validated and needs no new field

Today's `_check_event_ref` already rejects an unknown `source` tag (`def_validator.gd:116-125`), and `PREDATED` already carries
`source` (`player.gd:812`). Sticky Thread could unlock on `predated {"source": "spider"} x3` with no new field. That deletes
`CreatureDef.family`, the `PREDATED` tag addition, `SkillDef.families_used()`, the new validator rule, the build_content
data, and the three test items for them. The wording branch and a (simpler) hint rule are needed either way. The cost is that the
Taratect no longer counts, but `family` only buys the Taratect **once**: there is exactly one in the Deep (my spawn count over
`data/rooms`), and from an F1 or D1 start three spider-family eats are unreachable either way without farming. If more spider kin are
planned (the spider species spec), keep `family` then; today it is six touch points to count a single boss. The spec already
says "the Taratect now counts once ... accepted", so the trade is stated, not hidden.

### N9 [MINOR] "An empty price is free" is still a production branch that exists for one test

Round 1 F8 asked for this to go; the revision kept it so `test_evolution_branches` keeps working. The validator already requires a
non-empty price on every shipped base power, so the engine's empty-is-free path is reachable only from hand-built test defs. One
fixture line in that test (give its parent a price) removes the branch and lets `evolve()` assume a price. Given that about 40
test files are being rewritten anyway, this is cheap.

### N10 [MINOR] "Polled every frame, no new signal" hides a linear ledger scan

`hud.gd:96` recomputes `evolve_text()` each frame, and `held` is `count(ABSORBED) - count(ESSENCE_SPENT)`, each a linear scan of a log
that `ledger.gd:5` itself bounds to "a few thousand events" (and `damaged`, `skill_used` and `submerged` all log). While an evolution
is ready but unaffordable (possibly most of a life), the HUD runs about (ready siblings x price elements x 2) scans per frame. Probably
around a millisecond, so not a blocker, but the spec presents it as free. Cheap fixes: price is on the parent, so ask once per parent,
not per sibling; or have `can_afford` memoize on ledger size. Say which, or note the cost and defer.

### N11 [MINOR] `ESSENCE_SPENT` must not be added to `Events.INTERNAL`

`_drain` records every event except `INTERNAL` ones (`skill_rules_engine.gd` `_drain`: `if not Events.INTERNAL.has(ev): _ledger.record`), and
`DefValidator._check_event_ref` rejects counting an INTERNAL event. The spec only says "`events.gd`: `ESSENCE_SPENT`"; add "in `ALL`,
not `INTERNAL`" so the first implementer does not copy `SKILL_UNLOCKED`'s shape. (`MANA_SPENT`, `events.gd:17`, is the precedent: one
per unit, counted.)

---

## The one proposal (delete this / merge these)

1. **Spec 2: make the camera a function, not state.** Delete the retained world and camera node and the "pan and zoom survive"
   rationale (N1); one `tree_zoom` toggle instead of two actions and a clamp (N3); one constant tab stride of 84/80 instead of two
   strides and a threshold (N4). Net: a builder function plus one `_draw` helper, one new action, no `tab_layout` branch.
2. **Spec 2: sequence it** into the power graph and then the forms band (`forms_reached`, `form_advanced`, `form_card`, "opens" edges,
   and `forms_focus` only if the shot fails), so Q1 gates the second step only (N5, N6).
3. **Spec 1: unlock Sticky Thread on `source: "spider"`** and drop `family` unless the spider species is imminent (N8); fix the
   test defs instead of keeping an empty-price-is-free engine branch (N9).
4. **Spec 1: relax the rebirth-start calibration to reachability** and state both costs of Q5 (N7).

None of these is a redesign; each is a deletion of something the revision added, or a sentence the plan will otherwise have to
discover.

## Complexity budget

Spec 1 is now justified: the deletions (supply, affinity, seeded, ranking, `eligible_lineages`, EP) outweigh the additions (held
projection, price, `family`, one event), and the held projection from one log is the right shape. Spec 2 is a real feature at a fair
price once N1, N3, N4 and N6 are applied; the residual cost (a canvas where a list would do) is the design call the spec makes
openly and the doc supports ("node graph", "zoomable").

VERDICT: APPROVED — plan is solid and ready to implement
