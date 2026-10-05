extends GutTest
## ShotStage: where the shot tools draw the game, so the OS window can stay a tiny one that takes over nothing.

func test_mount_puts_the_node_in_a_subviewport_of_the_given_size() -> void:
	var node := Node2D.new()
	var view := ShotStage.mount(get_tree().root, node)
	assert_eq(view.get_parent(), get_tree().root)
	assert_eq(node.get_parent(), view)
	assert_eq(view.size, Vector2i(1280, 720))
	assert_eq(view.size_2d_override, Vector2i(640, 360), "the game draws at 640x360, shown at twice the size")
	assert_true(view.size_2d_override_stretch)
	assert_eq(view.render_target_update_mode, SubViewport.UPDATE_ALWAYS)
	view.queue_free()

func test_a_stage_with_no_game_size_draws_one_to_one() -> void:
	var view := ShotStage.open(get_tree().root, Vector2i(640, 360), Vector2i.ZERO)
	assert_eq(view.size, Vector2i(640, 360))
	assert_eq(view.size_2d_override, Vector2i.ZERO)
	assert_false(view.size_2d_override_stretch)
	view.queue_free()

func test_resize_changes_the_frame_size() -> void:
	var view := ShotStage.open(get_tree().root, Vector2i(640, 360), Vector2i.ZERO)
	ShotStage.resize(view, Vector2i(960, 540))
	assert_eq(view.size, Vector2i(960, 540))
	view.queue_free()

func test_a_fresh_profile_does_not_play_the_opening_over_the_frames() -> void:
	var was: bool = Compendium.soul.opening_seen
	Compendium.soul.opening_seen = false
	var view := ShotStage.open(get_tree().root)
	assert_true(Compendium.soul.opening_seen, "the stage marked it seen, in memory")
	Compendium.soul.opening_seen = was
	view.queue_free()

class FakeSoul extends RefCounted:
	var opening_seen := false

## The autoload that is not ready yet when a -s script's _initialize runs: `soul` appears in its _ready.
class FakeCompendium extends Node:
	var soul
	func _ready() -> void:
		soul = FakeSoul.new()

func test_before_the_autoloads_are_ready_the_opening_is_skipped_once_they_are() -> void:
	var fake_root := Window.new()
	var compendium := FakeCompendium.new()
	compendium.name = "Compendium"
	fake_root.add_child(compendium)
	assert_null(compendium.soul, "not ready yet")
	ShotStage.open(fake_root)
	add_child_autofree(fake_root)  # now the autoload's _ready runs, then the handler
	assert_true(compendium.soul.opening_seen)

func test_the_stage_says_what_window_it_is_in_for_the_runner() -> void:
	assert_string_contains(ShotStage.window_line(), "shots: window mode=")
	assert_string_contains(ShotStage.window_line(), "size=")
