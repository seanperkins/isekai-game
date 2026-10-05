extends GutTest
## The opening's battle: it pauses the game, rolls the truck in, shows the commands, plays each command's animation and its result,
## lets the truck hit (HP drops, the screen flashes), knocks you out after the third, and swallows every other key while it plays.

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
	for rect in [OpeningScene.MESSAGE_RECT, OpeningScene.COMMAND_RECT, OpeningScene.STATUS_RECT]:
		assert_true(screen.encloses(rect), str(rect))
	assert_false(OpeningScene.COMMAND_RECT.intersects(OpeningScene.STATUS_RECT))
	assert_false(OpeningScene.MESSAGE_RECT.intersects(OpeningScene.COMMAND_RECT))
	assert_lte(2.0 * 7.0 + OpeningDef.MAX_CHOICES * OpeningScene.ROW_HEIGHT, OpeningScene.COMMAND_RECT.size.y, "every command row fits its window")
	assert_lt(OpeningScene.FLOOR_Y, OpeningScene.COMMAND_RECT.position.y, "the fighters stand above the windows")
	assert_lt(OpeningScene.FLOOR_Y, OpeningScene.STATUS_RECT.position.y)

func test_the_street_is_the_640_by_360_backdrop() -> void:
	assert_true(ResourceLoader.exists(OpeningScene.BACKDROP), "assets/opening/backdrop.png")
	var texture := load(OpeningScene.BACKDROP) as Texture2D
	assert_eq(texture.get_size(), Vector2(640, 360))
	assert_not_null(scene.get_node("Backdrop").texture)
