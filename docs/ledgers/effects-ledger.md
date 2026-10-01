# SDD ledger — plan: docs/superpowers/plans/2026-09-29-channeled-skills-and-effects.md
Pre-flight: Task 1 produces the Ability channel API and Player.end_channel; Tasks 2 and 4 consume it; Task 3 produces VfxArt and Vfx helpers that Tasks 4 and 5 consume. Checked, consistent.
Task 1: complete (44d6a0a; tests: test_channel 16/16, test_world 34/34; mutation-checked raw strength and hit-hook placement)
Task 2: complete (f639db3; tests: test_water_stream 9/9; mutation-checked the latched direction)
Task 3: complete (26ed69d; tests: test_vfx_art 4/4, test_vfx 13/13, test_player_rope 9/9)
Task 4: complete (9d01a68; tests: test_web_tether 9/9; mutation-checked the super._process call)
Task 5: complete (b04dd5b; tests: test_vfx 13/13, test_zone 9/9, test_evolution_abilities 19/19)
Task 6: complete (commits b04dd5b..4ada4a2, tests: tools/run_tests.sh → 1079/1079 pass; screenshots read: web tether, rope, stream, crescent, web patch)
Task 7 (added at the user's request mid-run, not in the plan): complete (commits 4ada4a2..1a04c3b, tests: test_enemy_web 11/11, test_vfx_art 7/7, test_enemy 66/66; screenshots read: strands on a slowed bat, cocoon on a held bat)
Task 7: Ruling: the webs are keyed to the thread (_web_slow, _web_hold set only in Enemy.receive_thread), not to _slow or the stun state — zones (Spore Cloud, Binding Web patch) slow and a tackle stuns, and none of them should grow webs — costs a second timer beside _slow
Task 7: Ruling: the cover is drawn at the sprite frame's exact pixel size (VfxArt.web_cover, cached per size and state) rather than one stretched texture — keeps one texel per game pixel like the rest of the art — costs one small cached image per distinct frame size
Task 7: Ruling: a later tackle stun after a thread hold ends is not cocooned (_web_hold clears when the state leaves STUNNED); a tackle on a still-held enemy keeps the cocoon until that stun ends — costs a slightly long cocoon in that overlap
Task 8 (added at the user's request mid-run: the blade should look like water, the web cover looked bad, use Codex art): complete (commits 1a04c3b..0c0a5e8, tests: full suite 1099/1099; screenshots read: water slash, strands on a bat, cocoon on a bat)
Task 8: Ruling: replaced the procedural crescent and enemy web cover with Codex-generated pixel art (tools/art/vfx_frames.json, make_vfx.py, assets/sprites/vfx_*.png) — the user asked for it, and it supersedes the earlier "procedural textures, not the image pipeline" ruling for these three sprites only; the rope silk and the Binding Web patch stay procedural — costs three generated PNGs to keep in step with the game's look
Task 8: Ruling: the web cover is resampled per frame size at runtime from the one master (VfxArt.web_cover, cached per size) rather than shipped at several sizes — sheet frames are trimmed to many sizes — costs a small resample the first time a size is seen
Final: fixed the cocoon/strands staying full size over an enemy being eaten — test_the_web_hides_with_the_sprite_while_the_enemy_is_being_eaten RED→GREEN (mutation-checked), suite 1099/1099
Final: fixed strands jumping to new positions on every animation frame — the strands are now one generated sprite scaled to each frame, no per-size seed — test_the_strand_layout_does_not_change_with_the_animation_frame, suite 1099/1099
Final: fixed the Water Blade slash sliding back into the slime at point-blank (re-graded from Minor to Important: close range is the blade's main use) — test_water_blade_at_point_blank_never_slides_back_into_the_caster RED→GREEN (mutation-checked), suite 1099/1099
Final: fixed the spec's tier-2 hold never being pinned, and the playtest line that promised a stun at level 1-2 (re-graded from Minor: a playtester would fail the line) — test_a_tier_two_hold_stuns_a_real_enemy_and_keeps_it_stunned, checklist now says level 3, suite 1099/1099
Final: Ruling: reviewer's HYPOTHESIS that the two real-Player tether tests have no floor — refuted by a probe: the slime lands on the toad at y=-18, 18 px away, in range, so they do run the full 3 s hold; no change — costs the tests leaning on the toad as the floor
Final: Ruling: re-tethering after each 3 s cap and 0.8 s cooldown can keep an enemy stunned about 15 s on 20 MP — design, the spec bounds one hold; stands — costs a strong loop at full MP
Final: Ruling: at tier 1 a hold adds little over a tap — design; stands
Final: Ruling: the rope and tether always sag downward even when taut — the spec asks for a slight sag; stands
Final: Ruling: a trigger wobbling around 0.5 after a cap can re-fire just_pressed when the cooldown ends — predates this branch; stands
Final: Ruling: the tether's terrain ray treats one-way platforms as rock — existing terrain_hit behaviour; stands
Final: Ruling: Binding Web's patch slows without drawing strands on the enemy — webs are keyed to the thread by Task 7's ruling; stands
Final: Ruling: a cocoon on a thread-held enemy that is hurt while stunned changes shape for the hurt frame — the cover follows the frame; stands — costs a brief resize
Final: Ruling: the double strand at the start of a hold (0.35 s flash plus the persistent tether) — as the spec says; stands
Final: Ruling: a gamepad disconnecting mid-hold — bounded by the 3 s cap; stands
Final: minor (deferred): test_every_press_is_ignored_while_a_channel_is_live — its use_active(1) half hits an empty slot so it proves nothing (the use_active(0) half pins the guard)
Final: minor (deferred): no test for a discounted start with an undiscounted beat (trait_spinner / trait_water_thrift), which the spec lists
