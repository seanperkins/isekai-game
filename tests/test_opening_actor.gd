extends GutTest
## OpeningActor: a battle sprite played from a sheet through named clips, standing on its feet, mirrored by `flip`.

var actor: OpeningActor

func before_each() -> void:
	actor = OpeningActor.new()
	add_child_autofree(actor)

func test_it_loads_the_commuter_and_the_truck() -> void:
	assert_true(actor.setup("commuter"))
	assert_eq(actor.clip(), "idle")
	assert_true(actor.frame().begins_with("idle"))
	var truck := OpeningActor.new()
	add_child_autofree(truck)
	assert_true(truck.setup("truck"))

func test_an_unknown_set_draws_nothing_and_does_not_crash() -> void:
	assert_false(actor.setup("no_such_set"))
	actor.play("idle")
	assert_eq(actor.clip(), "")
	assert_eq(actor.frame(), "")

func test_play_switches_clips_and_ignores_unknown_ones() -> void:
	actor.setup("commuter")
	actor.play("fight")
	assert_eq(actor.clip(), "fight")
	assert_eq(actor.frame(), "fight_1")
	actor.play("no_such_clip")
	assert_eq(actor.clip(), "fight", "an unknown clip changes nothing")

func test_a_clip_advances_with_time_and_a_one_shot_holds_its_last_frame() -> void:
	actor.setup("commuter")
	actor.play("hurt")
	actor._process(5.0)
	assert_eq(actor.frame(), "hurt")
	actor.play("fight")
	actor._process(0.01)
	assert_eq(actor.frame(), "fight_1")
	actor._process(10.0)
	assert_eq(actor.frame(), "fight_3", "a one-shot stays on its last frame")

func test_the_feet_are_on_the_origin() -> void:
	actor.setup("commuter")
	var sprite := actor.get_child(0) as Sprite2D
	assert_almost_eq(sprite.position.y, -sprite.texture.get_height() / 2.0, 0.01, "the bottom of the frame sits on the origin")
	actor.play("ko")
	assert_almost_eq(sprite.position.y, -sprite.texture.get_height() / 2.0, 0.01, "in every frame")

func test_flip_mirrors_the_sprite() -> void:
	actor.setup("commuter")
	var sprite := actor.get_child(0) as Sprite2D
	assert_false(sprite.flip_h)
	actor.flip = true
	assert_true(sprite.flip_h)
