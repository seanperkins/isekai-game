extends GutTest
## The stick's selection step: one step per push, then slow repeats while held. Shared by the skill screen and the goddess's menu.

func test_a_push_steps_once_then_repeats_after_the_delay() -> void:
	var nav := NavStep.new()
	var down := Vector2(0.0, 0.9)
	assert_eq(nav.step(Vector2(0.0, 0.8), 0.016), Vector2i.DOWN)
	assert_eq(nav.step(down, 0.016), Vector2i.ZERO)
	assert_eq(nav.step(down, 0.2), Vector2i.ZERO)
	assert_eq(nav.step(down, 0.2), Vector2i.DOWN, "held past the delay: repeat")
	assert_eq(nav.step(down, 0.05), Vector2i.ZERO)
	assert_eq(nav.step(down, 0.1), Vector2i.DOWN)
	assert_eq(nav.step(Vector2(0.0, 0.1), 0.016), Vector2i.ZERO, "released")
	assert_eq(nav.step(Vector2(0.0, -0.7), 0.016), Vector2i.UP)

func test_the_dominant_axis_wins_and_a_small_push_is_ignored() -> void:
	var nav := NavStep.new()
	var cases := {Vector2(0.9, 0.3): Vector2i.RIGHT, Vector2(-0.8, 0.3): Vector2i.LEFT,
		Vector2(0.3, -0.9): Vector2i.UP, Vector2(-0.2, 0.7): Vector2i.DOWN}
	for stick in cases:
		nav.step(Vector2.ZERO, 0.016)  # release between pushes
		assert_eq(nav.step(stick, 0.016), cases[stick], str(stick))
	nav.step(Vector2.ZERO, 0.016)
	assert_eq(nav.step(Vector2(0.3, 0.3), 0.016), Vector2i.ZERO, "inside the threshold on both axes")

func test_reset_makes_the_next_push_a_fresh_edge() -> void:
	var nav := NavStep.new()
	var down := Vector2(0.0, 0.9)
	assert_eq(nav.step(down, 0.016), Vector2i.DOWN)
	assert_eq(nav.step(down, 0.016), Vector2i.ZERO, "still held")
	nav.reset()
	assert_eq(nav.step(down, 0.016), Vector2i.DOWN, "a fresh edge after reset")
