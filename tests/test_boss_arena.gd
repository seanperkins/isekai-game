extends GutTest
## Plan: boss arenas, Task 4. The arena node on real collision: it seals every exit of its room after the intro, wakes its boss, frees
## only its own gates when the boss is downed, and the world ignores exit transitions while it is locked.

class Dasher extends CharacterBody2D:
	var team := "player"
	var dash := 0.0
	func _ready() -> void:
		add_to_group("player")
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(28, 24)
		shape.shape = box
		add_child(shape)
	func _physics_process(_delta: float) -> void:
		velocity = Vector2(dash, 0.0)
		move_and_slide()

var creatures := {}
var skills_by_id := {}
var world: World
var player: Dasher
var events: Array = []

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _spawn(id: String, pos: Vector2) -> Node2D:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	return e

func _def(id: String, cell: Vector2i, size: Vector2i, exits: Array, extra := {}) -> RoomDef:
	var r := RoomDef.new()
	r.id = id
	r.area = "plain"
	r.cell = cell
	r.size = size
	r.exits = exits
	for k in extra:
		r.set(k, extra[k])
	return r

## ARENA: 2 screens wide at cell (1,0), one left door (span 240 to 320) to ANTE; the boss (a toad, for the test) far from the threshold.
func _rooms(arena_extra := {}) -> Dictionary:
	var arena := _def("ARENA", Vector2i(1, 0), Vector2i(2, 1), [{"edge": "left", "from": 240.0, "to": 320.0, "room": "ANTE"}], {
		"spawns": [{"id": "toad", "pos": Vector2(900, 300)}],
		"boss": {"creature": "toad", "threshold": Rect2(360, 200, 40, 120)},
	})
	for k in arena_extra:
		arena.set(k, arena_extra[k])
	var ante := _def("ANTE", Vector2i(0, 0), Vector2i(1, 1), [{"edge": "right", "from": 240.0, "to": 320.0, "room": "ARENA"}], {"start": Vector2(100, 310)})
	return {"ARENA": arena, "ANTE": ante}

## Builds the world in the arena (build_room adds the arena node) and returns it. The player starts at local `at`.
func _arena(at: Vector2, rooms := {}) -> BossArena:
	var defs := rooms if not rooms.is_empty() else _rooms()
	world = World.new()
	add_child_autofree(world)
	player = Dasher.new()
	world.setup(defs, player, {"spawn": _spawn, "progress": WorldProgress.new()})
	world.enter("ARENA")
	var def: RoomDef = defs["ARENA"]
	player.global_position = def.world_rect().position + at
	var arena: BossArena
	for n in world.room.get_children():
		if n is BossArena:
			arena = n
	assert_not_null(arena, "build_room adds the arena for a room with a boss")
	events = []
	EventBus.world_event.connect(_on_event)
	return arena

func _on_event(n: String, _t: Dictionary) -> void:
	if n.begins_with("boss_"):
		events.append(n)

func after_each() -> void:
	if EventBus.world_event.is_connected(_on_event):
		EventBus.world_event.disconnect(_on_event)

func _gates() -> Array:
	return world.room.get_children().filter(func(n: Node) -> bool: return n.is_in_group(BossArena.GATE_GROUP))

func _boss() -> Enemy:
	for n in world.room.get_children():
		if n is Enemy:
			return n
	return null

func test_ordinary_exits_have_no_gate_and_the_arena_adds_them_at_the_seal() -> void:
	var arena := _arena(Vector2(362, 290))  # on the threshold
	var probe := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(28, 24)
	shape.shape = box
	probe.add_child(shape)
	world.room.add_child(probe)
	probe.position = Vector2(60, 290)  # in front of the left door
	await wait_physics_frames(2)
	assert_false(probe.test_move(probe.global_transform, Vector2(-60, 0)), "the door is open before the seal")
	assert_eq(_gates().size(), 0)
	await wait_physics_frames(20)  # 0.33 s into the intro
	assert_eq(_gates().size(), 0, "not before 0.4 s")
	await wait_physics_frames(10)
	assert_eq(_gates().size(), 1, "one exit, one gate")
	assert_true(probe.test_move(probe.global_transform, Vector2(-60, 0)), "the door is shut")
	assert_true(arena.locked())

func test_the_threshold_is_the_only_trigger() -> void:
	var arena := _arena(Vector2(345, 290))  # the body spans x 331 to 359: 1 px short of the threshold at 360
	await wait_physics_frames(30)
	assert_eq(arena.model.state, BossArenaModel.State.WAITING)
	player.global_position += Vector2(2, 0)  # now it overlaps by 1 px
	await wait_physics_frames(5)
	assert_ne(arena.model.state, BossArenaModel.State.WAITING)

func test_the_boss_is_dormant_until_the_wake() -> void:
	var arena := _arena(Vector2(362, 290))
	var boss := _boss()
	assert_true(boss.dormant, "dormant from the moment the arena takes it")
	await wait_physics_frames(30)
	assert_eq(arena.model.state, BossArenaModel.State.INTRO)
	assert_true(boss.dormant)
	await wait_physics_frames(30)
	assert_eq(arena.model.state, BossArenaModel.State.FIGHT)
	assert_false(boss.dormant)
	assert_true(boss.hunting)

func test_the_gate_never_lands_on_the_player_and_the_player_cannot_leave_first() -> void:
	var arena := _arena(Vector2(362, 290))  # on the threshold, 342 px from the door
	player.dash = -700.0  # the Jet Dash, straight at the door
	var at_slam := [Vector2.INF]
	var on_slam := func(n: String, _t: Dictionary) -> void:
		if n == "boss_slam":
			at_slam[0] = player.global_position
	EventBus.world_event.connect(on_slam)
	await wait_physics_frames(90)
	EventBus.world_event.disconnect(on_slam)
	var gate := Rect2(world.room.global_position + Vector2(0, 240), Vector2(RoomDef.WALL, 80))
	var body := Rect2(at_slam[0] - Vector2(14, 12), Vector2(28, 24))
	assert_ne(at_slam[0], Vector2.INF, "the doors slammed")
	assert_false(gate.intersects(body), "the gate did not land on the dashing player")
	assert_eq(world.current_id, "ARENA", "no transition began")
	assert_false(world.sliding)
	assert_gte(player.global_position.x - world.room.global_position.x, RoomDef.WALL + 13.0, "stopped by the gate")
	assert_true(arena.locked())

func test_the_world_ignores_exit_transitions_while_the_arena_is_locked() -> void:
	var arena := _arena(Vector2(900, 290))
	arena.model.state = BossArenaModel.State.FIGHT
	player.global_position = world.room.global_position + Vector2(-5, 280)  # beyond the left door
	await wait_physics_frames(3)
	assert_eq(world.current_id, "ARENA")
	arena.model.state = BossArenaModel.State.WAITING
	player.global_position = world.room.global_position + Vector2(-5, 280)
	await wait_physics_frames(3)
	assert_eq(world.current_id, "ANTE", "an unlocked arena lets you leave")

func test_winning_frees_the_arena_gates_and_only_them() -> void:
	var rooms := _rooms()
	(rooms["ARENA"] as RoomDef).exits.append({"edge": "right", "from": 240.0, "to": 320.0, "room": "X", "shortcut": "S1"})
	var arena := _arena(Vector2(362, 290), rooms)
	await wait_physics_frames(60)
	assert_eq(arena.model.state, BossArenaModel.State.FIGHT)
	assert_eq(_gates().size(), 2, "both exits sealed (the shortcut one is closed anyway)")
	var boss := _boss()
	boss.downed.emit(boss.def)
	await wait_physics_frames(3)
	assert_eq(arena.model.state, BossArenaModel.State.WON)
	assert_eq(_gates().size(), 0, "the arena's gates are gone")
	assert_eq(world.room.get_children().filter(func(n: Node) -> bool: return n.is_in_group("gate_S1")).size(), 1, "the shortcut's gate stays")
	assert_false(arena.locked())

func test_the_events_reach_the_world_event_bus_in_order() -> void:
	_arena(Vector2(362, 290))
	await wait_physics_frames(60)
	var boss := _boss()
	boss.downed.emit(boss.def)
	await wait_physics_frames(3)
	assert_eq(events, ["boss_intro", "boss_slam", "boss_wake", "boss_defeated"])

func test_the_world_can_shake_the_camera_and_settles() -> void:
	_arena(Vector2(900, 290))
	world.shake(8.0, 0.2)
	var moved := false
	for _k in 8:
		await wait_physics_frames(1)
		moved = moved or world.camera.offset != Vector2.ZERO
	assert_true(moved)
	await wait_physics_frames(30)
	assert_eq(world.camera.offset, Vector2.ZERO)
	assert_true(world.ctx.has("shake"), "the arena finds it through ctx")

func test_the_gate_helper_parents_the_painted_art_and_freeing_the_gate_frees_it() -> void:
	var e := {"edge": "left", "from": 240.0, "to": 320.0, "room": "ANTE"}
	for area in ["deep", "plain"]:
		var def := _def("R", Vector2i.ZERO, Vector2i.ONE, [e], {})
		def.area = area
		var painted := TerrainArt.has_biome(area)
		var room := Node2D.new()
		add_child_autofree(room)
		var gate := RoomBuilder.make_gate(room, def, e, [], painted, "g")
		assert_true(gate.is_in_group("g"))
		assert_eq(gate.get_parent(), room)
		var extras := gate.get_children().filter(func(c: Node) -> bool: return not (c is CollisionShape2D))
		assert_eq(extras.size(), 1, "%s: one drawn thing, the art when painted and the tile when not" % area)
		var art: Node = extras[0]
		gate.free()
		assert_false(is_instance_valid(art), "%s: the art went with the gate" % area)
	assert_true(TerrainArt.has_biome("deep"), "the painted case was really tested")
