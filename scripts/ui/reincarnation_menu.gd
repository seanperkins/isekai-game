class_name ReincarnationMenu
extends CanvasLayer
## Shows RebirthChoice's decision after death: up/down (keys, D-pad, stick) moves, accept (Enter, Space, A) confirms an unlocked entry. Layer 40:
## above the death card (30) and the skill screen (20). It takes input only while a decision is pending.

var choose_callback := Callable()
var _options: Array = []
var _index := 0
var _open := false
var _list := VBoxContainer.new()

func _init() -> void:
	layer = 40
	visible = false

func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.05, 0.85)
	shade.size = Vector2(640, 360)
	add_child(shade)
	var title := Label.new()
	title.text = "Where will you be reborn?"
	title.position = Vector2(200, 84)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	add_child(title)
	_list.position = Vector2(200, 110)
	_list.size = Vector2(240, 140)
	add_child(_list)

## Listens for the Run's decision and answers through Run.choose.
func bind(run: Run) -> void:
	choose_callback = run.choose
	run.choice_needed.connect(show_decision)

func show_decision(decision: Dictionary) -> void:
	_options = decision.get("options", [])
	_index = int(decision.get("selected", 0))
	_open = not _options.is_empty()
	visible = _open
	_redraw()

func is_open() -> bool:
	return _open

func labels() -> Array:
	return _options.map(func(o: Dictionary) -> String: return o["name"])

func selected() -> int:
	return _index

func move(dir: int) -> void:
	if not _open:
		return
	_index = clampi(_index + dir, 0, _options.size() - 1)
	_redraw()

## Confirms the highlighted entry. A locked one does nothing; an unlocked one closes the menu and calls choose.
func confirm() -> bool:
	if not _open or _options[_index]["locked"]:
		return false
	var id: String = _options[_index]["id"]
	_open = false
	visible = false
	if choose_callback.is_valid():
		choose_callback.call(id)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		move(1)
	elif event.is_action_pressed("menu_accept") or event.is_action_pressed("ui_accept"):
		confirm()
	else:
		return
	get_viewport().set_input_as_handled()

func _redraw() -> void:
	if not is_node_ready():
		return
	for c in _list.get_children():
		c.queue_free()
	for i in _options.size():
		var l := Label.new()
		l.text = ("> " if i == _index else "  ") + str(_options[i]["name"])
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6) if _options[i]["locked"] else Color(0.75, 0.9, 1.0))
		_list.add_child(l)
