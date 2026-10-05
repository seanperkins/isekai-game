extends GutTest
## drain (a strike heals the caster), reveal (what is hidden shows) and bridge (a platform laid ahead).

class Actor extends Node2D:
	var team := "player"
	var facing := 1
	var health := Health.new(30)
	func apply_impulse(_v: Vector2) -> void:
		pass
	func receive_hit(_raw: int, _damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass

class Faller extends CharacterBody2D:
	func _physics_process(delta: float) -> void:
		velocity.y += 900.0 * delta
		move_and_slide()

var caster: Actor
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func before_each() -> void:
	caster = Actor.new()
	add_child_autofree(caster)
	caster.add_to_group("actors")

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("verb_bridges"):
		n.free()

func _foe(x: float) -> VerbArena.Foe:
	var f := VerbArena.Foe.new()
	add_child_autofree(f)
	f.add_to_group("actors")
	f.global_position = Vector2(x, 0)
	return f

func _verb(spec: Dictionary, value := 4) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(a)
	a.spec = spec
	a.setup(caster, [value], 1)
	return a

func _power(value: int) -> int:
	return Damage.skill_power(value, 1)

# --- drain ---

func test_a_drain_hit_heals_the_caster_by_a_fraction_of_the_damage() -> void:
	_foe(40)
	caster.health.hp = 10
	_verb({"kind": "bolt", "drain": 0.5}, 10).activate()
	assert_eq(caster.health.hp, 10 + maxi(1, int(_power(10) * 0.5)))

func test_a_drain_never_heals_above_the_maximum_and_heals_at_least_one() -> void:
	_foe(40)
	caster.health.hp = 29
	_verb({"kind": "bolt", "drain": 1.0}, 10).activate()
	assert_eq(caster.health.hp, 30, "capped")
	caster.health.hp = 10
	_verb({"kind": "bolt", "drain": 0.01}, 1).activate()
	assert_eq(caster.health.hp, 11, "at least 1 for a hit that drains")

func test_a_drain_heals_by_the_damage_actually_dealt_not_the_power() -> void:
	var crab := _enemy("mushroom_crab", Vector2(40, 0))
	crab.health.max_hp = 100
	crab.health.hp = 100
	caster.health.hp = 10
	_verb({"kind": "bolt", "drain": 0.5}, 10).activate()
	var dealt := 100 - crab.health.hp
	assert_lt(dealt, _power(10), "its armour took some")
	assert_eq(caster.health.hp, 10 + maxi(1, int(float(dealt) * 0.5)), "the fraction of what it lost")

func test_a_drain_on_an_almost_dead_enemy_heals_only_what_was_left() -> void:
	var crab := _enemy("mushroom_crab", Vector2(40, 0))
	crab.health.max_hp = 100
	crab.health.hp = 2
	caster.health.hp = 10
	_verb({"kind": "bolt", "drain": 1.0}, 20).activate()
	assert_eq(caster.health.hp, 12, "two points were left to take")

func test_a_drain_on_an_enemy_that_cannot_be_hit_heals_nothing() -> void:
	var lizard := _enemy("lizard", Vector2(40, 0))
	lizard.dormant = true
	caster.health.hp = 10
	_verb({"kind": "bolt", "drain": 1.0}, 20).activate()
	assert_eq(caster.health.hp, 10)
	assert_eq(lizard.health.hp, lizard.health.max_hp)

func test_a_drain_with_no_foe_heals_nothing() -> void:
	caster.health.hp = 10
	_verb({"kind": "bolt", "drain": 1.0}, 10).activate()
	assert_eq(caster.health.hp, 10)

func test_a_spec_without_drain_heals_nothing() -> void:
	_foe(40)
	caster.health.hp = 10
	_verb({"kind": "bolt"}, 10).activate()
	assert_eq(caster.health.hp, 10)

func test_a_delayed_mark_drains_when_it_lands() -> void:
	var foe := _foe(50)
	caster.health.hp = 10
	_verb({"kind": "mark", "delay": 0.1, "drain": 0.5}, 10).activate()
	await wait_seconds(0.3)
	assert_eq(foe.hits.size(), 1)
	assert_eq(caster.health.hp, 10 + maxi(1, int(_power(10) * 0.5)))

func test_a_delayed_mark_survives_its_caster_going_first() -> void:
	var foe := _foe(50)
	_verb({"kind": "mark", "delay": 0.1, "drain": 0.5}, 10).activate()
	caster.free()
	await wait_seconds(0.3)
	assert_eq(foe.hits.size(), 1, "it still lands, and nothing tried to heal a freed caster")

func test_a_mark_lays_a_marker_on_its_target() -> void:
	_foe(50)
	_verb({"kind": "mark", "delay": 5.0}).activate()
	assert_eq(get_tree().get_nodes_in_group("verb_marks").size(), 1)

# --- reveal ---

func test_reveal_calls_reveal_on_hidden_nodes_in_range_only() -> void:
	var near := VerbArena.Hidden.new()
	var far := VerbArena.Hidden.new()
	var plain := Node2D.new()
	for n in [near, far, plain]:
		add_child_autofree(n)
		n.add_to_group("hidden")
	near.global_position = Vector2(80, 0)
	far.global_position = Vector2(400, 0)
	plain.global_position = Vector2(20, 0)  # in group hidden but cannot be revealed: skipped
	_verb({"kind": "reveal", "radius": 120.0}).activate()
	assert_eq(near.revealed, 1)
	assert_eq(far.revealed, 0)

func test_reveal_with_nothing_hidden_does_nothing() -> void:
	assert_true(_verb({"kind": "reveal"}).activate())

# --- bridge ---

func test_a_bridge_lays_a_one_way_platform_ahead_that_a_body_can_stand_on_and_it_goes() -> void:
	caster.facing = 1
	_verb({"kind": "bridge", "length": 100.0, "seconds": 1.0}).activate()
	var bridges := get_tree().get_nodes_in_group("verb_bridges")
	assert_eq(bridges.size(), 1)
	var plank: StaticBody2D = bridges[0].get_child(0)
	assert_true(plank.get_child(0).one_way_collision)
	assert_gt(plank.global_position.x, 8.0, "ahead of the caster")
	var body := Faller.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(8, 8)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = Vector2(plank.global_position.x, -40.0)
	await wait_seconds(0.5)
	assert_lt(body.global_position.y, plank.global_position.y, "it rests on the plank")
	await wait_seconds(1.2)
	assert_eq(get_tree().get_nodes_in_group("verb_bridges").size(), 0, "and the bridge is gone")

func test_a_second_bridge_replaces_the_first() -> void:
	var a := _verb({"kind": "bridge", "seconds": 5.0})
	a.activate()
	a._process(5.0)
	a.activate()
	await wait_physics_frames(2)
	assert_eq(get_tree().get_nodes_in_group("verb_bridges").size(), 1)

func test_a_bridge_faces_the_way_the_caster_faces() -> void:
	caster.facing = -1
	_verb({"kind": "bridge", "length": 100.0}).activate()
	var plank: StaticBody2D = get_tree().get_nodes_in_group("verb_bridges")[0].get_child(0)
	assert_lt(plank.global_position.x, -8.0)

func test_validate_knows_drain_reveal_and_bridge() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "drain": 0.5})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "dash", "drain": 0.5})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "zone", "drain": 0.5})), ["zone: unknown key 'drain'"])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "drain": "lots"})), ["bolt: drain must be a number"])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "drain": -0.1})), ["bolt: drain must be from 0 to 1"])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "drain": 1.5})), ["bolt: drain must be from 0 to 1"])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "drain": 0})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "drain": 1})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "reveal", "radius": 100})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "bridge", "length": 120, "seconds": 10})), [])
