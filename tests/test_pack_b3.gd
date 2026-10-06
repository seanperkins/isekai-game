extends GutTest
## Hands up (items, tools and a bow), a giant that burrows first and needs room to grow, and a wall of web.

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
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("verb_walls"):
		n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _verb(spec: Dictionary) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [4], 1)
	return a

func test_a_body_that_needs_hands_uses_items_only_with_them_up() -> void:
	player.skillset.capabilities["trait_needs_hands"] = 1
	assert_false(player.can_use_items())
	player.rage_start({"toggle": true, "hands": true, "stats": {"atk": 1}}, "verb_hands")
	assert_true(player.can_use_items(), "hands up")
	player.rage.stop()
	assert_false(player.can_use_items())

func test_a_body_without_the_trait_uses_items_as_ever() -> void:
	assert_true(player.can_use_items())

func test_casting_again_with_the_hands_up_shoots_the_bow() -> void:
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	lizard.global_position = Vector2(900, 0)  # the real lizard is in the way otherwise
	arena.foes[0].global_position = Vector2(100, 0)
	var spec := {"kind": "rage", "toggle": true, "hands": true, "stats": {"atk": 1}, "recast": {"kind": "bolt", "range": 220.0, "half_width": 10.0, "pierce": false}}
	var a := _verb(spec)
	a.activate()
	assert_true(player.rage.active(), "hands up")
	assert_eq(arena.foes[0].hits.size(), 0, "no shot yet")
	a._cooldown = 0.0
	a.activate()
	assert_true(player.rage.active(), "hands stay up")
	assert_eq(arena.foes[0].hits.size(), 1, "the second cast is an arrow")

func test_a_giant_is_bigger_burrows_first_and_gives_up_the_size_after() -> void:
	var scale := player.body_scale()
	player.rage_start({"seconds": 0.4, "size": 1.5, "burrow": 0.3, "stats": {"atk": 1}}, "verb_giant")
	assert_almost_eq(player.body_scale(), scale * 1.5, 0.001)
	assert_true(player.is_unseen(), "burrowed")
	assert_true(player.is_held_still())
	await wait_seconds(0.7)
	assert_almost_eq(player.body_scale(), scale, 0.001, "small again")

func test_a_verb_that_needs_headroom_is_not_ready_in_a_low_place() -> void:
	player.global_position = Vector2(-200, 0)
	var a := _verb({"kind": "rage", "seconds": 5.0, "needs_headroom": 50.0})
	assert_true(a.ready(), "open air")
	var ceiling := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200, 10)
	shape.shape = rect
	ceiling.add_child(shape)
	ceiling.position = Vector2(-200, -30)
	add_child_autofree(ceiling)
	await wait_physics_frames(2)
	assert_false(a.ready(), "too big for a small gap")

func test_a_web_wall_holds_each_enemy_that_crosses_it_once() -> void:
	player.global_position = Vector2(-300, 0)
	lizard.global_position = Vector2(-240, 0)
	_verb({"kind": "burst", "range": 10.0, "wall": {"ahead": 30.0, "height": 60.0, "seconds": 5.0, "root": 1.0}}).activate()
	assert_eq(get_tree().get_nodes_in_group("verb_walls").size(), 1)
	lizard.global_position = Vector2(-270, 0)
	await wait_physics_frames(3)
	assert_true(lizard.is_rooted(), "caught")

func test_the_new_keys_validate() -> void:
	for spec in [{"kind": "rage", "toggle": true, "hands": true, "recast": {"kind": "bolt", "range": 200}}, {"kind": "rage", "seconds": 8, "size": 1.5, "burrow": 1.0,
			"needs_headroom": 48, "summon": {"count": 2, "look": "spider"}}, {"kind": "burst", "wall": {"height": 60, "seconds": 8, "root": 1.5}}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
