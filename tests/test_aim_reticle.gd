extends GutTest
## The aim reticle: where the pointer (right stick or mouse) aims, drawn over the body, shown only while a cast could fire.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var creature_list := DefLoader.load_dir("res://data/creatures")
	rules = autofree(SkillRulesEngine.new())
	rules.report_error = func(msg: String) -> void: fail_test(msg)
	rules.setup(skills)
	var compendium := CompendiumModel.new(skills, creature_list)
	CoreWiring.connect_core(rules, compendium, AnnouncerQueue.new())
	player = Player.new()
	player.setup(rules, compendium, creature_list, func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	PadInput.reset()

func _right(x: float, y: float) -> void:
	PadInput.axis(JOY_AXIS_RIGHT_X, x)
	PadInput.axis(JOY_AXIS_RIGHT_Y, y)

func _mouse_at(point: Vector2) -> void:
	player.pointer_override = point
	PadInput.mouse_move(Vector2(10, 0))

func _reticle() -> AimReticle:
	return player.get_node("AimReticle")

func _step() -> void:
	_reticle()._process(0.0)

func test_hidden_with_no_pointer() -> void:
	_step()
	assert_false(_reticle().visible)

func test_visible_and_rotated_to_the_stick() -> void:
	_right(0.0, -1.0)
	_step()
	assert_true(_reticle().visible)
	assert_almost_eq(_reticle().rotation, -PI / 2.0, 0.001)

func test_visible_and_rotated_to_the_cursor() -> void:
	_mouse_at(Vector2(0, 100))
	_step()
	assert_true(_reticle().visible)
	assert_almost_eq(_reticle().rotation, PI / 2.0, 0.001)

func test_scaled_by_the_forms_size_even_when_the_form_has_its_own_art() -> void:
	_right(1.0, 0.0)
	_step()
	assert_eq(_reticle().scale, Vector2.ONE, "a fresh slime")
	assert_true(player.advance_form("weaver", true))  # weaver: size 1.12 and its own sheet, so body_scale() is 1.0
	player._evolve_time = 0.0  # the evolve moment would hide the reticle
	assert_eq(player.body_scale(), 1.0)
	_step()
	assert_eq(_reticle().scale, Vector2.ONE * 1.12)

func test_hidden_whenever_a_cast_cannot_fire() -> void:
	_right(1.0, 0.0)
	player._channel = autofree(Ability.new())
	_step()
	assert_false(_reticle().visible, "a live channel: it is latched, so a live reticle would point elsewhere")
	player._channel = null
	_step()
	assert_true(_reticle().visible)
	player.health.take_hit(player.health.hp, "physical")
	_step()
	assert_false(_reticle().visible, "dead")

func test_it_does_not_hide_for_an_empty_slot() -> void:
	_right(1.0, 0.0)
	_step()
	assert_true(_reticle().visible, "no skill is even equipped")

func test_it_is_not_a_colorrect_and_not_a_vfx_node() -> void:
	var r: Node = _reticle()  # typed as a Node so the check is a runtime one (test_art_visuals forbids a ColorRect under the Player)
	assert_false(r is ColorRect)
	assert_false(r.is_in_group("vfx"))
