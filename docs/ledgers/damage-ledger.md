# SDD ledger — plan: docs/superpowers/plans/2026-09-29-damage-armor-levels.md
Pre-flight: T1 produces Damage.hit/RESIST_CAP consumed by T2 (tick_milli clamp) and T3 tests share tests/test_damage.gd; T4 independent. No conflicts found.
Task 1: complete (commits 39161c7..6edf086, tests: tools/run_tests.sh → PASS: 1185 tests)
Task 2: complete (commits 6edf086..4514f30, tests: tools/run_tests.sh → PASS: 1192 tests)
Task 3: complete (commits 4514f30..cf3bfe4, tests: tools/run_tests.sh → PASS: 1203 tests)
Task 4: complete (commits cf3bfe4..652b367, tests: tools/run_tests.sh → PASS: 1206 tests)
Task 5: complete (commits 652b367..fef2510, tests: tools/run_tests.sh → PASS: 1206 tests)
Task 1: Ruling: arbitrary resist percents in tests come from a test double (tests/support/fixed_resist.gd, a PlayerSkillSet subclass) rather than levelling the real skill — real skills only give 20/32/42/...; cost if wrong: the double ignores the damage type (the review found the wrong-type gap; a real-skill test was added in the fix pass)
Task 2: Ruling: _poison_milli is not reset in Player._on_run_started — the other poison state (_poison_left/_acc/_tick) is not reset there either, and a new life is a new Player; cost if wrong: a carry could survive into a rebirth in the same Player object (none exists today)
Task 2: Ruling: a poison tick expression uses floori(float()/float()) instead of integer division — matches the repo idiom and avoids the INTEGER_DIVISION warning
Task 3: Ruling: the Skills-tab ATK argument defaults to 1 and only lines labelled "Damage" amplify (ACTIVE_LABEL), exactly as the spec says; cost if wrong: a relabel silently drops the amplification (reviewer noted; spec-mandated)
Task 4: Ruling: added `const GROTTO_LEVEL := 4` in tools/build_content.gd and tests call the static _at_level/_scaled through load("res://tools/build_content.gd"); cost if wrong: the test depends on a tools script being loadable, which it is
Task 4: Ruling: the generator prints a macOS "ret != noErr" certificate line under the sandbox; it is environment noise (TLS/keychain), not re-run unsandboxed; cost if wrong: none, content regenerated identically twice
Final: fixed Miasma's cloud test could not fail at ATK 3 — test_the_clouds_holds_and_heals_stay_fixed_at_high_atk now casts Miasma at ATK 5, RED under a mutated cloud (skill_power(1, atk) -> [2,0] != [1,0]) GREEN restored, suite green
Final: fixed no test used real Poison Resistance or Venom Blood on ticks — test_real_poison_resistance_l1_shaves_the_ticks_of_a_toad_spit and test_venom_blood_shaves_the_ticks_too, RED under incoming("physical") (3 != 2) GREEN restored; tick_milli(1,30)==700 pinned in test_stats
Final: fixed vacuous level_of("poison_resistance")==0 guards removed from test_poison_carry (the real-skill tests assert level 1 unchanged after one more poison hit)
Final: fixed missing spec rows — test_poison_breath_ignores_the_crabs_armor_at_levels_1_and_4 (2 and 5), test_water_blade_at_atk_5_against_the_lizards_armor (3), test_a_toad_spit_on_def_3_costs_its_application_and_all_three_ticks (7)
Final: fixed playtest checklist line claimed a resisted spit always costs ticks; reworded for high resistance
Final: minor (deferred): damage.gd header comment says "percent reductions, then flat reductions, then floor" while the code floors before the flat subtraction (equivalent for integer flat) — wording only
Final: Ruling: poison now hurts the Mushroom Crab from any side (Breath L1 does 2 through DEF 2) — spec ruling 2 accepts it; cost if wrong: the crab's armor no longer matters for poison builds
Final: Ruling: the poison carry lasts indefinitely, so an old fraction lands on the next spit's first tick — spec ruling 8; cost if wrong: ticks depend on earlier spits
Final: Ruling: tackles at ATK 6+ against DEF 1 do 1 less (5->4 vs the serpent) and other off-table DEF>0 changes — covered by the spec's physical-hits-against-DEF class; the serpent is unspawned; cost if wrong: a few tackle values differ from the flat model
Final: Ruling: Blight's flavor text "A creeping rot you are immune to" is now untrue (poison ignores DEF) — out of scope in the spec; cost if wrong: one stale sentence
Final: Ruling: vine snake contact damage rises 3->4 at level 4 — an accepted table row; cost if wrong: Grotto snakes hit a little harder
Final: Ruling: the toad's Poison Resistance L2 stays unused and enemies have no resistance, XP does not scale with level — deferred by the spec; cost if wrong: creature resistances/XP-by-level need a follow-up
Final: Ruling: whether five crab tackles fit one stun in real play (knockback) was not measured — the spec pins only the timer arithmetic; cost if wrong: crabs take one more stun to kill
Final: Ruling: take_tick(0) fires `changed` on every resisted tick and spits during invulnerability are dropped whole — both pre-existing behaviours; cost if wrong: none new
