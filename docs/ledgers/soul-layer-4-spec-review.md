# Soul layer plan 4 (the opening): debate panel review of the spec (2026-10-04)

Spec: `docs/superpowers/specs/2026-10-04-the-opening-design.md`.
Panel: executor and auditor (the current default panel). The repo is public, so no ZDR override was needed.
Rounds: 1, 2 and 3 both REVISE; a verification pass then had the auditor APPROVED and the executor REVISE on one wording point, which was fixed without a further review (the revision budget was spent). Each finding was checked against the code before a ruling.

| # | Finding (seat) | Check | Ruling |
|---|---|---|---|
| 1 | `start_opening()` saved `opening_seen: false` before `play()`, so a refused start changed saved state (executor, auditor) | True | Superseded by 8, 12 and 15: `start_opening()` saves nothing; `_ready` saves the flag |
| 2 | The malformed-resource promise had no runtime path (executor, auditor) | True | `Game.load_opening()` validates the loaded resource; the validator also checks entry and field types |
| 3 | A refused `open_first_meeting` left the tree paused (executor) | True | `Game` unpauses and the player plays on, the opening still unseen |
| 4 | The flow test cannot read `pending_start` after a real restart, which clears it (executor) | True (`take_pending` clears) | The test replaces `_restart` with a counter, as `test_goddess_flow.gd` does; the restart's unpause stays with `test_run.gd` |
| 5 | A `CanvasLayer` has no `_draw` (auditor) | True | A child `Node2D` stage holds the drawing |
| 6 | Layer 45 would hide her menu at layer 40 (auditor) | True | The opening hides its layer, tree still paused, before `finished` |
| 7 | The hit would be silent: `enemy_impact` is on the `SFX_Enemy` bus and Audio keeps only `UI` voices alive while paused (auditor) | True (`audio.gd:126`, `cues.json`) | A new `opening_hit` cue reusing the impact files on the `UI` bus, not positional |
| 8 | Entering the first room saves the map before `start_opening()`, so a crash or refusal leaves a fresh profile that the no-key rule reads as an old save (executor, auditor) | True | `_ready` saves the explicit `false` before the world is set up |
| 9 | `open_first_meeting` must refuse while `_ending` (executor) | True | Added, with a test |
| 10 | `SoulProgress._save()` drops `Profile.save()` failures (executor) | True, for every soul field | Declined: the Profile warns and the worst case is a replay; stated in the spec |
| 11 | An unusable goddess model (empty `confirm()`) leaves the menu unconfirmable and the tree paused (auditor) | True | `open_first_meeting` refuses on an empty `confirm()` |
| 12 | Saving before validating conflicts with "a malformed resource saves nothing" (executor, auditor) | True | `_ready` loads and validates first, then saves; one failure policy, a malformed resource skips the opening and the profile later counts as seen |
| 13 | The validator should require three trucks and four choices (executor) | True that it does not | Declined: counts are data; the shipped-file test pins them |
| 14 | `--opening` replays after every restart, so the player never reaches the game (auditor) | True (the restart reloads the scene in the same process) | `--opening` is honored once per process |
| 15 | A forced `--opening` writes `false` over a completed profile's `true` (auditor) | True | `begin_opening()` only for an unseen profile; a forced replay leaves the flag alone until it finishes |
| 16 | "Writes nothing until it finishes" is wrong: `sanitize` and the map still save (executor, verification) | True | Reworded to "leaves `opening_seen` alone"; not re-reviewed |
