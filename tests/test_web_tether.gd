extends GutTest
## Hold Sticky Thread on an enemy: the tier applies at once (a tap is today's cast) and holding keeps re-applying it, up to
## 3 s, while the target is valid, hittable, in range and not behind rock.

class Double extends Node2D:
	var team := "player"
	var facing := 1
	var velocity := Vector2.ZERO
	var threads: Array = []
	var ropes: Array = []
	var hittable := true
	func apply_impulse(_v: Vector2) -> void:
		pass
	func receive_hit(_raw: int, _type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		pass
	func receive_thread(tier: int) -> void:
		threads.append(tier)
	func attach_rope(anchor: Vector2, _l: float, _r: float, _b: float) -> void:
		ropes.append(anchor)

class HittableDouble extends Double:
	func can_be_hit() -> bool:
		return hittable

var actor: Double

func before_each() -> void:
	actor = Double.new()
	add_child_autofree(actor)
	actor.add_to_group("actors")

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("vfx"):
		n.free()

func _solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _foe(pos: Vector2, hittable := false) -> Double:
	var e: Double = HittableDouble.new() if hittable else Double.new()
	e.team = "enemy"
	add_child_autofree(e)
	e.add_to_group("actors")
	e.global_position = pos
	return e

func _thread(id := "sticky_thread", aim := Vector2(1, 0), values := [1, 1, 2]) -> Ability:
	var a: Ability = load("res://scenes/abilities/%s.tscn" % id).instantiate()
	add_child_autofree(a)
	a.setup(actor, values, 1)
	a.aim = aim
	await wait_physics_frames(2)
	return a

func test_it_channels_only_when_an_enemy_is_the_first_contact() -> void:
	var a := await _thread()
	assert_false(a.can_channel(), "nothing in reach")
	var e := _foe(Vector2(50, 0))
	assert_true(a.can_channel())
	e.global_position = Vector2(500, 0)
	_solid(Rect2(60, -30, 10, 60))
	var wall_first := _foe(Vector2(100, 0))
	assert_false(a.can_channel(), "rock is nearer than the enemy behind it")
	wall_first.free()

func test_terrain_first_is_the_unchanged_one_shot_with_the_press_cooldown() -> void:
	_solid(Rect2(-50, -110, 100, 10))
	var a := await _thread("sticky_thread", Vector2(0, -1))
	assert_false(a.can_channel())
	assert_true(a.activate())
	assert_eq(actor.ropes.size(), 1)
	assert_false(a.ready(), "the cooldown runs from the press")

func test_evolved_threads_never_channel() -> void:
	_foe(Vector2(50, 0))
	for id in ["swing_thread", "binding_web"]:
		var a := await _thread(id, Vector2(1, 0), [2])
		assert_false(a.can_channel(), id)

func test_begin_applies_the_tier_at_once_and_flashes_like_a_tap() -> void:
	var e := _foe(Vector2(50, 0))
	var a := await _thread()
	a.begin_channel()
	assert_eq(e.threads, [1])
	assert_eq(get_tree().get_nodes_in_group("vfx").filter(func(n): return n is Line2D).size(), 1, "the 0.35 s flash")

func test_each_tick_reapplies_the_tier() -> void:
	var e := _foe(Vector2(50, 0))
	var a := await _thread()
	a.begin_channel()
	for i in 3:
		assert_true(a.channel_tick(0.016))
	assert_eq(e.threads, [1, 1, 1, 1])

func test_it_ends_when_the_target_leaves_range_or_hides_behind_rock_or_is_freed() -> void:
	var e := _foe(Vector2(50, 0))
	var a := await _thread()
	a.begin_channel()
	e.global_position = Vector2(150, 0)  # 120 + 20 = 140 is the limit
	assert_false(a.channel_tick(0.016), "out of range")
	e.global_position = Vector2(50, 0)
	assert_true(a.channel_tick(0.016))
	_solid(Rect2(20, -30, 10, 60))
	assert_false(a.channel_tick(0.016), "rock between")
	var f := _foe(Vector2(50, 40))
	var b := await _thread("sticky_thread", Vector2(0.8, 0.6).normalized())
	b.begin_channel()
	f.free()
	assert_false(b.channel_tick(0.016), "freed")

func test_a_downed_target_ends_it_and_a_double_without_can_be_hit_counts_as_hittable() -> void:
	var e: HittableDouble = _foe(Vector2(50, 0), true)
	var a := await _thread()
	a.begin_channel()
	assert_true(a.channel_tick(0.016))
	e.hittable = false
	assert_false(a.channel_tick(0.016))
	var plain := _foe(Vector2(50, 40))
	var b := await _thread("sticky_thread", Vector2(0.8, 0.6).normalized())
	b.begin_channel()
	assert_true(b.channel_tick(0.016), "no can_be_hit method: hittable")

# --- through a real Player ---

var rules: SkillRulesEngine
var events: Array
var player: Player

func _real_player() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	events = []
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	for i in 3:
		rules.handle_event("absorbed", {"essence": "thread", "source": "spider"})  # Sticky Thread, slot 0
	player.global_position = Vector2.ZERO
	player.set_physics_process(true)

func _real_enemy(x: float) -> Enemy:
	var e := Enemy.new()
	e.setup(DefLoader.load_dir("res://data/creatures").filter(func(c): return c.id == "toad")[0], {})
	add_child_autofree(e)
	e.global_position = Vector2(x, 0)
	e.set_physics_process(false)
	return e

func after_all() -> void:
	Input.action_release("active_1")

func test_a_hold_stuns_the_enemy_shows_the_strand_and_ends_at_three_seconds() -> void:
	_real_player()
	var toad := _real_enemy(60)
	Input.action_press("active_1")
	await wait_physics_frames(4)
	var ability: Ability = player._abilities["sticky_thread"]
	var strand: Line2D = ability.get_children().filter(func(n): return n is Line2D)[0]
	assert_true(strand.visible)
	assert_false(strand.is_in_group("vfx"))
	assert_eq(strand.texture, VfxArt.silk())
	assert_almost_eq(strand.points[strand.points.size() - 1].x, toad.global_position.x, 1.0, "redrawn after the physics step")
	await wait_seconds(3.3)
	assert_null(player._channel, "capped at 3.0 s")
	assert_false(strand.visible)
	assert_eq(events.filter(func(e): return e[0] == "mana_spent").size(), 3 + 6, "the start cost and six beats")
	Input.action_release("active_1")

func test_the_cooldown_still_runs_after_a_channel_and_recasting_works() -> void:
	_real_player()
	_real_enemy(60)
	Input.action_press("active_1")
	await wait_physics_frames(3)
	Input.action_release("active_1")
	await wait_physics_frames(3)
	var mp := player.mana.mp
	Input.action_press("active_1")
	await wait_physics_frames(3)
	assert_null(player._channel, "inside the 0.8 s after release: nothing")
	assert_eq(player.mana.mp, mp)
	Input.action_release("active_1")
	await wait_seconds(0.9)
	Input.action_press("active_1")
	await wait_physics_frames(3)
	assert_not_null(player._channel, "after 0.8 s the Sticky Thread cooldown has expired (its _process calls super)")
	Input.action_release("active_1")

func test_a_tier_two_hold_stuns_a_real_enemy_and_keeps_it_stunned() -> void:
	var toad := _real_enemy(60)
	var a := await _thread("sticky_thread", Vector2(1, 0), [2])
	a.begin_channel()
	assert_eq(toad.status.state, EnemyStatus.STUNNED, "tier 2 holds at once")
	for i in 30:
		assert_true(a.channel_tick(0.05))
	assert_eq(toad.status.state, EnemyStatus.STUNNED)
	assert_true(toad._web_hold, "and is cocooned while it is")
