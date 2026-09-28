extends GutTest
## Entering a room through its floor: the boost must lift the slime's feet over the floor lip, even
## from the very edge of the crossing. The body is 28x24 with its feet 12 px below its origin, so a
## boost tuned for the old 14x12 body is short. C2's ceiling into C3 is the only way to C3 and C6.

var rules: SkillRulesEngine
var player: Player

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	Input.action_release("move_left")

func _c3() -> RoomDef:
	return World.load_rooms("res://data/rooms")["C3"]

## Lands the slime in C3 through its floor gap, `overshoot` px past the crossing line, moving up at
## the entry boost and holding left, and returns whether it ends standing on the floor lip.
func _enters_and_stands(overshoot: float) -> bool:
	var room := RoomBuilder.build_room(_c3(), {})
	add_child_autofree(room)
	var bottom := _c3().world_rect().end.y
	player.global_position = Vector2(_c3().world_rect().position.x + 340.0, bottom - overshoot)
	player.velocity = Vector2(0.0, World.ENTRY_BOOST)
	Input.action_press("move_left")
	await wait_physics_frames(120)
	return player.is_on_floor() and player.global_position.y < bottom - RoomDef.FLOOR

func test_the_boost_clears_the_floor_lip_from_the_edge_of_the_crossing() -> void:
	var stood: bool = await _enters_and_stands(0.0)
	assert_true(stood, "the slime fell back through the gap instead of landing on the lip")

func test_the_boost_clears_it_with_a_small_overshoot_too() -> void:
	var stood: bool = await _enters_and_stands(2.5)
	assert_true(stood)

func test_the_boost_covers_the_lip_plus_the_feet_with_room_to_spare() -> void:
	var rise := World.ENTRY_BOOST * World.ENTRY_BOOST / (2.0 * Player.GRAVITY)
	assert_gte(rise, RoomDef.FLOOR + Player.BODY_BOTTOM + 8.0)
