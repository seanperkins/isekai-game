extends GutTest
## Plan: boss arenas, Task 3. A dormant enemy is frozen where it spawned and refuses everything, and an awake one can be made to hunt.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_poison(_a: int, _t: int, _s: float) -> void:
		pass

## The Tremor test's caster: only the actors group and a stat block matter to the ability.
class Caster extends Node2D:
	var team := "player"
	var facing := 1
	var stats := Stats.new({"atk": 5})
	func receive_hit(_raw: int, _type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, 16)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)  # the floor: its top at y 6, so an enemy at y 0 stands on it

func _enemy(id: String, pos: Vector2, dormant := false, sheet := false) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = sheet
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	if dormant:
		e.dormant = true  # before it enters the tree
	add_child_autofree(e)
	return e

func test_the_default_is_awake_and_not_hunting() -> void:
	var e := _enemy("toad", Vector2.ZERO)
	assert_false(e.dormant)
	assert_false(e.hunting)

func test_a_dormant_enemy_does_not_move_or_fall() -> void:
	var e := _enemy("toad", Vector2(0, -60), true)
	await wait_physics_frames(60)
	assert_eq(e.global_position, Vector2(0, -60), "a toad above a floor would have fallen")
	assert_eq(e.velocity, Vector2.ZERO)

func test_a_dormant_enemy_refuses_damage_from_every_path() -> void:
	var e := _enemy("stone_drake", Vector2.ZERO, true)
	await wait_physics_frames(5)
	var hp := e.health.hp
	e.receive_hit(5, "physical", Vector2.INF, "other", true)
	assert_eq(e.health.hp, hp, "an area skill's direct hit")
	assert_false(e.receive_tackle(5, true))
	e.receive_thread(2)
	assert_eq(e.health.hp, hp)
	assert_eq(e.status.state, EnemyStatus.ACTIVE, "no stun from a tackle or a thread")
	assert_false(e.can_be_hit())

func test_the_tremor_ability_and_a_slow_leave_a_dormant_enemy_unchanged() -> void:
	var caster := Caster.new()
	add_child_autofree(caster)
	caster.add_to_group("actors")
	caster.global_position = Vector2(-30, 0)
	var drake := _enemy("stone_drake", Vector2.ZERO)
	await wait_physics_frames(5)  # it lands on the floor, so the ability counts it as grounded
	assert_true(drake.is_on_floor())
	drake.dormant = true
	var t: Ability = load("res://scenes/abilities/tremor.tscn").instantiate()
	t.setup(caster, [3, 4, 5, 6, 7], 1)
	add_child_autofree(t)
	t.activate()
	assert_eq(drake.health.hp, drake.health.max_hp)
	assert_eq(drake.status.state, EnemyStatus.ACTIVE, "the real ability leaves it alone")
	drake.slow_for(Enemy.SLOW_SECONDS)  # what a spore cloud calls
	drake.dormant = false
	assert_eq(drake._slow, 0.0, "no slow carried over to the wake")

func test_a_dormant_enemys_status_refuses_a_direct_stun() -> void:
	var e := _enemy("stone_drake", Vector2.ZERO, true)
	e.status.stun()  # the Tremor ability calls this itself after receive_hit, for any enemy it reaches
	assert_eq(e.status.state, EnemyStatus.ACTIVE)
	e.dormant = false
	e.status.stun()
	assert_eq(e.status.state, EnemyStatus.STUNNED, "and it stuns again once awake")

func test_a_dormant_enemy_cannot_be_predated() -> void:
	var e := _enemy("stone_drake", Vector2.ZERO, true)
	e.status.state = EnemyStatus.STUNNED  # even if something forced it
	assert_false(e.can_be_predated())
	e.dormant = false
	assert_true(e.can_be_predated())

func test_a_dormant_enemy_deals_no_contact_damage() -> void:
	var p := StubPlayer.new()
	add_child_autofree(p)
	p.add_to_group("player")
	p.global_position = Vector2(4, 0)
	var e := _enemy("lizard", Vector2.ZERO, true)
	await wait_physics_frames(30)
	assert_eq(p.hits.size(), 0)
	e.dormant = false
	await wait_physics_frames(30)
	assert_gt(p.hits.size(), 0, "awake it bites")

func test_dormancy_shows_the_resting_frame_set_before_or_after_entering_the_tree() -> void:
	var before := _enemy("taratect", Vector2(0, -100), true, true)
	await wait_physics_frames(3)
	assert_eq(before._anim_state, "hang", "set before it entered the tree")
	var later := _enemy("taratect", Vector2(200, -100), false, true)
	await wait_physics_frames(3)
	later._hurt_t = 1.0  # mid-flinch: the hurt pose is showing
	later._update_visual()
	assert_eq(later._anim_state, "hurt")
	later.dormant = true
	assert_eq(later._anim_state, "hang", "set while it was showing another pose")

func test_a_hunting_enemy_is_alert_to_a_player_far_outside_chase_range() -> void:
	var p := StubPlayer.new()
	add_child_autofree(p)
	p.add_to_group("player")
	p.global_position = Vector2(900, 0)
	var calm := _enemy("toad", Vector2.ZERO)
	var hunter := _enemy("toad", Vector2(0, 0))
	hunter.hunting = true
	await wait_physics_frames(10)
	assert_false(calm.is_alert(), "900 px is far outside CHASE_RANGE")
	assert_true(hunter.is_alert())

func test_waking_it_restores_everything() -> void:
	var e := _enemy("stone_drake", Vector2(0, -60), true)
	await wait_physics_frames(10)
	assert_eq(e.global_position.y, -60.0)
	e.dormant = false
	assert_true(e.can_be_hit())
	await wait_physics_frames(60)
	assert_gt(e.global_position.y, -60.0, "it falls to the floor again")
	var hp := e.health.hp
	e.receive_hit(3, "physical", Vector2.INF, "other", true)
	assert_lt(e.health.hp, hp)
