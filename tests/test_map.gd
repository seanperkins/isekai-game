extends GutTest
## Map tab: rooms you've visited, drawn to scale; stubs for exits you haven't taken; your room
## highlighted; a count of rooms found.

var rooms := {}
var progress: WorldProgress

func _room(id: String, cell: Vector2i, exits: Array, extra: Dictionary = {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.cell = cell
	r.exits = exits
	for k in extra:
		r.set(k, extra[k])
	return r

func before_each() -> void:
	rooms = {
		"A": _room("A", Vector2i(0, 0), [{"edge": "right", "from": 200.0, "to": 320.0, "room": "B"}], {"start": Vector2(100, 310)}),
		"B": _room("B", Vector2i(1, 0), [{"edge": "left", "from": 200.0, "to": 320.0, "room": "A"},
			{"edge": "right", "from": 200.0, "to": 320.0, "room": "C"}],
			{"features": [{"kind": "glow_pool", "id": "p", "pos": Vector2(320, 320)}]}),
		"C": _room("C", Vector2i(2, 0), [{"edge": "left", "from": 200.0, "to": 320.0, "room": "B"}]),
	}
	progress = WorldProgress.new()
	progress.visit("A")
	progress.visit("B")

func test_map_view_shows_visited_rooms_and_unexplored_exits() -> void:
	var m := SkillScreenModel.map_view(rooms, progress, "B")
	assert_eq(m["rooms"].map(func(r: Dictionary) -> String: return r["id"]), ["A", "B"])
	assert_true(m["rooms"][1]["current"])
	assert_true(m["rooms"][1]["pool"])
	assert_eq(m["stubs"].size(), 1)
	assert_eq(m["stubs"][0]["point"], Vector2(1280, 260))
	assert_eq(m["found"], "Rooms found 2/3")
	assert_eq(m["bounds"], Rect2(0, 0, 1920, 360))

func test_the_map_tab_draws_inside_the_screen() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, [])
	var player := Player.new()
	player.setup(rules, compendium, [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(player)
	var world: World = autofree(World.new())
	world.rooms = rooms
	world.current_id = "B"
	var screen := SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, compendium, skills)
	screen.bind_world(world, progress)
	screen.open()
	screen.switch_tab(4)
	assert_eq(screen.tab(), "map")
	assert_eq(screen.map_found_text(), "Rooms found 2/3")
	assert_eq(screen.map_room_count(), 2)
	for c in screen.find_children("*", "Control", true, false):
		var r: Rect2 = c.get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= 640.0 and r.position.y >= 0.0 and r.end.y <= 360.0, str(c.name, r))
	get_tree().paused = false

func test_the_map_tab_without_a_world_says_so() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	var player := Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(player)
	var screen := SkillScreen.new()
	add_child_autofree(screen)
	screen.bind(player, rules, CompendiumModel.new(skills, []), skills)
	screen.open()
	screen.switch_tab(4)
	assert_eq(screen.map_room_count(), 0)
	get_tree().paused = false
