extends GutTest
## Eating covers the prey: the slime drapes over it, the prey shrinks inside, and the prey is always
## visible again afterwards, however the hold ends.

var sheet: SpriteSheet

func before_all() -> void:
	sheet = SpriteSheet.load_set("slime")

func _prey() -> Node2D:
	var prey := Node2D.new()
	prey.position = Vector2(100, 50)
	prey.add_child(Art.sprite("bat_1", 6.0))
	add_child_autofree(prey)
	return prey

func _cover(prey: Node2D) -> EatCover:
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey, sheet)
	return cover

func test_the_frame_follows_the_progress() -> void:
	assert_eq(EatCover.cover_frame(0.0, 0.0), "cover_1")
	assert_eq(EatCover.cover_frame(0.15, 0.0), "cover_2")
	assert_eq(EatCover.cover_frame(0.5, 0.0), "cover_3")
	assert_eq(EatCover.cover_frame(0.5, EatCover.ENGULF_SECONDS), "cover_4")
	assert_eq(EatCover.cover_frame(0.5, EatCover.ENGULF_SECONDS * 2.0), "cover_3")
	assert_eq(EatCover.cover_frame(0.95, 0.0), "cover_5")
	assert_eq(EatCover.cover_frame(1.0, 9.0), "cover_5")

func test_it_hides_the_prey_and_draws_a_shrinking_copy_under_a_translucent_slime() -> void:
	var prey := _prey()
	var cover := _cover(prey)
	assert_false(prey.get_node("Sprite").visible)
	assert_almost_eq(cover.cover.modulate.a, EatCover.BODY_ALPHA, 0.001)
	assert_eq(cover.prey_copy.texture, prey.get_node("Sprite").texture)
	cover.tick(0.016, 0.0)
	assert_almost_eq(cover.prey_copy.scale.x, 1.0, 0.001)
	cover.tick(0.016, 1.0)
	assert_almost_eq(cover.prey_copy.scale.x, EatCover.PREY_MIN_SCALE, 0.001)
	assert_lt(cover.prey_copy.z_index, cover.cover.z_index)

func test_the_cover_sprite_changes_frame_with_the_progress() -> void:
	var cover := _cover(_prey())
	cover.tick(0.016, 0.05)
	assert_eq(cover.cover.texture, sheet.frame_texture("cover_1"))
	cover.tick(0.016, 0.95)
	assert_eq(cover.cover.texture, sheet.frame_texture("cover_5"))

func test_the_cover_sits_on_the_prey_and_follows_it() -> void:
	var prey := _prey()
	var cover := _cover(prey)
	var s: Sprite2D = prey.get_node("Sprite")
	var bottom := s.position.y + s.texture.get_height() / 2.0
	assert_almost_eq(cover.global_position.x, prey.global_position.x, 0.001)
	assert_almost_eq(cover.global_position.y, prey.global_position.y + bottom, 0.001)
	prey.global_position += Vector2(0, 20)  # a stunned bat falling
	cover.tick(0.016, 0.5)
	assert_almost_eq(cover.global_position.y, prey.global_position.y + bottom, 0.001)

func test_the_copy_keeps_the_prey_upside_down_when_it_is_downed() -> void:
	var prey := _prey()
	prey.get_node("Sprite").flip_v = true
	prey.get_node("Sprite").modulate = Color(0.6, 0.6, 0.85)
	var cover := _cover(prey)
	assert_true(cover.prey_copy.flip_v)
	assert_eq(cover.prey_copy.modulate, Color(0.6, 0.6, 0.85))

func test_the_cover_mirrors_when_the_prey_is_to_the_left() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey, sheet, true)
	assert_true(cover.cover.flip_h)

func test_finishing_restores_the_prey() -> void:
	var prey := _prey()
	var cover := EatCover.new()
	add_child(cover)
	cover.begin(prey, sheet)
	cover.finish()
	assert_true(prey.get_node("Sprite").visible)
	await wait_process_frames(2)
	assert_false(is_instance_valid(cover))

func test_a_freed_prey_does_not_break_the_cover() -> void:
	var prey := _prey()
	var cover := _cover(prey)
	prey.free()
	cover.tick(0.016, 0.5)
	cover.finish()
	pass_test("no crash")

func _player_with_toad() -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var player := Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(_n: String, _t: Dictionary) -> void: pass)
	add_child_autofree(player)
	rules.start_run()
	var skills := {}
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d
	var enemy := Enemy.new()
	for c in DefLoader.load_dir("res://data/creatures"):
		if c.id == "toad":
			enemy.setup(c, skills)
	enemy.position = Vector2(24, 6)
	add_child_autofree(enemy)
	enemy.status.stun()
	return [player, enemy]

func test_the_player_covers_prey_while_eating_and_uncovers_on_cancel() -> void:
	var pair := _player_with_toad()
	var player: Player = pair[0]
	var enemy: Enemy = pair[1]
	player.begin_predate()
	assert_true(player.predation.active())
	assert_not_null(player._cover)
	assert_false(player.get_node("Sprite").visible)
	assert_false(enemy.get_node("Sprite").visible)
	player.cancel_predate()
	assert_null(player._cover)
	assert_true(player.get_node("Sprite").visible)
	assert_true(enemy.get_node("Sprite").visible)

func test_dying_while_eating_uncovers_the_prey() -> void:
	var pair := _player_with_toad()
	var player: Player = pair[0]
	var enemy: Enemy = pair[1]
	player.begin_predate()
	player.health.take_hit(999, "physical")
	assert_true(enemy.get_node("Sprite").visible)
	assert_null(player._cover)
