extends GutTest
## The opening's battle: it pauses the game, rolls the truck in, shows the commands, plays each command's animation and its result,
## lets the truck hit (HP drops, the screen flashes), knocks you out after the third, and swallows every other key while it plays.
## It is your turn and then the truck's, the first Dodge works and brings a second truck, the umbrella angers a truck (whose life bar
## does not move), and the last round has an old lady and one command.

class Probe extends Node:
	var seen := 0
	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS  # a default-mode node hears nothing while the tree is paused, which would prove nothing
	func _unhandled_input(_event: InputEvent) -> void:
		seen += 1

var scene: OpeningScene
var probe: Probe
var saved_pad: Array
var saved_paused: bool
var hits := [0]
var done := [0]
var _on_event := func(_name: String, _tags: Dictionary) -> void: pass

func _def() -> OpeningDef:
	var d := OpeningDef.new()
	d.choices = [{"id": "fight", "label": "Fight"}, {"id": "dodge", "label": "Dodge"}, {"id": "jump", "label": "Jump"},
		{"id": "pray", "label": "Pray"}, {"id": "run", "label": "Run"}]
	d.trucks = []
	for t in 3:
		var results := {}
		for c in d.choices:
			results[c["id"]] = "r%d_%s" % [t, c["id"]]
		d.trucks.append({"prompt": "P%d" % t, "results": results})
	d.fallback = "fallback"
	d.goddess_line = "line"
	return d

## The def with the new copy: the first dodge's line, the second truck's arrival and the old lady.
func _def_full() -> OpeningDef:
	var d := _def()
	d.dodge_success = "dodged"
	d.second_truck = "two trucks"
	d.grandma = {"id": "grandma", "label": "Save Grandma", "prompt": "an old lady", "result": "you push her clear"}
	return d

func before_each() -> void:
	saved_pad = [Controls.last_stick, Controls.using_joypad, Controls.last_device, Controls.last_pad_name]
	saved_paused = get_tree().paused
	hits[0] = 0
	done[0] = 0
	_on_event = func(event_name: String, _tags: Dictionary) -> void:
		if event_name == "opening_hit":
			hits[0] += 1
	EventBus.world_event.connect(_on_event)
	probe = Probe.new()
	add_child_autofree(probe)  # before the scene, so the scene hears a key first
	scene = OpeningScene.new()
	add_child_autofree(scene)
	scene.finished.connect(func() -> void: done[0] += 1)

func after_each() -> void:
	EventBus.world_event.disconnect(_on_event)
	get_tree().paused = saved_paused
	Controls.last_stick = saved_pad[0]
	Controls.using_joypad = saved_pad[1]
	Controls.last_device = saved_pad[2]
	Controls.last_pad_name = saved_pad[3]

func _press(code: Key, times := 1) -> void:
	for i in times:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code  # Controls binds the physical key
		ev.pressed = true
		get_viewport().push_input(ev)

## Enter until the command window is up (an Enter during an animation finishes it).
func _to_command() -> void:
	for i in 6:
		if scene.beat() == "command" or not scene.is_playing():
			return
		_press(KEY_ENTER)

## Takes the command `row` steps down the list, then finishes its animation: the result is on screen and waiting for you.
func _choose(row: int) -> void:
	_to_command()
	_press(KEY_DOWN, row)
	_press(KEY_ENTER)
	_press(KEY_ENTER)

## From the waiting result: the truck charges and hits, the animation is finished, and the next round (or the knock-out) begins.
func _take_the_hit() -> void:
	_press(KEY_ENTER)
	_press(KEY_ENTER)

func test_play_pauses_and_the_truck_rolls_in() -> void:
	assert_true(scene.play(_def()))
	assert_true(scene.is_playing())
	assert_true(scene.visible)
	assert_true(get_tree().paused)
	assert_eq(scene.beat(), "intro")
	assert_eq(scene.text_lines(), ["P0"], "the truck's prompt is the message")
	assert_eq(scene.row_texts(), [], "the command window is not up yet")
	assert_lt(scene.truck().position.x, 0.0, "the truck starts off the left of the screen")
	scene.skip()
	assert_eq(scene.beat(), "command")
	assert_eq(scene.truck().position.x, OpeningScene.TRUCK_REST_X)
	assert_eq(scene.row_texts(), ["> Fight", "  Dodge", "  Jump", "  Pray", "  Run"])
	assert_eq(scene.hp(), OpeningScene.MAX_HP)

func test_it_refuses_when_paused_or_already_playing() -> void:
	assert_true(scene.play(_def()))
	assert_false(scene.play(_def()), "a play is under way")
	assert_eq(scene.text_lines(), ["P0"], "and nothing changed")
	var other := OpeningScene.new()
	add_child_autofree(other)
	assert_false(other.play(_def()), "the tree is already paused")
	assert_false(other.is_playing())
	assert_false(other.visible)

func test_enter_during_the_intro_finishes_it() -> void:
	scene.play(_def())
	_press(KEY_ENTER)
	assert_eq(scene.beat(), "command")

func test_a_command_plays_its_action_then_waits_for_you_to_read_it() -> void:
	scene.play(_def())
	_to_command()
	_press(KEY_DOWN)
	assert_eq(scene.row_texts()[1], "> Dodge")
	_press(KEY_ENTER)
	assert_eq(scene.beat(), "action")
	assert_eq(scene.text_lines(), ["r0_dodge"], "the result of the highlighted command")
	assert_eq(scene.row_texts(), [], "no command window while it plays")
	assert_eq(scene.commuter().clip(), "dodge")
	_press(KEY_ENTER)  # finish the animation
	assert_eq(scene.beat(), "result")
	assert_eq(scene.commuter().clip(), "idle", "he is back on his feet")
	assert_eq(scene.commuter().position, OpeningScene.HERO_REST)
	assert_eq(scene.text_lines(), ["r0_dodge"], "the line stays up while you read it")

func test_every_command_plays_its_own_clip() -> void:
	var clips := {"fight": "fight", "dodge": "dodge", "jump": "jump", "pray": "pray", "run": "run"}
	var row := 0
	for id in clips:
		var one := OpeningScene.new()
		add_child_autofree(one)
		get_tree().paused = false
		assert_true(one.play(_def()))
		one.skip()
		one.move(row)
		one.act()
		assert_eq(one.commuter().clip(), clips[id], id)
		row += 1
		get_tree().paused = false  # a play pauses the tree; the next one must find it running

func test_the_truck_hits_hp_drops_and_the_third_knocks_you_out() -> void:
	scene.play(_def())
	_choose(0)
	assert_eq(scene.beat(), "result")
	_take_the_hit()
	assert_eq(hits[0], 1)
	assert_eq(scene.hp(), 20)
	assert_eq(scene.beat(), "intro", "the next truck rolls in")
	assert_eq(scene.text_lines(), ["P1"])
	assert_eq(scene.commuter().clip(), "idle", "he gets up")
	_choose(2)
	_take_the_hit()
	assert_eq(scene.hp(), 10)
	assert_eq(scene.text_lines(), ["P2"])
	_choose(3)
	_take_the_hit()
	assert_eq(hits[0], 3)
	assert_eq(scene.hp(), 0)
	assert_eq(scene.beat(), "ko")
	assert_eq(scene.commuter().clip(), "ko")
	assert_eq(done[0], 0, "the fade to white still has to play")
	_press(KEY_ENTER)
	assert_eq(done[0], 1, "finished fires once, when the white is full")
	assert_false(scene.is_playing())
	assert_true(scene.is_fading(), "the white fades away over her menu")
	assert_false(scene.get_node("Backdrop").visible, "the battle itself is gone")
	assert_false(scene.get_node("Commands").visible)
	assert_true(get_tree().paused, "her menu takes over the paused tree")
	scene.skip()
	assert_false(scene.visible, "and the layer goes once the white has faded")
	assert_false(scene.is_fading())
	_press(KEY_ENTER)
	assert_eq(done[0], 1, "and never again")

func test_skipping_a_hit_leaves_no_white_over_the_next_round() -> void:
	scene.play(_def())
	var flash := scene.get_node("Flash") as ColorRect
	_choose(0)
	_press(KEY_ENTER)  # the truck starts to charge
	_press(KEY_ENTER)  # and the player skips the whole hit, impact included, before it plays
	assert_eq(scene.beat(), "intro", "the next truck is rolling in")
	assert_eq(flash.modulate.a, 0.0, "the impact's white flash must not be left over the next round")
	_to_command()
	assert_eq(flash.modulate.a, 0.0)

func test_a_new_play_after_the_fade_shows_the_battle_again() -> void:
	scene.play(_def())
	for i in 3:
		_choose(0)
		_take_the_hit()
	_press(KEY_ENTER)
	scene.skip()
	get_tree().paused = false
	assert_true(scene.play(_def()))
	assert_true(scene.get_node("Backdrop").visible, "the street is back")
	assert_true(scene.get_node("Status").visible)
	assert_eq(scene.hp(), OpeningScene.MAX_HP)

func test_each_round_is_a_different_tint_of_the_same_truck() -> void:
	scene.play(_def())
	var first := scene.truck().modulate
	_choose(0)
	_take_the_hit()
	assert_ne(scene.truck().modulate, first, "another truck is coming")

func test_the_stick_steps_once_per_push() -> void:
	scene.play(_def())
	scene.skip()
	Controls.last_stick = Vector2(0.0, 0.9)
	scene._process(0.016)
	assert_eq(scene.row_texts()[1], "> Dodge")
	scene._process(0.016)
	assert_eq(scene.row_texts()[1], "> Dodge", "a held push repeats only after the delay")
	Controls.last_stick = Vector2.ZERO
	scene._process(0.016)
	Controls.last_stick = Vector2(0.0, 0.9)
	scene._process(0.016)
	assert_eq(scene.row_texts()[2], "> Jump", "a fresh push steps again")

func test_nothing_behind_it_gets_a_key_while_it_plays() -> void:
	scene.play(_def())
	_press(KEY_ESCAPE)
	var menu := InputEventAction.new()
	menu.action = "menu"
	menu.pressed = true
	get_viewport().push_input(menu)
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	get_viewport().push_input(motion)
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_START
	button.pressed = true
	get_viewport().push_input(button)
	assert_eq(probe.seen, 0, "the menu key, Escape and the pad reach nothing behind it")
	assert_true(scene.is_playing())
	for i in 40:
		if not scene.is_playing():
			break
		_press(KEY_ENTER)
	assert_false(scene.is_playing())
	_press(KEY_ESCAPE)
	assert_eq(probe.seen, 1, "once it is over, keys flow again (so the probe does hear)")

func test_each_hit_emits_opening_hit_once() -> void:
	scene.play(_def())
	for i in 3:
		_choose(0)
		assert_eq(hits[0], i, "the truck has not hit yet while you read the result")
		_take_the_hit()
		assert_eq(hits[0], i + 1)

func test_the_layout_fits_the_screen_and_the_windows_do_not_collide() -> void:
	var screen := Rect2(0, 0, 640, 360)
	for rect in [OpeningScene.MESSAGE_RECT, OpeningScene.COMMAND_RECT, OpeningScene.STATUS_RECT, OpeningScene.ENEMY_RECT]:
		assert_true(screen.encloses(rect), str(rect))
	assert_false(OpeningScene.COMMAND_RECT.intersects(OpeningScene.STATUS_RECT))
	assert_false(OpeningScene.MESSAGE_RECT.intersects(OpeningScene.COMMAND_RECT))
	assert_false(OpeningScene.ENEMY_RECT.intersects(OpeningScene.MESSAGE_RECT))
	assert_false(OpeningScene.ENEMY_RECT.intersects(OpeningScene.COMMAND_RECT))
	assert_lte(2.0 * 7.0 + OpeningDef.MAX_ROWS * OpeningScene.ROW_HEIGHT, OpeningScene.COMMAND_RECT.size.y, "every command row, and the old lady's, fits its window")
	assert_lt(OpeningScene.FLOOR_Y, OpeningScene.COMMAND_RECT.position.y, "the fighters stand above the windows")
	assert_lt(OpeningScene.FLOOR_Y, OpeningScene.STATUS_RECT.position.y)

func test_the_street_is_the_640_by_360_backdrop() -> void:
	assert_true(ResourceLoader.exists(OpeningScene.BACKDROP), "assets/opening/backdrop.png")
	var texture := load(OpeningScene.BACKDROP) as Texture2D
	assert_eq(texture.get_size(), Vector2(640, 360))
	assert_not_null(scene.get_node("Backdrop").texture)

# --- whose turn it is, and the truck going after you ---

func _tag(marker: Node) -> String:
	return (marker.get_node("Bob/Tag") as Label).text

func test_it_is_your_turn_while_the_commands_are_up() -> void:
	scene.play(_def())
	var marker := scene.get_node("TurnMarker") as Node2D
	assert_eq(scene.turn(), "", "the truck is still rolling in")
	assert_false(marker.visible)
	scene.skip()
	assert_eq(scene.turn(), "player")
	assert_true(marker.visible)
	assert_string_contains(_tag(marker), "YOUR TURN")
	assert_almost_eq(marker.position.x, scene.commuter().position.x, 1.0, "the arrow is over him")
	assert_lt(marker.position.y, scene.commuter().position.y - 60.0, "and above his head")
	_press(KEY_ENTER)
	assert_eq(scene.turn(), "", "he is acting, nobody's turn is highlighted")
	assert_false(marker.visible)

func test_after_your_result_the_trucks_turn_starts_by_itself() -> void:
	scene.play(_def())
	_choose(0)
	assert_eq(scene.beat(), "result")
	assert_eq(hits[0], 0)
	scene.skip()  # the pause that lets you read the line runs out: no Enter needed
	assert_eq(scene.beat(), "hit")
	assert_eq(scene.turn(), "truck")
	var marker := scene.get_node("TurnMarker") as Node2D
	assert_true(marker.visible)
	assert_string_contains(_tag(marker), "TRUCK")
	assert_gt(marker.position.x, scene.truck().position.x, "over the truck")

func test_the_truck_leaves_after_its_turn_and_the_next_round_rolls_in() -> void:
	scene.play(_def())
	_choose(0)
	_take_the_hit()
	assert_eq(scene.beat(), "intro")
	assert_lt(scene.truck().position.x, 0.0, "the first truck is gone; the next comes in from the left")

# --- the first dodge works, and a second truck shows up ---

func test_the_first_dodge_works_and_a_second_truck_shows_up() -> void:
	scene.play(_def_full())
	_choose(1)
	assert_eq(scene.text_lines(), ["dodged"])
	assert_eq(scene.commuter().clip(), "idle")
	_take_the_hit()
	assert_eq(hits[0], 0, "the truck missed: no impact")
	assert_eq(scene.hp(), OpeningScene.MAX_HP, "and no damage")
	assert_eq(scene.beat(), "intro")
	assert_eq(scene.text_lines(), ["two trucks"])
	assert_eq(scene.trucks_shown(), 2)
	assert_lt(scene.truck_at(1).position.x, 0.0, "the second one rolls in from the left")
	scene.skip()
	assert_eq(scene.beat(), "command")
	assert_true(scene.truck_at(1).visible)
	assert_eq(scene.truck().position.x, OpeningScene.TRUCK_SLOTS_TWO[0])
	assert_eq(scene.truck_at(1).position.x, OpeningScene.TRUCK_SLOTS_TWO[1])
	assert_eq(scene.row_texts()[0], "> Fight", "the round starts over")

func test_only_one_truck_before_the_dodge_and_the_enemy_window_grows_with_the_second() -> void:
	scene.play(_def_full())
	scene.skip()
	var enemy := scene.get_node("Enemy") as Control
	assert_true(enemy.visible)
	assert_eq(scene.trucks_shown(), 1)
	assert_false(scene.truck_at(1).visible)
	var one_high := enemy.size.y
	_choose(1)
	_take_the_hit()
	assert_gt(enemy.size.y, one_high, "a life bar for each truck")
	assert_lte(enemy.size.y, OpeningScene.ENEMY_RECT.size.y)
	assert_eq(scene.truck_hp_text(1), "HP 9999/9999")

func test_a_second_dodge_is_an_ordinary_command_and_fails() -> void:
	scene.play(_def_full())
	_choose(1)
	_take_the_hit()
	_choose(1)
	assert_eq(scene.text_lines(), ["r0_dodge"], "the truck's own line, not the success line")
	_take_the_hit()
	assert_eq(hits[0], 2, "both trucks run you over")
	assert_eq(scene.hp(), 20)

func test_with_two_trucks_each_hits_in_turn_and_the_round_still_costs_a_third() -> void:
	scene.play(_def_full())
	_choose(1)
	_take_the_hit()
	_choose(2)
	_take_the_hit()
	assert_eq(hits[0], 2, "the front truck and the one behind it")
	assert_eq(scene.hp(), 20)
	assert_eq(scene.text_lines(), ["P1"])

func test_every_hit_of_a_two_truck_fight_lands_and_the_last_knocks_you_out() -> void:
	scene.play(_def_full())
	_choose(1)
	_take_the_hit()
	_choose(2)
	_take_the_hit()
	_choose(3)
	_take_the_hit()
	assert_eq(scene.hp(), 10)
	_choose(0)  # the old lady's round: the only command
	_take_the_hit()
	assert_eq(hits[0], 6, "two trucks, three rounds")
	assert_eq(scene.hp(), 0)
	assert_eq(scene.beat(), "ko")

# --- the umbrella angers the truck, and its life bar does not move ---

func test_hitting_the_truck_with_the_umbrella_angers_it_and_its_life_bar_does_not_move() -> void:
	scene.play(_def())
	scene.skip()
	assert_false(scene.truck_angry(0))
	assert_eq(scene.truck_hp_text(0), "HP 9999/9999")
	assert_eq(scene.truck_bar_fraction(0), 1.0)
	_press(KEY_ENTER)  # Fight
	scene.skip()
	assert_true(scene.truck_angry(0), "angry eyebrows")
	assert_eq(scene.truck().clip(), "idle_angry")
	assert_eq(scene.pops_shown(), ["0"], "the damage number is a zero")
	assert_eq(scene.truck_hp_text(0), "HP 9999/9999", "it did not go down at all")
	assert_eq(scene.truck_bar_fraction(0), 1.0)

func test_the_other_commands_leave_the_truck_calm() -> void:
	for row in [1, 2, 3, 4]:
		var one := OpeningScene.new()
		add_child_autofree(one)
		get_tree().paused = false
		assert_true(one.play(_def()))
		one.skip()
		one.move(row)
		one.act()
		one.skip()
		assert_false(one.truck_angry(0), "row %d" % row)
		assert_eq(one.truck().clip(), "idle")
		assert_eq(one.pops_shown(), [])
		get_tree().paused = false

func test_the_truck_stays_angry_and_its_attack_is_a_road_rage() -> void:
	scene.play(_def())
	_choose(0)
	assert_eq(scene.rage_attacks(), 0, "it has not attacked yet")
	_take_the_hit()
	assert_eq(scene.rage_attacks(), 1)
	assert_eq(hits[0], 1)
	assert_eq(scene.hp(), 20, "a road rage hits as hard as any other, no harder")
	assert_eq(scene.get_node("Stage").position, Vector2.ZERO, "the shaking stops")
	assert_true(scene.truck_angry(0), "it stays angry for the rest of the fight")
	assert_eq(scene.truck().clip(), "idle_angry")
	assert_eq(scene.truck().modulate, OpeningScene.TRUCK_TINTS[1], "and is back to its colour, not left red")
	_choose(2)
	_take_the_hit()
	assert_eq(scene.rage_attacks(), 2, "every attack of an angry truck is one")

func test_a_calm_truck_does_not_rage() -> void:
	scene.play(_def())
	_choose(2)
	_take_the_hit()
	assert_eq(scene.rage_attacks(), 0)
	assert_eq(hits[0], 1)

func test_the_umbrella_angers_only_the_front_truck() -> void:
	scene.play(_def_full())
	_choose(1)
	_take_the_hit()  # the second truck is here
	_choose(0)
	assert_true(scene.truck_angry(0))
	assert_false(scene.truck_angry(1))
	_take_the_hit()
	assert_eq(scene.rage_attacks(), 1, "only the angry one rages; the other just charges")
	assert_eq(hits[0], 2)

# --- the old lady ---

func _to_the_last_round() -> void:
	_choose(2)
	_take_the_hit()
	_choose(2)
	_take_the_hit()

func test_no_old_lady_before_the_last_round() -> void:
	scene.play(_def_full())
	assert_false(scene.grandma().visible)
	_choose(2)
	_take_the_hit()
	assert_false(scene.grandma().visible)
	assert_eq(scene.row_texts().size(), 0)
	scene.skip()
	assert_eq(scene.row_texts().size(), 5, "five commands, no sixth row")

func test_the_old_lady_walks_in_and_only_saving_her_can_be_picked() -> void:
	scene.play(_def_full())
	_to_the_last_round()
	assert_true(scene.grandma().visible)
	assert_gt(scene.grandma().position.x, OpeningScene.GRANDMA_X, "she is walking in from the right")
	assert_eq(scene.text_lines(), ["an old lady"])
	scene.skip()
	assert_eq(scene.grandma().position.x, OpeningScene.GRANDMA_X)
	assert_eq(scene.row_texts(), ["  Fight", "  Dodge", "  Jump", "  Pray", "  Run", "> Save Grandma"])
	for i in 5:
		assert_false(scene.row_enabled(i), "row %d is grayed out" % i)
	assert_true(scene.row_enabled(5))
	_press(KEY_UP, 3)
	_press(KEY_DOWN, 3)
	assert_eq(scene.row_texts()[5], "> Save Grandma", "the highlight cannot leave her row")

func test_the_grayed_rows_are_drawn_dim() -> void:
	scene.play(_def_full())
	_to_the_last_round()
	scene.skip()
	var column := scene.get_node("Commands/Choices")
	assert_eq(column.get_child_count(), 6)
	assert_eq((column.get_child(0) as Label).get_theme_color("font_color"), OpeningScene.COL_DISABLED)
	assert_eq((column.get_child(4) as Label).get_theme_color("font_color"), OpeningScene.COL_DISABLED)
	assert_eq((column.get_child(5) as Label).get_theme_color("font_color"), OpeningScene.COL_TEXT)

func test_saving_the_old_lady_shoves_her_clear_and_the_trucks_run_you_over() -> void:
	scene.play(_def_full())
	_to_the_last_round()
	scene.skip()
	_press(KEY_ENTER)
	assert_eq(scene.beat(), "action")
	assert_eq(scene.commuter().clip(), "save")
	assert_eq(scene.text_lines(), ["you push her clear"])
	_press(KEY_ENTER)  # finishes the shove
	assert_eq(scene.beat(), "result")
	assert_eq(scene.grandma().clip(), "safe")
	assert_eq(scene.commuter().position.x, OpeningScene.GRANDMA_X, "he stands where she stood")
	assert_gt(scene.grandma().position.x, OpeningScene.HERO_REST.x, "she is out of the road, behind him")
	_take_the_hit()
	assert_eq(scene.hp(), 0)
	assert_eq(scene.beat(), "ko")
	assert_eq(scene.commuter().clip(), "ko")
	assert_eq(hits[0], 3)
	_press(KEY_ENTER)
	assert_eq(done[0], 1)

func test_the_trucks_stop_at_him_wherever_he_stands() -> void:
	scene.play(_def_full())
	_to_the_last_round()
	scene.skip()
	_press(KEY_ENTER)
	_press(KEY_ENTER)
	var stops := []
	var record := func(event_name: String, _tags: Dictionary) -> void:
		if event_name == "opening_hit":
			stops.append(scene.truck().position.x + OpeningScene.TRUCK_HALF_WIDTH * scene.truck().scale.x)
	EventBus.world_event.connect(record)
	_press(KEY_ENTER)  # the truck's turn
	_press(KEY_ENTER)  # and all of it at once
	EventBus.world_event.disconnect(record)
	assert_eq(stops.size(), 1)
	assert_lt(stops[0], OpeningScene.GRANDMA_X + 1.0, "its front stops at him, at the spot he shoved her from")
	assert_gt(stops[0], OpeningScene.GRANDMA_X - 40.0, "and does not stop well short of him")

func test_a_new_play_starts_over_with_no_anger_no_old_lady_and_one_truck() -> void:
	scene.play(_def_full())
	_choose(1)
	_take_the_hit()
	_choose(0)
	assert_true(scene.truck_angry(0))
	for i in 40:
		if not scene.is_playing():
			break
		_press(KEY_ENTER)
	scene.skip()
	get_tree().paused = false
	assert_true(scene.play(_def_full()))
	assert_false(scene.truck_angry(0))
	assert_eq(scene.trucks_shown(), 1)
	assert_false(scene.grandma().visible)
	assert_eq(scene.rage_attacks(), 0)
	assert_eq(scene.pops_shown(), [])
	assert_eq(scene.commuter().position, OpeningScene.HERO_REST)

func test_the_arrow_follows_the_truck_as_it_charges() -> void:
	scene.play(_def())
	_choose(0)
	scene.skip()  # the trucks' turn starts, and nothing of it has played yet
	assert_eq(scene.turn(), "truck")
	var marker := scene.get_node("TurnMarker") as Node2D
	scene.truck().position.x = 300.0
	scene._process(0.016)
	assert_almost_eq(marker.position.x, 300.0 + OpeningScene.TRUCK_CAB_OFFSET * scene.truck().scale.x, 1.0, "over the cab wherever it is")

func test_the_arrow_stays_above_the_tallest_charging_frame() -> void:
	scene.play(_def())
	_choose(0)
	scene.skip()
	var marker := scene.get_node("TurnMarker") as Node2D
	assert_lt(marker.position.y, OpeningScene.FLOOR_Y - OpeningScene.TRUCK_MARKER_HEIGHT, "clear of the tilted truck, whatever frame it is on")
