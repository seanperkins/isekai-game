extends GutTest
## Room tags (moonlit, hold): a lint rule for the names, a kill in a moonlit room is a deed with the flag, the forest's open rooms carry it.

var skills: Array
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for d in skills:
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _findings(r: RoomDef) -> Array:
	return RoomLint.check_room(r, {r.id: r}).filter(func(f: Dictionary) -> bool: return f["rule"] == "room_tag")

func test_an_unknown_room_tag_is_a_lint_finding() -> void:
	var r := AreaKit.room("TG1", "forest", Vector2i(40, 40))
	r.tags = ["moonlit", "sunny"]
	var found := _findings(r)
	assert_eq(found.size(), 1)
	assert_string_contains(found[0]["text"], "sunny")

func test_the_known_tags_are_clean() -> void:
	var r := AreaKit.room("TG1", "forest", Vector2i(40, 40))
	r.tags = ["moonlit", "hold"]
	assert_eq(_findings(r), [])
	assert_true(RoomLint.RULES.has("room_tag"))

func test_the_kit_tags_a_room_once() -> void:
	var r := AreaKit.room("TG1", "forest", Vector2i(40, 40))
	AreaKit.tag(r, "moonlit")
	AreaKit.tag(r, "moonlit")
	AreaKit.tag(r, "hold")
	assert_eq(r.tags, ["moonlit", "hold"])

func test_for_defeat_tags_moonlit_only_when_the_context_says_so() -> void:
	var def: CreatureDef = creatures["toad"]
	assert_false(DeedTags.for_defeat(def, {}, {}).has("moonlit"))
	assert_false(DeedTags.for_defeat(def, {}, {"moonlit": false}).has("moonlit"))
	assert_true(DeedTags.for_defeat(def, {}, {"moonlit": true})["moonlit"])

func test_a_defeat_in_moonlight_carries_the_tag_and_one_out_of_it_does_not() -> void:
	var events: Array = []
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var player := Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void: events.append([n, t]))
	add_child_autofree(player)
	var e := Enemy.new()
	e.setup(creatures["toad"], skills_by_id)
	add_child_autofree(e)
	player.in_moonlight = true
	player.note_defeat(e)
	player.in_moonlight = false
	player.note_defeat(e)
	var defeats := events.filter(func(x: Array) -> bool: return x[0] == Deeds.DEFEATED)
	assert_eq(defeats.size(), 2)
	assert_true(defeats[0][1].get("moonlit", false))
	assert_false(defeats[1][1].has("moonlit"))

func test_entering_a_moonlit_room_sets_the_players_flag_and_leaving_it_clears_it() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(3)
	assert_true((game.world.rooms["FO3"] as RoomDef).tags.has("moonlit"))
	game._on_room_entered("FO3")
	assert_true(game.player.in_moonlight)
	game._on_room_entered("FO1")
	assert_false(game.player.in_moonlight)

func test_the_forests_open_rooms_are_moonlit_and_its_covered_ones_are_not() -> void:
	var world := World.load_rooms(AreaBuilder.ROOMS_DIR)
	for id in ["FO2", "FO3", "FO5", "FO6", "FO7", "FO8"]:
		assert_true((world[id] as RoomDef).tags.has("moonlit"), id)
	for id in ["FO1", "FO4", "FO9"]:
		assert_false((world[id] as RoomDef).tags.has("moonlit"), id)

func test_tags_survive_a_serialize_and_a_load() -> void:
	var r := AreaKit.room("TG9", "forest", Vector2i(40, 40))
	AreaKit.tag(r, "hold")
	var path := "user://room_tags_%d.tres" % Time.get_ticks_usec()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(AreaBuilder.serialize(r))
	f.close()
	var back: RoomDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(back.tags, ["hold"])
