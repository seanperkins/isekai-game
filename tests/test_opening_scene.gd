extends GutTest
## The truck dodge: it pauses the game, draws the model's prompt and choices, is driven by keys and the stick, swallows every other
## key while it plays (there is no skip), and emits the hit once per truck.

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
var _on_event := func(_name: String, _tags: Dictionary) -> void: pass

func _def() -> OpeningDef:
	var d := OpeningDef.new()
	d.choices = [{"id": "a", "label": "A"}, {"id": "b", "label": "B"}, {"id": "c", "label": "C"}]
	d.trucks = [
		{"prompt": "P0", "results": {"a": "r0a", "b": "r0b", "c": "r0c"}},
		{"prompt": "P1", "results": {"a": "r1a", "b": "r1b", "c": "r1c"}},
		{"prompt": "P2", "results": {"a": "r2a", "b": "r2b", "c": "r2c"}},
	]
	d.fallback = "fallback"
	d.goddess_line = "line"
	return d

func before_each() -> void:
	saved_pad = [Controls.last_stick, Controls.using_joypad, Controls.last_device, Controls.last_pad_name]
	saved_paused = get_tree().paused
	hits[0] = 0
	_on_event = func(event_name: String, _tags: Dictionary) -> void:
		if event_name == "opening_hit":
			hits[0] += 1
	EventBus.world_event.connect(_on_event)
	probe = Probe.new()
	add_child_autofree(probe)  # before the scene, so the scene hears a key first
	scene = OpeningScene.new()
	add_child_autofree(scene)

func after_each() -> void:
	EventBus.world_event.disconnect(_on_event)
	get_tree().paused = saved_paused
	Controls.last_stick = saved_pad[0]
	Controls.using_joypad = saved_pad[1]
	Controls.last_device = saved_pad[2]
	Controls.last_pad_name = saved_pad[3]

func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code  # Controls binds the physical key
	ev.pressed = true
	get_viewport().push_input(ev)

func test_play_pauses_and_shows_the_first_prompt_and_rows() -> void:
	assert_true(scene.play(_def()))
	assert_true(scene.is_playing())
	assert_true(scene.visible)
	assert_true(get_tree().paused)
	assert_eq(scene.text_lines(), ["P0"])
	assert_eq(scene.row_texts(), ["> A", "  B", "  C"])

func test_it_refuses_when_paused_or_already_playing() -> void:
	assert_true(scene.play(_def()))
	assert_false(scene.play(_def()), "a play is under way")
	assert_eq(scene.text_lines(), ["P0"], "and nothing changed")
	var other := OpeningScene.new()
	add_child_autofree(other)
	assert_false(other.play(_def()), "the tree is already paused")
	assert_false(other.is_playing())
	assert_false(other.visible)

func test_keys_walk_the_three_trucks() -> void:
	var done := [0]
	scene.finished.connect(func() -> void: done[0] += 1)
	scene.play(_def())
	_press(KEY_DOWN)
	assert_eq(scene.row_texts(), ["  A", "> B", "  C"])
	_press(KEY_ENTER)
	assert_eq(scene.text_lines(), ["r0b"], "the result of the highlighted choice")
	assert_eq(scene.row_texts(), [], "no menu while the truck hits")
	_press(KEY_ENTER)
	assert_eq(scene.text_lines(), ["P1"])
	assert_eq(scene.row_texts(), ["> A", "  B", "  C"], "the row starts at the top again")
	_press(KEY_ENTER)
	_press(KEY_ENTER)
	assert_eq(scene.text_lines(), ["P2"])
	_press(KEY_DOWN)
	_press(KEY_DOWN)
	_press(KEY_ENTER)
	assert_eq(scene.text_lines(), ["r2c"])
	assert_eq(done[0], 0)
	_press(KEY_ENTER)
	assert_eq(done[0], 1, "finished fires once, after the last result")
	assert_false(scene.visible)
	assert_false(scene.is_playing())
	assert_true(get_tree().paused, "her menu takes over the paused tree")
	_press(KEY_ENTER)
	assert_eq(done[0], 1, "and never again")

func test_the_stick_steps_once_per_push() -> void:
	scene.play(_def())
	Controls.last_stick = Vector2(0.0, 0.9)
	scene._process(0.016)
	assert_eq(scene.row_texts()[1], "> B")
	scene._process(0.016)
	assert_eq(scene.row_texts()[1], "> B", "a held push repeats only after the delay")
	Controls.last_stick = Vector2.ZERO
	scene._process(0.016)
	Controls.last_stick = Vector2(0.0, 0.9)
	scene._process(0.016)
	assert_eq(scene.row_texts()[2], "> C", "a fresh push steps again")

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
	assert_eq(probe.seen, 0, "the menu key, Escape and the pad reach nothing behind it: there is no skip")
	assert_true(scene.is_playing())
	for i in 6:
		_press(KEY_ENTER)
	assert_false(scene.is_playing())
	_press(KEY_ESCAPE)
	assert_eq(probe.seen, 1, "once it is over, keys flow again (so the probe does hear)")

func test_each_hit_emits_opening_hit_once() -> void:
	scene.play(_def())
	for i in 3:
		_press(KEY_ENTER)
		assert_eq(hits[0], i + 1, "the truck hits as the choice is taken")
		_press(KEY_ENTER)
		assert_eq(hits[0], i + 1, "and not again when the result is dismissed")

func test_the_truck_slides_in_and_hits() -> void:
	scene.play(_def())
	var stage := scene.get_node("Stage") as OpeningStage
	assert_eq(stage.approach, 0.0)
	scene._process(OpeningScene.APPROACH_SECONDS * 0.5)
	assert_almost_eq(stage.approach, 0.5, 0.001)
	scene._process(OpeningScene.APPROACH_SECONDS)
	assert_eq(stage.approach, 1.0, "it stops at the figure")
	assert_false(stage.hit)
	_press(KEY_ENTER)
	assert_true(stage.hit)
	assert_gt(stage.flash, 0.0)
	scene._process(OpeningScene.FLASH_SECONDS)
	assert_eq(stage.flash, 0.0, "the flash is brief")
	_press(KEY_ENTER)
	assert_eq([stage.approach, stage.hit], [0.0, false], "the next truck starts from the left")

func test_taking_a_choice_early_brings_the_truck_in() -> void:
	scene.play(_def())
	var stage := scene.get_node("Stage") as OpeningStage
	assert_eq(stage.approach, 0.0)
	_press(KEY_ENTER)  # confirm before the truck has arrived
	assert_eq(stage.approach, 1.0, "the truck is on the figure when it hits, not stuck halfway down the road")
	assert_true(stage.hit)

func test_the_choices_and_the_footer_fit_the_screen() -> void:
	var shipped := Game.load_opening()
	assert_lte(shipped.choices.size(), OpeningDef.MAX_CHOICES)
	assert_lte(OpeningScene.COLUMN_Y + OpeningDef.MAX_CHOICES * OpeningScene.ROW_HEIGHT, OpeningScene.FOOTER_Y, "the rows end above the footer")
	assert_lte(OpeningScene.FOOTER_Y + OpeningScene.FOOTER_HEIGHT, 360.0, "and the footer is on the screen")
	scene.play(shipped)
	var column := scene.get_node("Choices") as VBoxContainer
	assert_eq(column.position.y, OpeningScene.COLUMN_Y)
	assert_eq(scene.get_node("Footer").position.y, OpeningScene.FOOTER_Y)
