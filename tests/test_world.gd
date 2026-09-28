extends GutTest
## The World keeps one room live. Crossing an open exit freezes the player, slides the camera
## into the neighbour, frees the old room and hands the player back their velocity.

var rules: SkillRulesEngine
var player: Player
var world: World
var progress: WorldProgress
var spawned: Array = []
var entered_velocity := Vector2.INF

func _room(id: String, cell: Vector2i, exits: Array, extra: Dictionary = {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.cell = cell
	r.exits = exits
	for k in extra:
		r.set(k, extra[k])
	return r

func _spawn(id: String, pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.set_meta("spawn", id)
	spawned.append(n)
	return n

func _world(rooms: Dictionary) -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	progress = WorldProgress.new()
	world = World.new()
	add_child_autofree(world)
	world.setup(rooms, player, {"spawn": _spawn, "progress": progress})
	world.room_entered.connect(func(_id: String) -> void: entered_velocity = player.velocity)
	rules.start_run()
	world.enter_start()

func _side_by_side() -> void:
	spawned = []
	_world({
		"A": _room("A", Vector2i(0, 0), [{"edge": "right", "from": 200.0, "to": 320.0, "room": "B"}],
			{"start": Vector2(100, 310), "spawns": [{"id": "bat", "pos": Vector2(300, 200)}]}),
		"B": _room("B", Vector2i(1, 0), [{"edge": "left", "from": 200.0, "to": 320.0, "room": "A"}]),
	})

func _rooms_alive() -> int:
	return world.get_children().filter(func(n: Node) -> bool: return world.rooms.has(String(n.name))).size()

func after_each() -> void:
	get_tree().paused = false
	Input.action_release("move_right")

func test_starting_places_the_player_and_frames_the_room() -> void:
	_side_by_side()
	assert_eq(world.current_id, "A")
	assert_eq(player.global_position, Vector2(100, 310))
	assert_eq(world.camera.global_position, Vector2(320, 180))
	assert_eq(progress.visited, ["A"])
	assert_eq(spawned.size(), 1)

func test_walking_through_an_exit_slides_into_the_neighbour() -> void:
	_side_by_side()
	Input.action_press("move_right")
	await wait_physics_frames(3)  # the World runs before the player each frame: let the walk start first
	player.global_position = Vector2(641, 314)
	await wait_physics_frames(2)
	assert_true(world.sliding)
	assert_false(player.is_physics_processing())
	var frozen := player.global_position
	await wait_seconds(0.1)
	assert_eq(player.global_position, frozen)
	await wait_seconds(0.5)
	assert_eq(world.current_id, "B")
	assert_false(world.sliding)
	assert_eq(entered_velocity.x, 140.0)
	assert_eq(_rooms_alive(), 1)
	assert_eq(progress.visited, ["A", "B"])
	assert_true(world.current_rect().has_point(world.camera.global_position))

func test_turning_back_returns_cleanly() -> void:
	_side_by_side()
	player.global_position = Vector2(641, 314)
	await wait_seconds(0.6)
	player.global_position = Vector2(638, 314)
	await wait_seconds(0.6)
	assert_eq(world.current_id, "A")
	assert_eq(_rooms_alive(), 1)
	assert_eq(spawned.size(), 2)  # A's bat respawned on re-entry
	assert_false(is_instance_valid(spawned[0]))

func test_pausing_mid_slide_finishes_after_unpause() -> void:
	_side_by_side()
	player.global_position = Vector2(641, 314)
	await wait_physics_frames(2)
	get_tree().paused = true
	await get_tree().create_timer(0.6).timeout  # a SceneTreeTimer keeps running while paused; GUT's waits don't
	assert_true(world.sliding)
	get_tree().paused = false
	await wait_seconds(0.6)
	assert_false(world.sliding)
	assert_eq(world.current_id, "B")

func test_a_rope_is_dropped_when_you_change_rooms() -> void:
	_side_by_side()
	player.global_position = Vector2(600, 300)
	player.attach_rope(Vector2(560, 100), 200.0, 60.0, 1.0)
	player.global_position = Vector2(641, 314)
	await wait_seconds(0.6)
	assert_null(player.rope)

func test_entering_through_a_floor_pushes_you_up() -> void:
	spawned = []
	_world({
		"L": _room("L", Vector2i(0, 1), [{"edge": "top", "from": 280.0, "to": 360.0, "room": "U"}], {"start": Vector2(320, 310)}),
		"U": _room("U", Vector2i(0, 0), [{"edge": "bottom", "from": 280.0, "to": 360.0, "room": "L"}]),
	})
	player.global_position = Vector2(320, 355)
	player.velocity = Vector2(0, -100)
	await wait_seconds(0.6)
	assert_eq(world.current_id, "U")
	assert_lte(entered_velocity.y, World.ENTRY_BOOST)

func test_view_center_clamps_to_the_room() -> void:
	var rect := Rect2(0, 0, 1280, 360)
	assert_eq(World.view_center(rect, Vector2(10, 10)), Vector2(320, 180))
	assert_eq(World.view_center(rect, Vector2(1270, 300)), Vector2(960, 180))
	assert_eq(World.view_center(rect, Vector2(700, 100)), Vector2(700, 180))

func test_build_room_makes_walls_solids_and_spawns() -> void:
	var def := _room("R", Vector2i(1, 1), [{"edge": "right", "from": 200.0, "to": 320.0, "room": "X"}],
		{"solids": [Rect2(100, 266, 100, 12)], "spawns": [{"id": "toad", "pos": Vector2(300, 300)}]})
	spawned = []
	var node := RoomBuilder.build_room(def, {"spawn": _spawn})
	autofree(node)
	assert_eq(node.position, Vector2(640, 360))
	assert_eq(String(node.name), "R")
	var bodies := node.get_children().filter(func(n: Node) -> bool: return n is StaticBody2D)
	assert_eq(bodies.size(), RoomBuilder.edge_walls(def.pixel_size(), def.exits).size() + 1)
	assert_eq(spawned.size(), 1)

func test_a_closed_shortcut_is_gated() -> void:
	var def := _room("R", Vector2i(0, 0), [{"edge": "bottom", "from": 200.0, "to": 260.0, "room": "X", "shortcut": "s1"}])
	var p := WorldProgress.new()
	var closed := RoomBuilder.build_room(def, {"progress": p})
	autofree(closed)
	assert_eq(closed.get_children().filter(func(n: Node) -> bool: return n.is_in_group("gate_s1")).size(), 1)
	assert_false(RoomBuilder.is_exit_open(def.exits[0], p))
	p.open_shortcut("s1")
	var opened := RoomBuilder.build_room(def, {"progress": p})
	autofree(opened)
	assert_eq(opened.get_children().filter(func(n: Node) -> bool: return n.is_in_group("gate_s1")).size(), 0)
	assert_true(RoomBuilder.is_exit_open(def.exits[0], p))
