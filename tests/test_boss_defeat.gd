extends GutTest
## Plan: boss arenas, Task 5. A boss stays defeated, a lost fight rebuilds the arena waiting, and the Bestiary hears of the kill before
## the profile does.

class Dasher extends CharacterBody2D:
	var team := "player"
	func _ready() -> void:
		add_to_group("player")
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(28, 24)
		shape.shape = box
		add_child(shape)

## Notes the order a profile is written in, against what the test logs before it.
class LogProfile extends Profile:
	var log: Array = []
	func save() -> bool:
		log.append("profile")
		return super.save()

var creatures := {}
var skills_by_id := {}
var world: World
var player: Dasher
var progress: WorldProgress
var order: Array = []
var dir: String

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	dir = "user://test_boss_defeat_%d" % Time.get_ticks_usec()
	order = []

func after_each() -> void:
	var abs := ProjectSettings.globalize_path(dir)
	if DirAccess.dir_exists_absolute(abs):
		for f in DirAccess.get_files_at(abs):
			DirAccess.remove_absolute(abs.path_join(f))
		DirAccess.remove_absolute(abs)

## The game's spawn: the Bestiary's listener is connected before the room can add anything of its own.
func _spawn(id: String, pos: Vector2) -> Node2D:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	e.downed.connect(func(_d: CreatureDef) -> void: order.append("bestiary"))
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

func _rooms() -> Dictionary:
	var arena := _def("ARENA", Vector2i(1, 0), Vector2i(2, 1), [{"edge": "left", "from": 240.0, "to": 320.0, "room": "ANTE"}], {
		"spawns": [{"id": "toad", "pos": Vector2(900, 300)}],
		"boss": {"creature": "toad", "threshold": Rect2(360, 200, 40, 120)},
	})
	var ante := _def("ANTE", Vector2i(0, 0), Vector2i(1, 1), [{"edge": "right", "from": 240.0, "to": 320.0, "room": "ARENA"}], {"start": Vector2(100, 310)})
	return {"ARENA": arena, "ANTE": ante}

func _world(profile: Profile = null) -> void:
	progress = WorldProgress.new(profile)
	world = World.new()
	add_child_autofree(world)
	player = Dasher.new()
	world.setup(_rooms(), player, {"spawn": _spawn, "progress": progress})
	world.enter("ARENA")
	player.global_position = world.room.global_position + Vector2(900, 290)  # well away from the threshold

func _arena() -> BossArena:
	for n in world.room.get_children():
		if n is BossArena:
			return n
	return null

func _boss() -> Enemy:
	for n in world.room.get_children():
		if n is Enemy:
			return n
	return null

func _fight() -> BossArena:
	player.global_position = world.room.global_position + Vector2(362, 290)
	await wait_physics_frames(60)
	return _arena()

func test_a_defeated_boss_is_not_spawned_and_the_room_has_no_arena() -> void:
	progress = WorldProgress.new()
	progress.defeat_boss("toad")
	world = World.new()
	add_child_autofree(world)
	player = Dasher.new()
	world.setup(_rooms(), player, {"spawn": _spawn, "progress": progress})
	world.enter("ARENA")
	assert_null(_boss(), "no boss")
	assert_null(_arena(), "no arena")
	assert_eq(world.room.get_children().filter(func(n: Node) -> bool: return n.is_in_group(BossArena.GATE_GROUP)).size(), 0)

func test_an_undefeated_boss_is_a_full_health_dormant_spawn_every_time_the_room_is_built() -> void:
	_world()
	var arena := await _fight()
	assert_eq(arena.model.state, BossArenaModel.State.FIGHT)
	var boss := _boss()
	assert_false(boss.dormant)
	boss.health.take_hit(Damage.hit(1, "physical", 0, 0, 0), "physical")  # a lost fight, in short: the boss is hurt and the player dies
	assert_lt(boss.health.hp, boss.health.max_hp)
	world.enter("ARENA")  # the next life: the room is built again
	var fresh := _boss()
	assert_not_same(fresh, boss)
	assert_eq(fresh.health.hp, fresh.health.max_hp, "full health")
	assert_true(fresh.dormant)
	assert_eq(_arena().model.state, BossArenaModel.State.WAITING)
	await wait_physics_frames(2)
	assert_eq(world.room.get_children().filter(func(n: Node) -> bool: return n.is_in_group(BossArena.GATE_GROUP)).size(), 0, "no doors carried over")

func test_the_bestiary_defeat_is_recorded_before_the_profile() -> void:
	var profile := LogProfile.new(dir.path_join("profile.json"))
	profile.reload()
	profile.log = order  # one shared list: the bestiary listener and the profile write both append to it
	_world(profile)
	order.clear()
	var arena := await _fight()
	var boss := _boss()
	boss.receive_hit(9999, "physical", Vector2.INF, "other", true)  # a lethal hit: _on_died emits downed
	await wait_physics_frames(4)
	assert_eq(arena.model.state, BossArenaModel.State.WON)
	assert_eq(order, ["bestiary", "profile"], "the Bestiary first, the profile on the next tick")
	assert_true(progress.is_defeated("toad"))

func test_stopping_between_the_two_leaves_the_boss_alive() -> void:
	var profile := Profile.new(dir.path_join("profile.json"))
	profile.reload()
	_world(profile)
	await _fight()
	var boss := _boss()
	boss.downed.emit(boss.def)  # the Bestiary has heard; the arena has not yet recorded it
	var reloaded := Profile.new(dir.path_join("profile.json"))
	reloaded.reload()  # what the next launch would read from disk
	var after_a_stop := WorldProgress.new(reloaded)
	assert_false(after_a_stop.is_defeated("toad"), "nothing written yet")
	var again := World.new()
	add_child_autofree(again)
	again.setup(_rooms(), Dasher.new(), {"spawn": _spawn, "progress": after_a_stop})
	again.enter("ARENA")
	assert_eq(again.room.get_children().filter(func(n: Node) -> bool: return n is Enemy).size(), 1, "the boss is there to fight again")

func test_a_predatable_boss_wins_on_downed_not_on_being_eaten() -> void:
	_world()
	var arena := await _fight()
	var boss := _boss()
	assert_true(boss.def.predatable)
	boss.receive_hit(9999, "physical", Vector2.INF, "other", true)
	await wait_physics_frames(4)
	assert_eq(arena.model.state, BossArenaModel.State.WON, "its lethal hit emitted downed through _on_died")
	assert_eq(world.room.get_children().filter(func(n: Node) -> bool: return n.is_in_group(BossArena.GATE_GROUP)).size(), 0)
	boss.consume()  # the player eats the corpse afterwards
	await wait_physics_frames(2)
	assert_eq(arena.model.state, BossArenaModel.State.WON, "eating it changes nothing")

func test_the_editor_preview_builds_a_boss_room_with_no_progress_and_no_spawner() -> void:
	var def: RoomDef = _rooms()["ARENA"]
	var node := RoomBuilder.build_room(def, {"progress": null})
	add_child_autofree(node)
	assert_eq(node.get_children().filter(func(n: Node) -> bool: return n is Enemy or n is BossArena).size(), 0)
