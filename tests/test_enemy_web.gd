extends GutTest
## A thread's mark on an enemy: a few strands while it slows, a full cocoon while it holds. Only a thread draws it: a
## spore cloud's slow and a tackle's stun do not.

var creatures := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _enemy(id: String) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], {})
	add_child_autofree(e)
	e.set_physics_process(false)  # stepped by hand so nothing moves it
	return e

func _cover(e: Enemy) -> WebCover:
	return e.get_node("WebCover")

func _step(e: Enemy, seconds: float = 0.02) -> void:
	e._physics_process(seconds)
	e._update_visual(seconds)

func _sized(e: Enemy, held: bool) -> Texture2D:
	return VfxArt.web_cover(Vector2i(e._sprite.texture.get_size()), held)

func test_a_fresh_enemy_wears_no_web() -> void:
	var e := _enemy("toad")
	assert_false(_cover(e).visible)

func test_a_slowing_thread_draws_a_few_strands() -> void:
	var e := _enemy("toad")
	e.receive_thread(1)
	_step(e)
	assert_true(_cover(e).visible)
	assert_eq(_cover(e).texture, _sized(e, false))

func test_a_holding_thread_draws_the_cocoon() -> void:
	var e := _enemy("toad")
	e.receive_thread(2)
	_step(e)
	assert_eq(e.status.state, EnemyStatus.STUNNED)
	assert_true(_cover(e).visible)
	assert_eq(_cover(e).texture, _sized(e, true))

func test_the_web_sits_on_the_sprite() -> void:
	var e := _enemy("toad")
	e.receive_thread(2)
	_step(e)
	assert_eq(_cover(e).position, e._sprite.position)

func test_a_thread_that_only_slows_an_enemy_that_cannot_be_stunned_draws_strands() -> void:
	var e := _enemy("serpent")
	e.receive_thread(2)
	_step(e)
	assert_eq(e.status.state, EnemyStatus.ACTIVE)
	assert_eq(_cover(e).texture, _sized(e, false), "it is slowed, not held, so it is not cocooned")

func test_a_zone_slow_draws_nothing() -> void:
	var e := _enemy("toad")
	e.slow_for(2.0)
	_step(e)
	assert_false(_cover(e).visible)

func test_a_tackle_stun_draws_nothing() -> void:
	var e := _enemy("bat")
	e.receive_tackle(1, false)
	_step(e)
	assert_eq(e.status.state, EnemyStatus.STUNNED)
	assert_false(_cover(e).visible)

func test_the_strands_go_when_the_slow_ends() -> void:
	var e := _enemy("toad")
	e.receive_thread(1)
	_step(e, 0.5)
	assert_true(_cover(e).visible)
	_step(e, 2.0)
	assert_false(_cover(e).visible)

func test_the_cocoon_goes_when_the_hold_ends() -> void:
	var e := _enemy("toad")
	e.receive_thread(2)
	_step(e)
	_step(e, EnemyStatus.STUN_SECONDS + 0.1)
	assert_eq(e.status.state, EnemyStatus.ACTIVE)
	assert_false(_cover(e).visible)

func test_a_later_tackle_stun_is_not_a_cocoon() -> void:
	var e := _enemy("toad")
	e.receive_thread(2)
	_step(e)
	_step(e, EnemyStatus.STUN_SECONDS + 0.1)
	e.receive_tackle(1, false)
	_step(e)
	assert_eq(e.status.state, EnemyStatus.STUNNED)
	assert_false(_cover(e).visible)

func test_a_held_enemy_that_slips_into_dying_sheds_the_web() -> void:
	var e := _enemy("toad")
	e.receive_thread(2)
	_step(e)
	e.receive_hit(99, "physical")
	_step(e)
	assert_false(_cover(e).visible)

func test_the_web_hides_with_the_sprite_while_the_enemy_is_being_eaten() -> void:
	var e := _enemy("toad")
	e.receive_thread(2)
	_step(e)
	assert_true(_cover(e).visible)
	var eat := EatCover.new()
	add_child_autofree(eat)
	eat.begin(e, SpriteSheet.load_set("slime"))
	e.set_held(true)  # a predate hold pauses the stun, so it is still held by the thread
	_step(e)
	assert_false(e._sprite.visible)
	assert_false(_cover(e).visible, "the eat draws its own shrinking copy: a full-size cocoon left over it would not shrink")
	eat.finish()
	e.set_held(false)
	_step(e)
	assert_true(_cover(e).visible, "and comes back if the eat is cancelled")
