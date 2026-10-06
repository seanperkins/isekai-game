extends GutTest
## The shipped world verbs that are keys on a kind (kraken, alkahest, hellhound, gabriel hound, cloud rider, chasm weaver, venomspinner, plaguemother, loom weaver).

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000
	player._invuln = 1000.0

func after_each() -> void:
	for g in ["verb_bridges", "verb_fields", "player_webs", "player_clouds", "verb_traps"]:
		for n in get_tree().get_nodes_in_group(g):
			n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func test_the_maelstrom_pulls_in_loose_parts_too() -> void:
	assert_true(arena.verb("kraken").spec["pickups"])

func test_alkahest_corrodes_what_you_carry() -> void:
	var gate := Node2D.new()
	gate.set_script(load("res://tests/support/fake_dissolvable.gd"))
	add_child_autofree(gate)
	gate.add_to_group("dissolvable")
	gate.global_position = Vector2(30, 0)
	var carried := player.parts_carried()
	arena.verb("alkahest").activate()
	assert_eq(gate.dissolved, 1)
	assert_eq(player.parts_carried(), carried - 1)

func test_fenrir_breaks_a_barrier() -> void:
	var barrier := RoomBarrier.new()
	barrier.setup({"id": "b", "pos": Vector2(60, 60), "w": 24.0, "h": 60.0}, {})
	add_child_autofree(barrier)
	await wait_physics_frames(2)
	arena.verb("wolf_fenrir").activate()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(barrier) and barrier.is_in_group("dissolvable"), "the wall is down")

func test_the_flame_trail_is_laid() -> void:
	arena.verb("wolf_hellhound").activate()
	assert_gte(get_tree().get_nodes_in_group("verb_fields").size(), 3)

func test_the_pack_carries_you_only_after_a_kill() -> void:
	var a := arena.verb("wolf_gabriel_hound")
	assert_false(a.ready())
	player.note_defeat(lizard)
	assert_true(a.ready())

func test_the_cloud_carries_you_sideways() -> void:
	assert_gt(float(arena.verb("cloud_rider").spec["drift"]), 0.0)

func test_the_span_needs_anchors_and_is_slow() -> void:
	player.global_position = Vector2(0, 0)
	var a := arena.verb("spider_chasm_weaver")
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("verb_bridges").size(), 0, "no ground at either end here")
	assert_true(player.is_held_still(), "slow to spin")

func test_the_venom_web_poisons_and_spreads() -> void:
	var a := arena.verb("spider_venomspinner")
	a.activate()
	assert_eq(get_tree().get_nodes_in_group("player_webs").size(), 1)
	assert_true(arena.verb("spider_venomspinner").spec["spreads"])

func test_the_plaguemother_leaves_a_cloud_where_she_dies() -> void:
	var f := load("res://data/forms/spider_plaguemother.tres") as FormDef
	assert_true(f.traits.has("miasma_death"))

func test_the_tapestry_stays_as_a_snare_and_is_slow() -> void:
	arena.verb("spider_loom_weaver").activate()
	assert_eq(get_tree().get_nodes_in_group("verb_traps").size(), 1)
	assert_true(player.is_held_still())
