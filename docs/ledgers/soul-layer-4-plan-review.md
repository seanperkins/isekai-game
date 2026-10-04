# Soul layer plan 4 (the opening): debate panel review of the plan (2026-10-04)

Plan: `docs/superpowers/plans/2026-10-04-soul-layer-4-opening.md`.
Panel: executor and auditor (the current default panel). The repo is public, so no ZDR override was needed.
Rounds: 1, 2 and 3 both REVISE; a verification pass then had the executor REVISE and the auditor fail once (the model was at capacity) and REVISE on re-run. The last fixes were applied without a further review (the revision budget was spent). Each finding was checked against the code before a ruling.

| # | Finding (seat) | Check | Ruling |
|---|---|---|---|
| 1 | The generator made its directory with a `res://` path and never checked the save (executor) | True | `tools/build_opening.gd` copies `tools/build_soul.gd`'s `_save` helper verbatim |
| 2 | `git add -A <paths>` could stage movement-owned files (executor) | False here: this worktree is isolated and the movement agent edits its own | Declined |
| 3 | `run_tests.sh` reads `$?` without `set -e` (executor) | Works as written | No change |
| 4 | `--opening` under a headless run starts an opening nobody can advance (auditor) | True | `wants_opening` checks headless before `--opening`, with a test |
| 5 | A validator test assigned a String to a typed `Array` field (auditor) | True | The test uses malformed entries; a wrong top-level type is Godot's to refuse |
| 6 | The flow test stays paused after its intercepted restart, so the timed death never advances (auditor) | True | The handler counts and calls `game._prepare_restart()` |
| 7 | The input probe ignored the paused tree, so it passed even if Escape opened the skill screen (auditor) | True | The probe is `PROCESS_MODE_ALWAYS` and the flow test asserts the skill screen stays closed |
| 8 | The "new profile" flow test read the test home's saved choice, deaths and attunements (auditor) | True | Last choice, pending start and deaths are pinned and restored |
| 9 | The generator ran before the class cache knew `OpeningDef` (executor) | True | Import first, run, import again |
| 10 | A headless first launch writes the map and the no-key rule then reads the profile as seen (auditor) | True | The unseen flag is saved whenever the profile is unseen and the resource is valid, wanted or not; a two-launch test |
| 11 | A migrated legacy save has `compendium` and `bestiary` but no map, so it would see the truck (auditor) | True (`Profile._migrate`) | The no-key rule counts a non-empty `map`, `compendium` or `bestiary` |
| 12 | `Game.force_opening` bypassed the headless and skip rules (executor) | True of a test hook whose job is that | Replaced by `Game.launch_override` (`args`, `headless`), which keeps the real decision |
| 13 | A malformed opening leaves a fresh profile counting as seen (executor) | True, and the spec's failure policy | Declined: shipped data is pinned by a test and a bad resource is a loud bug |
| 14 | The plan listed several suites in one runner call (executor) | True | Each suite is its own invocation |
| 15 | A headless or skipped fresh launch would still start the opening (auditor) | True | `start_opening` runs only when `wanted` |
| 16 | The flow test forced the opening and so never ran the normal decision (auditor) | True | It uses `launch_override`, plus skip and headless launches |
| 17 | The flow test did not restore the Profile `rebirths` section (auditor) | True | Added to the snapshot |
| 18 | A failed `Profile.save()` can lose the unseen flag (executor) | True, for every soul field | Declined: the Profile warns and the worst case is a replay (the spec says so) |
| 19 | A malformed asset can consume a fresh profile's opening, again (executor) | Same as 13 | Declined |
| 20 | `load_opening()` must check the resource type before the validator (executor) | True | `is OpeningDef` check and a wrong-type test |
| 21 | The global constraint still said a map alone marks "seen" (auditor) | True | Reworded to match Task 3 |
| 22 | `start_opening()` has no editor Play guard of its own (auditor) | True for an editor Play | Guarded, with a test in `test_editor_play.gd`; a headless guard declined, since tests call it directly |
| 23 | F11 fullscreen still works during the opening (auditor) | True | Declined: a window shortcut, not a game input |
