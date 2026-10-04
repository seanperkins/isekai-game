# Opus Skeptic: verification of the round-2 edits

Checked against the repo on `docs/design-direction`. Every file:line below comes from a read or grep in this session.

## Round-2 concerns: status

| Round 2 | Status | Evidence |
|---|---|---|
| N1 forced calibration moves | Resolved as written. Echolocation and Body Armor (G1, F1) and Tremor (cap 50, Cave-start point moves into the Flooded) are listed. The ratios check out: Cave+Grotto old earth 4+12=16, new 8+36=44, 44/16 = 2.75; Deep old 9+9+9=27, new 9+18+12=39, 39/27 = 1.44. But see NEW-1: the reachability model behind the Tremor cap now contradicts Sticky Thread | |
| N2 constant five-way offer | Resolved: Open Q6, and "at most five rows" | |
| N3 Greater Slime | Resolved: named when reached or offered, otherwise a stub under the slime; children follow the stage-3/4 rule; a model test is added | |
| N4 `essence_spent` | Resolved. It is written with `_ledger.record` directly, outside `Events.ALL` and `INTERNAL`. `_drain` records only non-internal queued events (`skill_rules_engine.gd:234-235`), so this bypass is the only way that works. `test_audio_boundary.gd:52-58` scans only `_emit(`/`world_event.emit(` literals, so a direct ledger write does not trip it. `test_constants.gd:15` and `test_audio_catalog.gd:108` stay untouched | |
| Minor 1 six-tab strip | Resolved. One stride/width: six tabs end at 28 + 5·84 + 80 = 528, seven at 28 + 6·84 + 80 = 612. `TAB_X = 28` (`skill_screen.gd:11`); the branch to delete is `skill_screen.gd:130-131`. Note: today's six-tab width is 84 (`TAB_W_SIX`, `skill_screen.gd:15`), and 80 is narrower. The plan rightly leaves "COMPENDIUM" to a screenshot | |
| Minor 2 pad-only action | Resolved: a key is required, and there is a test | |
| Minor 3 key list | Resolved | |
| Minor 4 hint side effects | Resolved, with a test | |
| Minor 5 `family` in two PREDATED dicts | Moot. `family` is dropped. `source` is already in both dicts (`player.gd:812`, `:818`) | |
| Minor 6 EP sweep | Resolved | |
| Minor 7 tools | Resolved (`aim_shots`, `vfx_shots` listed) | |
| Minor 8 minimums blind spot | Resolved: a source branch, and the minimums already hold `"spider": 3` (`test_content.gd:58`) | |
| Minor 9 thread price vs Cave dark | Acceptable. The target is now Cave+Grotto: dark 10+10+6+3 = 29, max single price 14 ≤ 29, all three 36 > 29. Any two are affordable (22, 24, 26 ≤ 29). That fits "one … but not all three" | |
| Minor 10 per-frame poll | Addressed by a memo, but see NEW-2 | |
| Minor 11, 12 | Resolved (secret rationale corrected; the retained view was replaced by a builder, with the camera as a pure function) | |

Citations re-grounded: `Sources.ALL` includes `SPIDER` and `TARATECT` (`scripts/core/sources.gd:25`). `_check_event_ref` rejects an unknown `source` (`def_validator.gd:123-124`). The Ledger uses superset tag matching (`ledger.gd:3-4`). `predated` maps to "Eat creatures" (`skill_screen_model.gd:15`), and `_event_text` is at `:177`. `nav_step(stick_y, delta)` is at `skill_screen.gd:218`, `_process` passes `Controls.last_stick.y` (`:241`), the joypad motion handler is at `:254`, and the y-only signature is pinned by `test_menu_input.gd:62-69`. The skill counts hold: 10 essence + 9 proficiency = 19 base, plus 8 evolutions = 27, and the eleven edgeless powers named are exactly the 19 minus the 8 lineage powers.

## CRITICAL

None.

## MAJOR

### NEW-1. The `source: spider` unlock makes Sticky Thread unreachable from every rebirth start under the plan's own reachability model, and the plan does not list it (spec 1, Thread and Calibration)

- Today Sticky Thread needs `absorbed 3 {"essence": "thread"}` (`build_content.gd:122`). Thread comes from the Vine Snake (thread 1, `build_content.gd:271`; 6 in the Grotto) and the Taratect (thread 3, `build_content.gd:301`; 1 in the Deep).
  - A G1 one-pass life reaches it at the 3rd vine snake.
  - An F1 or D1 life reaches it with one Taratect eat (3 ≥ 3).
- Under the edit, only `{"source": "spider"}` counts, and the plan says "The Taratect and the Vine Snake do not … count toward Sticky Thread". Black Spiders exist only in the Cave.
- Tremor's cap of 50 uses a **one-pass** model: "an F1 one-pass life holds only 50" = Flooded 11 + Deep 39. Under that model, G1, F1 and D1 never meet a Black Spider, so Sticky Thread (and with it the Weaver lineage's only opening power) becomes **unobtainable from all three rebirth starts**. Today all three can obtain it.
- The priority rule says rebirth starts must reach every power "or be listed as not". It is not listed.
- If the plan instead means a life may walk back (G1's exit goes to `C5`, `data/rooms/G1.tres:98`), then Sticky Thread is reachable. But then the F1 one-pass argument for Tremor ≤ 50 falls, and the only remaining ceiling is the minimums test's 51.

**Fix.** Define "reachable" once: one-pass forward, or any walk without farming respawns. Then do one of the following:
- list Sticky Thread as unreachable from G1/F1/D1 (and record that the Weaver lineage cannot open there);
- also count `{"source": "taratect"}` (one more condition would need the OR the engine lacks, so it would have to be a second unlock route or a lower combined rule);
- or re-derive the Tremor cap under the walk-back model.

Also add rebirth-start reachability for Sticky Thread to the pinned tests. "Rebirth-start reachability for every power" is listed, but under one-pass it would fail as specified.

## MINOR

1. **The `can_afford` memo keyed on ledger size goes stale across lives (spec 1, Evolving; Engine changes).**
   - `reset_run()` calls `_ledger.clear()` (`skill_rules_engine.gd:71-75`), so the size restarts at 0.
   - A memo keyed only on `size()` can return a previous life's answer once the new life's log reaches the same length with different contents. At a few thousand entries per run, some life hitting the same size is likely.
   - Fix: clear the memo in `reset_run()`, or key it on (run start, size). Add a test: afford in life 1, reset, same ledger size in life 2 without the essence → false.
2. **Spec 2 still references the dropped `family` (spec 2, Detail).** "with `condition_text` (which gains the `family` wording from the essence overhaul)". Spec 1 now adds a **`source`** branch to `_event_text` instead. Change the word.
3. **The priority-rule wording contradicts the Tremor move (spec 1, Calibration).** It says the Cave-start "within one eat" is the **primary** constraint and rebirth starts are held only to reachability. But Tremor gives up its Cave-start point (Deep → Flooded) to keep F1 reachable, so reachability actually outranks the within-one-eat target. State it that way: reachability is hard, within one eat is the target, and every exception is listed. The listed moves are already consistent with that order; only the sentence is inverted.

## Test coverage gaps

- Sticky Thread reachability from G1, F1 and D1 (NEW-1), once "reachable" is defined.
- Memo invalidation across `reset_run` (minor 1).

## Security

No change. `forms_reached` goes through `Profile.list_section` (string-checked). No content or profile string reaches a shell, query, template or eval.

VERDICT: REVISE — concerns above should be addressed first
