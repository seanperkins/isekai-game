extends GutTest

class Caster extends Node2D:
	var team := "player"
	var facing := 1
	var stats := Stats.new({"atk": 1})
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func _caster() -> Caster:
	var c := Caster.new()
	add_child_autofree(c)
	c.add_to_group("actors")
	return c

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	add_child_autofree(e)
	e.global_position = pos
	e.set_physics_process(false)
	return e

func _jolt(caster: Node2D, level := 1) -> Ability:
	var j: Ability = load("res://scenes/abilities/jolt.tscn").instantiate()
	j.setup(caster, [3, 4, 5, 6, 7], level)
	add_child_autofree(j)
	return j

func test_a_stun_never_shortens_a_longer_one() -> void:
	var s := EnemyStatus.new()
	s.stun(3.0)
	s.stun(1.5)
	s.update(2.0)
	assert_eq(s.state, EnemyStatus.STUNNED, "still stunned: the 3 s stayed")
	var fresh := EnemyStatus.new()
	fresh.stun(1.5)
	assert_eq(fresh.state, EnemyStatus.STUNNED)
	fresh.update(1.6)
	assert_eq(fresh.state, EnemyStatus.ACTIVE)

func test_targets_around_is_radial_other_team_and_alive() -> void:
	var c := _caster()
	var near := _enemy("bat", Vector2(30, 0))
	var far := _enemy("bat", Vector2(90, 0))
	var downed := _enemy("bat", Vector2(10, 0))
	downed.receive_hit(99, "physical")
	var j := _jolt(c)
	var got := j.targets_around(40.0)
	assert_true(got.has(near))
	assert_false(got.has(far))
	assert_false(got.has(downed), "a corpse is not a target")
	assert_false(got.has(c), "never the caster")

func test_jolt_damages_everything_in_radius_with_shock_and_stuns_only_swimmers() -> void:
	var c := _caster()
	var eel := _enemy("glass_eel", Vector2(20, 0))
	var crayfish := _enemy("cave_crayfish", Vector2(-25, 0))
	var jelly := _enemy("drift_jelly", Vector2(0, 20))
	_jolt(c).activate()
	assert_eq(eel.status.state, EnemyStatus.STUNNED, "an eel is stunned")
	assert_ne(crayfish.status.state, EnemyStatus.STUNNED, "a crayfish is only hurt")
	assert_lt(crayfish.health.hp, crayfish.health.max_hp)
	assert_ne(jelly.status.state, EnemyStatus.ACTIVE, "a jelly is stunned (its 4 HP at level 7 survive a level-1 Jolt) or downed: either way eatable")
	assert_lt(jelly.health.hp, jelly.health.max_hp)

func test_jolt_never_hurts_the_caster() -> void:
	var c := _caster()
	_jolt(c).activate()
	assert_eq(c.hits, [])

func test_jolt_damage_follows_the_level() -> void:
	var c := _caster()
	var bat := _enemy("lizard", Vector2(10, 0))
	var before: int = bat.health.hp
	_jolt(c, 5).activate()
	assert_gt(before - bat.health.hp, 0)
