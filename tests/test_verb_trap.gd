extends GutTest
## The Tinker's Rig: a trap at the caster's feet that the first awake enemy to step on it springs.

class Hands extends Node2D:
	var team := "player"
	var facing := 1
	var deeds: Array = []
	func apply_impulse(_v: Vector2) -> void:
		pass
	func emit_deed(event_name: String, tags := {}) -> void:
		deeds.append([event_name, tags])

var skills_by_id := {}
var skills := {}
var caster: Hands

func before_all() -> void:
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	caster = Hands.new()
	add_child_autofree(caster)
	caster.add_to_group("actors")
	caster.add_to_group("player")

func after_each() -> void:
	for t in get_tree().get_nodes_in_group("verb_traps"):
		t.free()

func _ability(spec := {"kind": "trap"}, value := 4) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(a)
	a.spec = spec
	a.setup(caster, [value], 1)
	return a

func _traps() -> Array:
	return get_tree().get_nodes_in_group("verb_traps")

func _enemy(at: Vector2) -> Enemy:
	var d := TestDefs.creature("t_foe")
	d.stats = {"max_hp": 9, "atk": 1, "def": 0, "spd": 100}
	var e := Enemy.new()
	e.setup(d, skills_by_id)
	e.position = at
	add_child_autofree(e)
	return e

func _armed(trap: VerbTrap) -> void:
	trap._physics_process(VerbTrap.ARM_SECONDS + 0.1)

func test_a_cast_sets_a_trap_at_the_casters_feet() -> void:
	caster.global_position = Vector2(120, 40)
	VerbKinds.run(_ability(), {"kind": "trap"})
	assert_eq(_traps().size(), 1)
	assert_eq(_traps()[0].global_position, Vector2(120, 40))

func test_a_trap_does_nothing_until_it_is_armed() -> void:
	VerbKinds.run(_ability(), {"kind": "trap"})
	var e := _enemy(caster.global_position)
	_traps()[0]._physics_process(0.1)
	assert_eq(e.health.hp, 9)
	assert_eq(caster.deeds, [])
	assert_eq(_traps().size(), 1)

func test_an_awake_enemy_that_steps_on_it_is_hurt_stunned_and_the_deed_is_said() -> void:
	var a := _ability({"kind": "trap", "stun": 2.0}, 4)
	VerbKinds.run(a, {"kind": "trap", "stun": 2.0})
	var e := _enemy(caster.global_position)
	var trap: VerbTrap = _traps()[0]
	_armed(trap)
	assert_eq(e.health.hp, 9 - Damage.skill_power(4, 1))
	assert_eq(e.status.state, EnemyStatus.STUNNED)
	assert_eq(caster.deeds, [[Deeds.TRAP_SPRUNG, {}]])
	assert_true(trap.is_queued_for_deletion())

func test_two_enemies_on_it_spring_it_once() -> void:
	VerbKinds.run(_ability(), {"kind": "trap"})
	var a := _enemy(caster.global_position)
	var b := _enemy(caster.global_position)
	_armed(_traps()[0])
	assert_eq(caster.deeds.size(), 1)
	assert_eq([a, b].filter(func(e: Enemy) -> bool: return e.health.hp < 9).size(), 1)

func test_a_stunned_a_dormant_a_downed_or_a_far_enemy_springs_nothing() -> void:
	VerbKinds.run(_ability(), {"kind": "trap"})
	var stunned := _enemy(caster.global_position)
	stunned.status.stun(10.0)
	var dormant := _enemy(caster.global_position)
	dormant.dormant = true
	var downed := _enemy(caster.global_position)
	downed.receive_hit(999, "physical", Vector2.INF)
	downed.finish_dying()
	var far := _enemy(caster.global_position + Vector2(VerbTrap.REACH.x + 20.0, 0))
	_armed(_traps()[0])
	assert_eq(caster.deeds, [])
	assert_eq(_traps().size(), 1)
	assert_eq(far.health.hp, 9)

func test_the_caster_and_other_actors_do_not_spring_it() -> void:
	VerbKinds.run(_ability(), {"kind": "trap"})
	var friend := Hands.new()
	add_child_autofree(friend)
	friend.add_to_group("actors")
	friend.global_position = caster.global_position
	_armed(_traps()[0])
	assert_eq(caster.deeds, [])
	assert_eq(_traps().size(), 1)

func test_a_trap_that_stands_its_time_goes_quietly() -> void:
	VerbKinds.run(_ability(), {"kind": "trap", "seconds": 5.0})
	var trap: VerbTrap = _traps()[0]
	trap._physics_process(4.0)
	assert_false(trap.is_queued_for_deletion())
	trap._physics_process(2.0)
	assert_true(trap.is_queued_for_deletion())
	assert_eq(caster.deeds, [])

func test_a_fourth_trap_takes_the_place_of_the_oldest() -> void:
	var a := _ability()
	var spots := [Vector2(0, 0), Vector2(100, 0), Vector2(200, 0), Vector2(300, 0)]
	for p in spots:
		caster.global_position = p
		VerbKinds.run(a, {"kind": "trap"})
	assert_eq(_traps().size(), VerbKinds.TRAP_MAX)
	var xs := _traps().map(func(t: Node2D) -> float: return t.global_position.x)
	xs.sort()
	assert_eq(xs, [100.0, 200.0, 300.0], "the first is gone")

func test_traps_of_another_caster_are_not_taken() -> void:
	var other := Hands.new()
	add_child_autofree(other)
	other.add_to_group("actors")
	var oa: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(oa)
	oa.spec = {"kind": "trap"}
	oa.setup(other, [4], 1)
	for i in VerbKinds.TRAP_MAX:
		VerbKinds.run(oa, {"kind": "trap"})
	VerbKinds.run(_ability(), {"kind": "trap"})
	assert_eq(_traps().size(), VerbKinds.TRAP_MAX + 1)

# --- the kind and the Tinker's verb ---

func test_validate_accepts_a_trap_with_or_without_its_keys() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "trap"})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "trap", "seconds": 10.0, "stun": 1.0, "cooldown": 2.0})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "trap", "radius": 3})), ["trap: unknown key 'radius'"])
	assert_eq(Array(VerbKinds.validate({"kind": "trap", "stun": "long"})), ["trap: stun must be a number"])

func test_a_trap_is_not_a_kind_an_enemy_casts() -> void:
	assert_false(VerbKinds.ENEMY_KINDS.has("trap"))
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var twin := Enemy.new()
	twin.setup(creatures["twin_goblin_tinker"], skills_by_id)
	add_child_autofree(twin)
	assert_null(twin._build_verb(skills_by_id["verb_goblin_tinker"]), "the Tinker's twin has hands for nothing")

func test_the_tinkers_verb_is_the_trap() -> void:
	var sd: SkillDef = skills_by_id["verb_goblin_tinker"]
	assert_eq(SkillEffects.active_spec(sd), {"kind": "trap", "seconds": 30.0, "stun": 2.0, "cooldown": 2.0})
	assert_eq(sd.display_name, "Rig")
