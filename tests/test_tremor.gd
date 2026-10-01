extends GutTest
## Tremor: it slams the ground. Enemies standing on a floor near the caster take the skill's damage through their DEF and are stunned
## (all but the serpent, which takes the hit). Nothing in the air, nothing out of range, nothing that is not an enemy.

class Caster extends Node2D:
	var team := "player"
	var facing := 1
	var stats := Stats.new({"atk": 5})
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

## A shortcut switch's shape: an `actors` member on the terrain team whose receive_hit takes four arguments and that has no `def`.
class Switch extends Node2D:
	var team := "terrain"
	var hits := 0
	func receive_hit(_raw: int, _type: String, _from: Vector2, _cause: String) -> void:
		hits += 1

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

## A solid box whose top is at `top_y`, `width` wide centred on `x`.
func _platform(x: float, top_y: float, width: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x, top_y + 10.0)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(width, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _caster(pos := Vector2.ZERO) -> Caster:
	var c := Caster.new()
	add_child_autofree(c)
	c.add_to_group("actors")
	c.global_position = pos
	return c

## An enemy at `pos` with its physics running (no player exists, so it only falls and stands).
func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func _tremor(caster: Node2D, level := 1) -> Ability:
	var t: Ability = load("res://scenes/abilities/tremor.tscn").instantiate()
	t.setup(caster, [3, 4, 5, 6, 7], level)
	add_child_autofree(t)
	return t

func before_each() -> void:
	_platform(0.0, 6.0, 4000.0)  # the floor: top at y 6, so an enemy at y 0 stands on it

func test_the_scene_exists_and_casts() -> void:
	assert_true(ResourceLoader.exists("res://scenes/abilities/tremor.tscn"))

func test_it_hurts_a_grounded_enemy_through_its_defense_and_stuns_it() -> void:
	var c := _caster()
	var drake := _enemy("stone_drake", Vector2(30, 0))  # DEF 5
	await wait_physics_frames(5)
	assert_true(drake.is_on_floor())
	_tremor(c).activate()
	# ATK 5: skill_power(3, 5) = 6. Through DEF 5 a plain hit would do 2; ignoring DEF it does all 6.
	assert_eq(Damage.skill_power(3, 5), 6)
	assert_eq(drake.health.max_hp - drake.health.hp, 6)
	assert_eq(drake.status.state, EnemyStatus.STUNNED)

func test_the_damage_follows_the_level() -> void:
	var c := _caster()
	var drake := _enemy("stone_drake", Vector2(30, 0))
	await wait_physics_frames(5)
	_tremor(c, 3).activate()  # value 5 at level 3: skill_power(5, 5) = 10
	assert_eq(drake.health.max_hp - drake.health.hp, 10)

func test_it_skips_an_enemy_out_of_range() -> void:
	var c := _caster()
	var wolf := _enemy("gloom_wolf", Vector2(100, 0))  # beyond 72 px
	await wait_physics_frames(5)
	_tremor(c).activate()
	assert_eq(wolf.health.hp, wolf.health.max_hp)
	assert_eq(wolf.status.state, EnemyStatus.ACTIVE)

func test_it_skips_a_flier_in_the_air() -> void:
	var c := _caster()
	var bat := _enemy("bat", Vector2(30, -30))  # an active swooper has no gravity: it hangs in the air
	await wait_physics_frames(5)
	assert_false(bat.is_on_floor())
	_tremor(c).activate()
	assert_eq(bat.health.hp, bat.health.max_hp)

func test_it_hits_a_stunned_flier_that_has_fallen_to_the_floor() -> void:
	var c := _caster()
	var bat := _enemy("bat", Vector2(30, -30))
	bat.status.stun()  # a stunned bat falls
	await wait_physics_frames(60)
	assert_true(bat.is_on_floor())
	_tremor(c).activate()
	assert_lt(bat.health.hp, bat.health.max_hp)

func test_it_hits_an_enemy_standing_on_a_ledge_overhead() -> void:
	_platform(20.0, -45.0, 120.0)  # a ledge whose top is 45 above the floor line (y 6 - 51)
	var c := _caster()
	var crab := _enemy("mushroom_crab", Vector2(20, -52))
	await wait_physics_frames(10)
	assert_true(crab.is_on_floor())
	_tremor(c).activate()
	assert_lt(crab.health.hp, crab.health.max_hp, "any floor counts, a ledge included")

func test_it_hits_what_stands_below_a_caster_in_the_air() -> void:
	var c := _caster(Vector2(0, -40))
	var wolf := _enemy("gloom_wolf", Vector2(10, 0))
	await wait_physics_frames(5)
	_tremor(c).activate()
	assert_lt(wolf.health.hp, wolf.health.max_hp, "no caster condition")

func test_it_skips_a_shortcut_switch_without_error() -> void:
	var c := _caster()
	var sw := Switch.new()
	add_child_autofree(sw)
	sw.add_to_group("actors")
	sw.global_position = Vector2(10, 0)
	_tremor(c).activate()
	assert_eq(sw.hits, 0)

func test_the_serpent_takes_the_hit_and_is_never_stunned() -> void:
	var c := _caster()
	var serpent := _enemy("serpent", Vector2(30, 0))
	await wait_physics_frames(5)
	_tremor(c).activate()
	assert_lt(serpent.health.hp, serpent.health.max_hp)
	assert_eq(serpent.status.state, EnemyStatus.ACTIVE, "not predatable: it cannot be stunned")

func test_it_never_hurts_the_caster() -> void:
	var c := _caster()
	_enemy("gloom_wolf", Vector2(20, 0))
	await wait_physics_frames(5)
	_tremor(c).activate()
	assert_eq(c.hits, [])
