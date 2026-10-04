# Soul layer plan 3 (altars): debate panel review (2026-10-04)

Plan: `docs/superpowers/plans/2026-10-04-soul-layer-3-altars.md`.
Panel: executor and auditor (the current default panel). The repo is public now, so no ZDR override was needed.
Rounds: 1 both REVISE; 2 executor APPROVED, auditor REVISE; then three verification passes by the auditor (REVISE, REVISE, APPROVED). Each finding was checked against the code before a ruling.

| # | Finding (seat) | Check | Ruling |
|---|---|---|---|
| 1 | `Game._ready` validates the world before the goddess exists, so the perk list cannot come from it (executor) | True | Task 4 adds `Game.world_errors`, which validates with the shipped perk definitions, and a test of it |
| 2 | Task 7's test leaves banked soul data on disk (executor, auditor) | True: banking and buying save through the Profile | Snapshot and restore the saved soul section, the progress arrays and the touched Profile sections |
| 3 | Deleting `RebirthKit` breaks `room_lint.gd:45`, `test_player_in_water.gd:45` and `test_room_editor_scene.gd:341` and `:721` (auditor) | True | Task 6 lists each replacement; `CAVE_MOVEMENT_KIT` stays granted through `HeadStart.apply` |
| 4 | A malformed altar with no `pos` crashes the editor's lint path first (auditor) | True, but it is how every feature kind behaves today | Declined: this plan does not change it |
| 5 | A world with no altar passes the default-altar check (auditor) | True by design: every small test world has no altar | Declined: the rule applies once any altar exists, and the shipped-world test pins `C1` |
| 6 | An altar's `area` can disagree with its room's `area` (auditor) | True; the shipped altars agree | New validator rule with a test |
| 7 | Task 1 names `tests/test_goddess_flow.gd`, which is absent (auditor) | Absent only because this branch was cut before plan 2's last commit | Declined: it exists once plan 2 merges |
| 8 | Task 7 restores neither `Compendium.progress` nor the skill run (auditor) | True | Specified: arrays and sections restored, `SkillRules.reset_run()` at the end |
| 9 | Task 7's essence events unlock skills in the real Compendium (auditor) | True | The menu is bound to an isolated engine for the test |
| 10 | Task 7 also leaves the Compendium and bestiary sections and `sanitize`'s last choice; the menu no longer tests the production binding; `after_each` runs before GUT frees the scene (auditor) | The binding and the ordering are real; the rest is how every game-scene test in the suite behaves against the scratch profile | Fixed: `AltarMenu.engine` is asserted to be `SkillRules` before rebinding, and `after_each` frees the scene first. Declined: restoring the Compendium, bestiary and `sanitize` state, with the convention stated in the plan |
