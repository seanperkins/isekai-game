extends GutTest
## The cue catalog: routing an event to a cue, picking variants and validating data/audio/cues.json.

func _exists(_p: String) -> bool:
	return true

func _biomes() -> Dictionary:
	var out := {}
	for area in CueCatalog.BIOMES:
		out[area] = {"music": "music/%s.ogg" % area, "ambience": "ambience/%s.ogg" % area, "reverb_wet": 0.2,
			"oneshots": {"cues": ["a"], "interval": [4.0, 8.0], "radius": 200}}
	return out

func _catalog(events := {}, themes := {}) -> CueCatalog:
	return CueCatalog.from_dict({
		"cues": {
			"a": {"files": ["sfx/a_1.ogg", "sfx/a_2.ogg"], "bus": "SFX_Player", "volume_db": -6},
			"b": {"files": ["sfx/b_1.ogg"], "bus": "UI"},
			"lp": {"files": ["sfx/lp_1.ogg"], "bus": "SFX_Player", "loop": true},
		},
		"events": events,
		"biomes": _biomes(),
		"themes": themes,
	})

func test_a_plain_event_routes_to_its_cue() -> void:
	var c := _catalog({"jumped": "a"})
	assert_eq(c.route("jumped", {}), {"cue": "a"})

func test_a_bool_tag_selects_by_its_string_form() -> void:
	var c := _catalog({"landed": {"by": "hard", "true": "a", "false": "b"}})
	assert_eq(c.route("landed", {"hard": true}), {"cue": "a"})
	assert_eq(c.route("landed", {"hard": false}), {"cue": "b"})

func test_a_by_id_entry_falls_back_to_default() -> void:
	var c := _catalog({"skill_used": {"by": "id", "x": "a", "default": "b"}})
	assert_eq(c.route("skill_used", {"id": "x"}), {"cue": "a"})
	assert_eq(c.route("skill_used", {"id": "zzz"}), {"cue": "b"})
	assert_eq(c.route("skill_used", {}), {"cue": "b"})

func test_a_by_entry_without_a_default_is_silent_for_an_unknown_tag() -> void:
	var c := _catalog({"e": {"by": "id", "x": "a"}})
	assert_eq(c.route("e", {"id": "nope"}), {})

func test_stop_silent_and_unknown_events() -> void:
	var c := _catalog({"off": {"stop": "lp"}, "quiet": null, "_why:quiet": "because"})
	assert_eq(c.route("off", {}), {"stop": "lp"})
	assert_eq(c.route("quiet", {}), {})
	assert_eq(c.route("never_heard_of_it", {}), {})

func test_pick_file_never_repeats_a_variant_back_to_back() -> void:
	var c := _catalog()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var last := ""
	for i in 200:
		var f := c.pick_file("a", rng)
		assert_ne(f, last)
		assert_true(f.begins_with("res://assets/audio/sfx/a_"))
		last = f

func test_pick_file_with_one_variant_and_an_unknown_cue() -> void:
	var c := _catalog()
	var rng := RandomNumberGenerator.new()
	assert_eq(c.pick_file("b", rng), "res://assets/audio/sfx/b_1.ogg")
	assert_eq(c.pick_file("b", rng), "res://assets/audio/sfx/b_1.ogg")
	assert_eq(c.pick_file("nope", rng), "")

func test_a_valid_catalog_has_no_errors() -> void:
	var c := _catalog({"jumped": "a", "off": {"stop": "lp"}, "quiet": null, "_why:quiet": "x"})
	assert_eq(c.validate(_exists), [])

func test_validate_reports_each_kind_of_mistake() -> void:
	var missing := func(p: String) -> bool: return not p.ends_with("a_2.ogg")
	assert_true(_errors(_catalog(), missing, "missing file"))
	var c := _catalog({"quiet": null})
	assert_true(_errors(c, _exists, "silent without a _why"))
	c = _catalog({"e": "ghost"})
	assert_true(_errors(c, _exists, "unknown cue"))
	c = _catalog({"e": {"stop": "a"}})
	assert_true(_errors(c, _exists, "not a loop"))
	c = _catalog()
	c.cues["a"]["bus"] = "Nope"
	assert_true(_errors(c, _exists, "unknown bus"))
	c = _catalog()
	c.biomes.erase("deep")
	assert_true(_errors(c, _exists, "biome deep"))
	c = _catalog()
	c.biomes["cave"]["oneshots"]["interval"] = [8.0, 4.0]
	assert_true(_errors(c, _exists, "bad interval"))

func _errors(c: CueCatalog, exists: Callable, what: String) -> bool:
	var errs := c.validate(exists)
	if errs.is_empty():
		fail_test("expected an error for: " + what)
		return false
	return true

# --- the committed catalog ------------------------------------------------------

func test_the_committed_catalog_validates_against_the_real_files() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	assert_gt(c.cues.size(), 45)
	var errs := c.validate(func(p: String) -> bool: return FileAccess.file_exists(p))
	assert_eq(errs, [], "\n".join(errs))

func test_every_gameplay_event_has_an_entry() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	for name in Events.ALL:
		assert_true(c.events.has(name), "events.%s" % name)
	for name in ["skill_unlocked", "skill_leveled", "evolution_ready"]:
		assert_true(c.events.has(name), "events.%s" % name)

func test_every_active_skill_has_its_own_cue() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	var by_id: Dictionary = c.events["skill_used"]
	for d in SkillRules.skill_defs:
		if SkillEffects.active_scene(d) != "":
			assert_true(by_id.has(d.id), "skill_used.%s" % d.id)

func test_no_audio_file_is_orphaned() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	var used := {}
	for id in c.cues:
		for f in c.cues[id]["files"]:
			used[f] = true
	for area in c.biomes:
		used[c.biomes[area]["music"]] = true
		used[c.biomes[area]["ambience"]] = true
	for id in c.themes:
		used[c.themes[id]["music"]] = true
	for sub in ["sfx", "music", "ambience"]:
		for f in DirAccess.get_files_at("res://assets/audio/" + sub):
			if f.ends_with(".ogg"):
				assert_true(used.has(sub + "/" + f), "orphan %s/%s" % [sub, f])

func test_the_opening_hit_cue_is_on_the_ui_bus_and_not_positional() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	assert_eq(c.route("opening_hit", {}), {"cue": "op_crash"})
	var rule: Dictionary = c.cues["op_crash"]
	assert_eq(rule["bus"], "UI", "Audio keeps only UI voices alive while the tree is paused, and the opening pauses it")
	assert_false(bool(rule.get("positional", false)))
	assert_false(c.cues.has("opening_impact"), "the stand-in that borrowed the enemy hit is gone")

# --- themes: a track that takes the music over from the room's bed ---

func test_a_theme_event_routes_to_its_theme_and_a_stop_event_to_its_end() -> void:
	var c := _catalog({"fight": {"theme": "battle"}, "peace": {"theme_stop": "battle"}},
		{"battle": {"music": "music/battle.ogg", "fade_in": 0.5, "fade_out": 1.5}})
	assert_eq(c.route("fight", {}), {"theme": "battle"})
	assert_eq(c.route("peace", {}), {"theme_stop": "battle"})
	assert_eq(c.themes["battle"]["fade_out"], 1.5)

func test_valid_theme_data_validates_clean() -> void:
	var c := _catalog({"fight": {"theme": "battle"}, "peace": {"theme_stop": "battle"}},
		{"battle": {"music": "music/battle.ogg", "fade_in": 0.5, "fade_out": 1.5}})
	assert_eq(c.validate(_exists), [], "a theme's name in an event is not read as a cue id")

func test_theme_mistakes_are_named() -> void:
	var themes := {"battle": {"music": "music/battle.ogg", "fade_in": 0.5, "fade_out": 1.5}}
	var gone := func(p: String) -> bool: return not p.ends_with("battle.ogg")
	assert_true(str(_catalog({}, themes).validate(gone)).contains("theme battle: missing music file"))
	assert_true(str(_catalog({"fight": {"theme": "nope"}}, themes).validate(_exists)).contains("event fight: unknown theme nope"))
	assert_true(str(_catalog({"peace": {"theme_stop": "nope"}}, themes).validate(_exists)).contains("event peace: unknown theme nope"))
	var slow := {"battle": {"music": "music/battle.ogg", "fade_in": 99.0, "fade_out": -1.0}}
	var errors := str(_catalog({}, slow).validate(_exists))
	assert_true(errors.contains("theme battle: fade_in must be 0..10"))
	assert_true(errors.contains("theme battle: fade_out must be 0..10"))

func test_the_shipped_opening_events_route_to_their_sounds() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	assert_eq(c.validate(func(p: String) -> bool: return ResourceLoader.exists(p)), [])
	assert_eq(c.route("opening_started", {}), {"theme": "opening_battle"})
	assert_eq(c.route("opening_ended", {}), {"theme_stop": "opening_battle"})
	assert_eq(c.route("opening_turn", {"who": "player"}), {"cue": "op_turn"})
	assert_eq(c.route("opening_turn", {"who": "truck"}), {}, "the truck's turn has no chime: its engine says it")
	assert_eq(c.route("opening_truck_arrive", {"index": 0}), {"cue": "op_arrive"})
	assert_eq(c.route("opening_truck_arrive", {"index": 1}), {"cue": "op_arrive_horn"})
	assert_eq(c.route("opening_grandma_arrive", {}), {"cue": "op_steps"})
	var actions := {"fight": "op_swing", "dodge": "op_dodge", "jump": "op_jump", "pray": "op_pray", "run": "op_run", "grandma": "op_dash"}
	for id in actions:
		assert_eq(c.route("opening_action", {"id": id}), {"cue": actions[id]}, id)
	assert_eq(c.route("opening_umbrella_hit", {}), {"cue": "op_bonk"})
	assert_eq(c.route("opening_shove", {}), {"cue": "op_shove"})
	assert_eq(c.route("opening_grandma_safe", {}), {"cue": "op_safe"})
	assert_eq(c.route("opening_charge", {"rage": false}), {"cue": "op_charge"})
	assert_eq(c.route("opening_charge", {"rage": true}), {"cue": "op_rage"})
	assert_eq(c.route("opening_pass", {}), {"cue": "op_pass"})
	assert_eq(c.route("opening_hit", {}), {"cue": "op_crash"})
	assert_eq(c.route("opening_ko", {}), {"cue": "op_ko_fall"})
	assert_eq(c.route("opening_whiteout", {}), {"cue": "op_whiteout"})

func test_every_opening_cue_plays_on_the_ui_bus_so_it_sounds_while_the_tree_is_paused() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	var found := 0
	for id in c.cues:
		if str(id).begins_with("op_"):
			found += 1
			assert_eq(c.cues[id]["bus"], "UI", id)
			assert_false(bool(c.cues[id].get("positional", false)), id)
	assert_eq(found, 19)

func test_the_shipped_battle_theme_is_a_music_file_with_fades() -> void:
	var c := CueCatalog.load_file("res://data/audio/cues.json")
	var theme: Dictionary = c.themes["opening_battle"]
	assert_eq(theme["music"], "music/opening_battle.ogg")
	assert_gt(float(theme["fade_in"]), 0.0)
	assert_gt(float(theme["fade_out"]), 0.0)
