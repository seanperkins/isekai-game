extends GutTest
## Tackling the cracked stone in the nook breaks the floor open for good: the gate goes, the
## exit opens, and later builds of the room have neither gate nor switch.

var rules: SkillRulesEngine
var player: Player
var world: World
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
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	progress = WorldProgress.new()
	var rooms := {
		"T": _room("T", Vector2i(0, 0), [{"edge": "bottom", "from": 200.0, "to": 260.0, "room": "B", "shortcut": "s1"}],
			{"start": Vector2(320, 310), "features": [{"kind": "switch", "id": "sw", "shortcut": "s1", "pos": Vector2(290, 320)}]}),
		"B": _room("B", Vector2i(0, 1), [{"edge": "top", "from": 200.0, "to": 260.0, "room": "T", "shortcut": "s1"}]),
	}
	assert_eq("\n".join(WorldValidator.validate(rooms)), "")
	world = World.new()
	add_child_autofree(world)
	world.setup(rooms, player, {"progress": progress})
	rules.start_run()
	world.enter_start()

func _gates() -> int:
	return world.room.get_children().filter(func(n: Node) -> bool: return n.is_in_group("gate_s1") and not n.is_queued_for_deletion()).size()

func test_the_gate_holds_until_the_switch_is_tackled() -> void:
	assert_eq(_gates(), 1)
	assert_true(world.exit_beyond(Vector2(230, 365)).is_empty())
	player.facing = -1
	player.do_tackle()
	assert_true(progress.is_open("s1"))
	await wait_physics_frames(1)
	assert_eq(_gates(), 0)
	assert_false(world.exit_beyond(Vector2(230, 365)).is_empty())

func test_an_opened_shortcut_stays_open_in_later_builds() -> void:
	progress.open_shortcut("s1")
	world.enter("T")
	await wait_physics_frames(1)
	assert_eq(_gates(), 0)
	assert_eq(world.room.get_children().filter(func(n: Node) -> bool: return n is ShortcutSwitch).size(), 0)

func test_dropping_through_the_opened_floor_changes_rooms() -> void:
	progress.open_shortcut("s1")
	player.global_position = Vector2(230, 365)
	await wait_seconds(0.6)
	assert_eq(world.current_id, "B")
