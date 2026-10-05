extends GutTest
## Killing what killed you: the last life's killer is remembered across lives, and killing it is an `avenged` defeat.

var dir: String

func before_each() -> void:
	dir = "user://test_avenged_%d" % Time.get_ticks_usec()

func after_each() -> void:
	var path := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(path):
		for f in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(f))
		DirAccess.remove_absolute(path)

func _profile() -> Profile:
	var p := Profile.new(dir.path_join("profile.json"))
	p.warn = func(_msg: String) -> void: pass
	p.reload()
	return p

func test_a_death_remembers_what_dealt_the_last_blow_across_loads() -> void:
	var profile := _profile()
	var soul := SoulProgress.new(profile)
	soul.note_death("lizard")
	assert_eq(soul.last_death_cause, "lizard")
	assert_eq(soul.deaths, 1)
	var again := SoulProgress.new(_profile())
	assert_eq(again.last_death_cause, "lizard", "it was saved")
	assert_eq(again.deaths, 1)

func test_a_later_death_replaces_it_and_no_cause_clears_it() -> void:
	var soul := SoulProgress.new(_profile())
	soul.note_death("lizard")
	soul.note_death("toad")
	assert_eq(soul.last_death_cause, "toad")
	soul.note_death()
	assert_eq(soul.last_death_cause, "")

func test_a_saved_cause_that_is_not_a_string_loads_as_none() -> void:
	var profile := _profile()
	profile.set_section("soul", {"points": 0, "perks": {}, "deaths": 2, "opening_seen": true, "last_death_cause": 7})
	profile.save()
	assert_eq(SoulProgress.new(_profile()).last_death_cause, "")

func test_a_profile_from_before_it_existed_loads_none() -> void:
	var profile := _profile()
	profile.set_section("soul", {"points": 3, "perks": {}, "deaths": 2, "opening_seen": true})
	profile.save()
	var soul := SoulProgress.new(_profile())
	assert_eq(soul.last_death_cause, "")
	assert_eq(soul.points, 3)

func test_the_goddess_hands_the_cause_to_the_soul() -> void:
	var goddess := Goddess.load_default(SoulProgress.new(), CompendiumModel.new([], []), [])
	goddess.line_for_death("armed_ant")
	assert_eq(goddess.soul.last_death_cause, "armed_ant")

func test_killing_the_remembered_killer_is_an_avenged_defeat() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var events: Array = []
	var player := Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	player.avenge_target = "bat"
	var bat := Enemy.new()
	bat.setup(creatures["bat"], by_id)
	add_child_autofree(bat)
	var toad := Enemy.new()
	toad.setup(creatures["toad"], by_id)
	add_child_autofree(toad)
	player.note_defeat(bat)
	player.note_defeat(toad)
	assert_true(events[0][1].has("avenged"))
	assert_false(events[1][1].has("avenged"))
	player.avenge_target = ""
	player.note_defeat(bat)
	assert_false(events[2][1].has("avenged"), "nothing to avenge")

func test_a_new_life_carries_the_remembered_killer() -> void:
	var was: String = Compendium.soul.last_death_cause
	Compendium.soul.last_death_cause = "bat"
	Game.launch_override = {"headless": true, "args": ["--skip-opening"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_eq(game.player.avenge_target, "bat")
	Compendium.soul.last_death_cause = was
