extends GutTest
## The Deep's creatures: the wolf is a charger without the armored front, the pack shares its alert, the drake stomps.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var grounded := true
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func receive_poison(_a: int, _t: int, _s: float) -> void:
		pass
	func is_on_floor() -> bool:
		return grounded

var creatures := {}
var skills_by_id := {}
var fake_player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	fake_player = StubPlayer.new()
	add_child_autofree(fake_player)
	fake_player.add_to_group("player")

## A floor whose top is y 6: an enemy at y 0 stands on it (its body bottom is 6 below its centre).
func _floor() -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(0, 16)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(4000, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _enemy(id: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	return e

func _def(flags: Dictionary) -> CreatureDef:
	var d := CreatureDef.new()
	d.id = "test_%s" % str(flags.keys()[0])
	d.stats = {"max_hp": 9, "atk": 1, "def": 0, "spd": 100}
	for k in flags:
		d.set(k, flags[k])
	return d

func _bare(d: CreatureDef) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(d, {})
	add_child_autofree(e)
	return e

func test_a_charges_def_is_a_charger_and_a_front_tackle_stuns_it() -> void:
	var e := _bare(_def({"charges": true}))
	assert_eq(e.kind, Enemy.Kind.CHARGER)
	assert_true(e.receive_tackle(1, false), "no armored front: a front tackle stuns")
	assert_eq(e.status.state, EnemyStatus.STUNNED)

func test_an_armored_charger_still_resists_a_front_tackle() -> void:
	var e := _bare(_def({"armored_charger": true}))
	assert_eq(e.kind, Enemy.Kind.CHARGER)
	assert_false(e.receive_tackle(1, false), "the armored front blocks it")
	assert_true(e.receive_tackle(1, true), "from behind it is stunned")

func test_a_wolf_that_sees_you_alerts_a_wolf_within_the_radius_and_not_one_beyond_or_an_ant() -> void:
	_floor()
	fake_player.global_position = Vector2(100, 0)
	var finder := _enemy("gloom_wolf", Vector2(0, 0))
	var near_mate := _enemy("gloom_wolf", Vector2(-150, 0))  # 250 from the player: it cannot see you itself, but it is 150 from its finder
	var far_mate := _enemy("gloom_wolf", Vector2(-300, 0))  # beyond the radius from the finder
	var ant := _enemy("armed_ant", Vector2(-100, 0))  # in range of the finder, but not of its kind
	await wait_physics_frames(5)
	assert_true(finder.is_alert(), "the finder sees you")
	assert_true(near_mate.is_alert(), "the howl reaches a packmate with no line of sight needed")
	assert_false(far_mate.is_alert(), "beyond PACK_RADIUS")
	assert_false(ant.is_alert(), "a wolf does not wake an ant")

func test_a_creature_woken_by_a_packmate_does_not_wake_another() -> void:
	_floor()
	fake_player.global_position = Vector2(100, 0)
	var finder := _enemy("gloom_wolf", Vector2(0, 0))
	var first := _enemy("gloom_wolf", Vector2(-200, 0))  # 200 from the finder
	var second := _enemy("gloom_wolf", Vector2(-420, 0))  # 220 from the first, 420 from the finder
	await wait_physics_frames(5)
	assert_true(first.is_alert())
	assert_false(second.is_alert(), "only sight calls the howl: the pack does not chain")
	assert_true(finder.is_alert())

func test_a_woken_mate_calms_down_after_its_finder_loses_sight() -> void:
	_floor()
	fake_player.global_position = Vector2(100, 0)
	var finder := _enemy("gloom_wolf", Vector2(0, 0))
	var mate := _enemy("gloom_wolf", Vector2(-150, 0))
	await wait_physics_frames(5)
	assert_true(mate.is_alert())
	fake_player.global_position = Vector2(3000, 0)  # out of every wolf's sight
	await wait_physics_frames(int(Enemy.ALERT_MEMORY * 60.0) + 12)
	assert_false(mate.is_alert(), "ALERT_MEMORY after the finder lost you")
	assert_false(finder.is_alert())

func test_the_actors_group_holds_things_that_are_not_enemies() -> void:
	_floor()
	fake_player.global_position = Vector2(100, 0)
	var imposter := Node2D.new()  # a shortcut switch or a stub: in `actors`, no `def`
	add_child_autofree(imposter)
	imposter.add_to_group("actors")
	imposter.global_position = Vector2(-50, 0)
	var finder := _enemy("gloom_wolf", Vector2(0, 0))
	await wait_physics_frames(5)
	assert_true(finder.is_alert(), "no error from the non-enemy, and the wolf still sees you")
