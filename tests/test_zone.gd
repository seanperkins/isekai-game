extends GutTest
## The zone (SporeCloudArea): a lingering area the player leaves. It slows every frame, and once a second hurts (damage) and
## heals its caster (heals). Damage 0 never touches an enemy.

class StubActor extends Node2D:
	var team := "player"
	var facing := 1

class HealActor extends Node2D:
	var team := "player"
	var facing := 1
	var health := Health.new(10)

class FakeProgress extends RefCounted:
	var opened: Array = []
	func open_shortcut(id: String) -> void:
		opened.append(id)
	func is_open(_id: String) -> bool:
		return false

var actor: StubActor
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	actor = StubActor.new()
	add_child_autofree(actor)

func _toad(pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures["toad"], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	e.set_physics_process(false)  # no floor here: it would fall out of the zone
	return e

func _zone(at: Vector2, radius: float, seconds: float, opts := {}, who: Node2D = null) -> SporeCloudArea:
	var z := SporeCloudArea.new()
	add_child_autofree(z)
	z.launch(at, radius, seconds, who if who != null else actor, opts)
	return z

func test_a_fast_enemy_crossing_between_ticks_is_slowed() -> void:
	var toad := _toad(Vector2(-60, 0))
	_zone(Vector2.ZERO, 40.0, 4.0, {"damage": 0})
	assert_almost_eq(toad._speed(), Enemy.BASE_SPEED * toad.stats.get_stat("spd") / 100.0, 0.001, "not slowed before it enters")
	for i in 40:  # 180 px/s: inside from x -40 to +40 in frames 7..33, long before the one-second tick
		toad.position.x += 3.0
		await get_tree().physics_frame
	assert_lt(toad._speed(), Enemy.BASE_SPEED * toad.stats.get_stat("spd") / 100.0, "slowed without waiting for a tick")

func test_damage_zero_leaves_an_enemy_untouched() -> void:
	var toad := _toad(Vector2(10, 0))
	_zone(Vector2.ZERO, 40.0, 2.0, {"damage": 0})
	var hp := toad.health.hp
	await wait_physics_frames(130)
	assert_eq(toad.health.hp, hp)
	assert_eq(toad._hurt_t, 0.0, "no hit means no hurt timer")

func test_a_zone_ticks_once_per_whole_second_and_expires() -> void:
	for seconds in [1.0, 2.0, 3.0, 4.0]:
		var toad := _toad(Vector2(10, 0))
		toad.health.max_hp = 99
		toad.health.hp = 99
		var z := _zone(Vector2.ZERO, 40.0, seconds)
		await wait_physics_frames(int(seconds * 60.0) + 12)
		assert_eq(99 - toad.health.hp, int(seconds), "%s s zone ticks that many times" % seconds)
		assert_false(is_instance_valid(z) and z.is_inside_tree(), "%s s zone expired" % seconds)
		toad.queue_free()

func test_healing_heals_the_caster_only_inside_and_on_the_tick() -> void:
	var slime := HealActor.new()
	add_child_autofree(slime)
	slime.health.hp = 5
	_zone(Vector2.ZERO, 40.0, 3.0, {"damage": 0, "heals": 1}, slime)
	await wait_physics_frames(30)
	assert_eq(slime.health.hp, 5, "nothing before the first second")
	await wait_physics_frames(40)
	assert_eq(slime.health.hp, 6)
	slime.position = Vector2(200, 0)  # steps out
	await wait_physics_frames(60)
	assert_eq(slime.health.hp, 6)

func test_the_default_options_are_spore_clouds() -> void:
	var toad := _toad(Vector2(10, 0))
	_zone(Vector2.ZERO, 24.0, 2.0)  # the old four-argument call
	var hp := toad.health.hp
	await wait_physics_frames(72)
	assert_eq(toad.health.hp, hp - 1)
	assert_lt(toad._speed(), Enemy.BASE_SPEED * toad.stats.get_stat("spd") / 100.0, "slowed")

func test_a_no_slow_zone_does_not_slow() -> void:
	var toad := _toad(Vector2(10, 0))
	_zone(Vector2.ZERO, 40.0, 2.0, {"slow": false})
	await wait_physics_frames(30)
	assert_almost_eq(toad._speed(), Enemy.BASE_SPEED * toad.stats.get_stat("spd") / 100.0, 0.001)

func _switch(pos: Vector2, progress) -> ShortcutSwitch:
	var sw := ShortcutSwitch.new()
	add_child_autofree(sw)
	sw.setup({"shortcut": "c6_drop", "pos": pos}, {"progress": progress})
	return sw

## The cracked stone is an actor with receive_hit but no slow_for: a slowing zone must skip it without an error, and a
## damaging zone still opens it (that is how Spore Cloud opens the C6 shortcut).
func test_a_damaging_zone_still_opens_a_shortcut_switch_and_expires() -> void:
	var progress := FakeProgress.new()
	_switch(Vector2(10, 0), progress)
	var z := _zone(Vector2.ZERO, 40.0, 2.0)
	await wait_physics_frames(72)
	assert_eq(progress.opened, ["c6_drop"], "opened on the first tick")
	await wait_physics_frames(70)
	assert_false(is_instance_valid(z) and z.is_inside_tree(), "expired on time")

func test_a_slowing_zone_with_no_damage_leaves_a_shortcut_switch_alone_and_expires() -> void:
	var progress := FakeProgress.new()
	_switch(Vector2(10, 0), progress)
	var z := _zone(Vector2.ZERO, 40.0, 2.0, {"damage": 0})
	await wait_physics_frames(130)
	assert_eq(progress.opened, [], "damage 0 never hits it")
	assert_false(is_instance_valid(z) and z.is_inside_tree(), "expired on time")

func test_a_web_look_puts_a_web_sprite_where_the_square_was() -> void:
	var z := _zone(Vector2.ZERO, 40.0, 1.0, {"look": "web", "damage": 0})
	var s := z.get_child(0)
	assert_true(s is Sprite2D)
	assert_eq((s as Sprite2D).texture, VfxArt.web(80))
	var plain := _zone(Vector2.ZERO, 40.0, 1.0)
	assert_true(plain.get_child(0) is ColorRect, "no look keeps the square")
