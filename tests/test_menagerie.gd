extends GutTest
## The Menagerie: one room with every creature in it, started with --room=menagerie, and the keeper that wakes the ones you stand near.

class StubPlayer extends Node2D:
	var team := "player"
	func receive_hit(_raw: int, _damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass

var creatures: Array

func before_all() -> void:
	creatures = DefLoader.load_dir("res://data/creatures")

func _ids(defs: Array) -> Array:
	return defs.map(func(c: CreatureDef) -> String: return c.id)

func test_the_order_is_shipped_then_support_then_twins_by_species_and_stage() -> void:
	var order := Menagerie.order(creatures)
	assert_eq(order.size(), creatures.size() - 1, "every creature but the water pool, which is terrain")
	var ids := _ids(order)
	assert_false(ids.has("water_pool"))
	var shipped := Sources.SHIPPED.filter(func(id: String) -> bool: return id != "water_pool")
	assert_eq(ids.slice(0, shipped.size()), shipped)
	assert_eq(ids.slice(shipped.size(), shipped.size() + MenagerieIds.SUPPORT.size()), MenagerieIds.SUPPORT)
	var last_species := -1
	var last_stage := 0
	for c in order.slice(shipped.size() + MenagerieIds.SUPPORT.size()):
		var s := Form.SPECIES.find(c.species)
		assert_gte(s, last_species, "%s: species in order" % c.id)
		if s != last_species:
			last_stage = 0
		assert_gte(c.stage, last_stage, "%s: stages rise within a species" % c.id)
		last_species = s
		last_stage = c.stage

func test_the_room_has_one_spawn_per_creature_spaced_apart() -> void:
	var request := Menagerie.request(creatures)
	var room: RoomDef = request["rooms"][Menagerie.ROOM_ID]
	assert_eq(request["room"], Menagerie.ROOM_ID)
	assert_eq(room.spawns.map(func(s: Dictionary) -> String: return s["id"]), _ids(Menagerie.order(creatures)))
	var last := -1000.0
	for s in room.spawns:
		assert_gte(s["pos"].x - last, Menagerie.SPACING, s["id"])
		last = s["pos"].x
	assert_lt(last, room.pixel_size().x - RoomDef.WALL)

func test_the_player_starts_on_the_floor_at_the_left_end() -> void:
	var request := Menagerie.request(creatures)
	var room: RoomDef = request["rooms"][Menagerie.ROOM_ID]
	assert_eq(request["pos"], room.start)
	assert_lt(room.start.x, room.spawns[0]["pos"].x)
	assert_true(room.is_start())

func test_the_player_starts_out_of_reach_of_every_creature() -> void:
	var room: RoomDef = Menagerie.request(creatures)["rooms"][Menagerie.ROOM_ID]
	for s in room.spawns:
		assert_gt(room.start.distance_to(s["pos"]), MenagerieKeeper.WAKE_RANGE, "%s would wake the moment the room loads" % s["id"])

func test_the_room_passes_the_world_validator_and_the_lint() -> void:
	var request := Menagerie.request(creatures)
	var rooms: Dictionary = request["rooms"]
	assert_eq(WorldValidator.validate(rooms, _ids(creatures)), PackedStringArray())
	assert_eq(RoomLint.check_room(rooms[Menagerie.ROOM_ID], rooms), [])

func test_the_swimmers_have_water_to_swim_in() -> void:
	var room: RoomDef = Menagerie.request(creatures)["rooms"][Menagerie.ROOM_ID]
	assert_gt(room.water.size(), 0)
	for s in room.spawns:
		if (creatures.filter(func(c: CreatureDef) -> bool: return c.id == s["id"])[0] as CreatureDef).swimmer:
			assert_true(room.water.any(func(w: Rect2) -> bool: return w.has_point(s["pos"])), s["id"])

func test_every_creature_has_a_name_tag_under_it() -> void:
	var tags := Menagerie.tags(creatures)
	var order := Menagerie.order(creatures)
	assert_eq(tags.size(), order.size())
	assert_eq(tags[0]["text"], order[0].display_name)
	assert_eq(tags[0]["pos"].x, Menagerie.request(creatures)["rooms"][Menagerie.ROOM_ID].spawns[0]["pos"].x)

func test_room_arg_reads_the_flag_and_nothing_else() -> void:
	assert_eq(Game.room_arg(["--room=menagerie"]), "menagerie")
	assert_eq(Game.room_arg(["--soul=5", "--room=menagerie"]), "menagerie")
	assert_eq(Game.room_arg([]), "")
	assert_eq(Game.room_arg(["--room"]), "")
	assert_eq(Game.room_arg(["--room="]), "")
	assert_eq(Game.room_arg(["--room=menagre"]), "", "a name nobody knows reads as no flag")

func test_the_keeper_wakes_what_the_player_stands_near_and_freezes_the_rest() -> void:
	var skills := {}
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d
	var by_id := {}
	for c in creatures:
		by_id[c.id] = c
	var player := StubPlayer.new()
	add_child_autofree(player)
	player.add_to_group("player")
	var near := Enemy.new()
	near.setup(by_id["lizard"], skills)
	near.position = Vector2(20, 0)
	add_child_autofree(near)
	var far := Enemy.new()
	far.setup(by_id["lizard"], skills)
	far.position = Vector2(MenagerieKeeper.WAKE_RANGE + 200.0, 0)
	add_child_autofree(far)
	var keeper := MenagerieKeeper.new()
	add_child_autofree(keeper)
	await wait_physics_frames(2)
	assert_false(near.dormant, "near: awake")
	assert_true(far.dormant, "far: asleep")
	player.global_position = far.global_position
	await wait_physics_frames(2)
	assert_true(near.dormant, "the player left: asleep again")
	assert_false(far.dormant, "now near: awake")

func test_a_game_started_with_the_flag_is_in_the_menagerie() -> void:
	Game.launch_override = {"headless": true, "args": ["--room=menagerie", "--skip-opening"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_eq(game.world.current_id, Menagerie.ROOM_ID)
	assert_eq(game.world.room.get_children().filter(func(n: Node) -> bool: return n is Enemy).size(), creatures.size() - 1)
	assert_not_null(game.get_node_or_null("MenagerieKeeper"))
	assert_eq(Compendium.progress.forms_reached.size(), 0, "nothing reaches the real profile")
	assert_null(game.world.ctx.get("compendium"), "looking is not seeing: no sighting reaches the bestiary")
	assert_false(Compendium.model.saving, "a defeat or an eat in the menagerie is not saved to the real profile")
	remove_child(game)
	game.queue_free()
	assert_true(Compendium.model.saving, "saving is back when the menagerie is left")
	assert_eq(game.get_children().filter(func(n: Node) -> bool: return n is EditorReturn).size(), 0, "there is no editor to go back to")

func test_a_hanging_creature_wakes_for_a_player_standing_under_it() -> void:
	var room: RoomDef = Menagerie.request(creatures)["rooms"][Menagerie.ROOM_ID]
	var by_id := {}
	for c in creatures:
		by_id[c.id] = c
	var hangers := 0
	for s in room.spawns:
		if Menagerie._hangs(by_id[s["id"]]):
			hangers += 1
			var under := Vector2(s["pos"].x, 308.0)  # the player's height on the floor
			assert_lte(under.distance_to(s["pos"]), MenagerieKeeper.WAKE_RANGE, "%s hangs where a player under it wakes it" % s["id"])
	assert_gt(hangers, 0)

func test_a_misspelt_room_flag_starts_the_normal_game() -> void:
	Game.launch_override = {"headless": true, "args": ["--room=menagre", "--skip-opening"]}
	var game = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game)
	await wait_physics_frames(5)
	assert_ne(game.world.current_id, Menagerie.ROOM_ID)
	assert_null(game.get_node_or_null("MenagerieKeeper"))
	assert_true(Compendium.model.saving, "an ordinary game saves")
