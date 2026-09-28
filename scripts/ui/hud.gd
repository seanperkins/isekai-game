class_name Hud
extends CanvasLayer
## HP, active slots, the Great Sage pop-up, the ticker, and the inspect/status panel.

const PANEL_SECONDS := 4.0
const TICKER_SECONDS := 3.0
## HUD is laid out for the 640x360 internal resolution; stretch scales it with the window.
const VIEW := Vector2(640, 360)
const FONT_MAIN := 10
const FONT_SMALL := 8
## Skill slots sit where their buttons are on the pad: bumpers (slots 0, 1) on the bottom row,
## triggers (slots 2, 3) above them; left buttons bottom-left, right buttons bottom-right.
const SLOT_SIZE := Vector2(128, 20)
const SLOT_MARGIN := 6.0
const SLOT_GAP := 3.0
const SLOT_CELL := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 0)]  # (side, row)

var _player: Player
var _rules
var _queue: AnnouncerQueue
var _hp := Label.new()
var _mp := Label.new()
var _menu_hint := Label.new()
var _input_debug := Label.new()
var _level := Label.new()
var _slot_nodes: Array = []  # per slot: {panel, chip, icon, name}
var _popup := Label.new()
var _popup_panel := PanelContainer.new()
var _ticker := Label.new()
var _panel := Label.new()
var _panel_left := 0.0
var _ticker_lines: Array = []  # [[text, seconds_left]]

func bind(player: Player, rules, _compendium: CompendiumModel, queue: AnnouncerQueue) -> void:
	_player = player
	_rules = rules
	_queue = queue
	player.inspect_report.connect(_on_inspect_report)
	player.not_enough_mp.connect(func(_id: String) -> void: _ticker_lines.append(["Not enough MP", TICKER_SECONDS]))

func _ready() -> void:
	_hp.position = Vector2(6, 4)
	_mp.position = Vector2(6, 16)
	_ticker.position = Vector2(140, 296)
	_ticker.size = Vector2(360, 56)
	_ticker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ticker.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_panel.position = Vector2(420, 40)
	_menu_hint.position = Vector2(572, 4)
	_input_debug.position = Vector2(6, 43)
	_level.position = Vector2(6, 28)
	_level.add_theme_font_size_override("font_size", FONT_SMALL)
	_level.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	_input_debug.visible = false
	_input_debug.add_theme_font_size_override("font_size", FONT_SMALL)
	_input_debug.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_menu_hint.add_theme_font_size_override("font_size", FONT_SMALL)
	_menu_hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	for l in [_hp, _mp, _popup]:
		l.add_theme_font_size_override("font_size", FONT_MAIN)
	for l in [_ticker, _panel]:
		l.add_theme_font_size_override("font_size", FONT_SMALL)
	_mp.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	# Great Sage window: translucent blue with a glowing border.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.1, 0.28, 0.85)
	style.border_color = Color(0.45, 0.8, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	_popup_panel.add_theme_stylebox_override("panel", style)
	_popup_panel.position = Vector2(VIEW.x / 2.0, 6)
	_popup.position = Vector2.ZERO
	_popup_panel.add_child(_popup)
	for l in [_hp, _mp, _popup_panel, _ticker, _panel, _menu_hint, _input_debug, _level]:
		add_child(l)
	_build_slots()

func _process(delta: float) -> void:
	if _player == null:
		return
	_hp.text = hp_text()
	_mp.text = mp_text()
	_menu_hint.text = menu_hint_text()
	_level.text = level_text()
	if Input.is_action_just_pressed("debug_input"):
		toggle_input_debug()
	if _input_debug.visible:
		_input_debug.text = input_debug_text()
	_update_slots()
	_popup.text = popup_text()
	_popup_panel.visible = _popup.text != ""
	_popup_panel.reset_size()
	_popup_panel.position.x = roundf((VIEW.x - _popup_panel.size.x) / 2.0)
	var entry := _queue.pop_ticker()
	while not entry.is_empty():
		_ticker_lines.append([StatusText.ticker_text(entry, _rules), TICKER_SECONDS])
		entry = _queue.pop_ticker()
	for line in _ticker_lines:
		line[1] -= delta
	_ticker_lines = _ticker_lines.filter(func(l): return l[1] > 0.0)
	_ticker.text = "\n".join(_ticker_lines.map(func(l): return l[0]))
	_panel_left = maxf(0.0, _panel_left - delta)
	_panel.visible = _panel_left > 0.0

func _slot_pos(i: int) -> Vector2:
	var cell: Vector2i = SLOT_CELL[i]
	var x := SLOT_MARGIN if cell.x == 0 else VIEW.x - SLOT_MARGIN - SLOT_SIZE.x
	var y := VIEW.y - SLOT_MARGIN - SLOT_SIZE.y - (1 - cell.y) * (SLOT_SIZE.y + SLOT_GAP)
	return Vector2(x, y)

func _build_slots() -> void:
	for i in SLOT_CELL.size():
		var right: bool = SLOT_CELL[i].x == 1
		var panel := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.07, 0.2, 0.8)
		style.border_color = Color(0.45, 0.8, 1.0, 0.8)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		panel.add_theme_stylebox_override("panel", style)
		panel.position = _slot_pos(i)
		panel.size = SLOT_SIZE
		add_child(panel)
		# Button chip on the outer edge, then the icon, then the name toward the middle.
		var chip := Label.new()
		chip.size = Vector2(20, 12)
		chip.position = Vector2(SLOT_SIZE.x - 22 if right else 2, 4)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", FONT_SMALL)
		chip.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		panel.add_child(chip)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.size = Vector2(16, 16)
		icon.position = Vector2(SLOT_SIZE.x - 40 if right else 24, 2)
		panel.add_child(icon)
		var name := Label.new()
		name.size = Vector2(SLOT_SIZE.x - 46, 12)
		name.position = Vector2(4 if right else 42, 4)
		name.clip_text = true
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
		name.add_theme_font_size_override("font_size", FONT_SMALL)
		panel.add_child(name)
		_slot_nodes.append({"panel": panel, "chip": chip, "icon": icon, "name": name, "icon_id": ""})

func _update_slots() -> void:
	var labels: Array = Controls.slot_labels()
	for i in _slot_nodes.size():
		var n: Dictionary = _slot_nodes[i]
		var id: String = _player.skillset.slots.slots[i]
		var d = _rules.get_def(id) if id != "" else null
		n["chip"].text = labels[i]
		n["name"].text = d.display_name if d != null else ""
		var icon_id := ("icon_" + id) if d != null else ""
		if icon_id != n["icon_id"]:
			n["icon_id"] = icon_id
			n["icon"].texture = Art.texture(icon_id) if icon_id != "" else null
		n["panel"].modulate.a = 0.45 if _slot_dim(i) else 1.0

## Empty, or not enough MP to cast.
func _slot_dim(i: int) -> bool:
	var id: String = _player.skillset.slots.slots[i]
	if id == "" or _rules.get_def(id) == null:
		return true
	return _player.mana.mp < _rules.get_def(id).mp_cost

## What slot `i` shows, for tests: button label, skill name, icon sprite, position, dimmed.
func slot_view(i: int) -> Dictionary:
	var n: Dictionary = _slot_nodes[i]
	return {"label": n["chip"].text, "name": n["name"].text, "icon": n["icon_id"],
		"pos": n["panel"].position, "dim": _slot_dim(i)}

func hp_text() -> String:
	return "HP %d/%d" % [_player.health.hp, _player.health.max_hp]

func toggle_input_debug() -> void:
	_input_debug.visible = not _input_debug.visible

func input_debug_visible() -> bool:
	return _input_debug.visible

## Raw stick, the aim the player would cast with right now, and the last cast's direction.
func input_debug_text() -> String:
	var held := Input.get_vector("move_left", "move_right", "aim_up", "aim_down")
	var cast: Dictionary = _player.last_cast
	var cast_text := "—" if cast.is_empty() else "%s %s" % [cast["id"], _vec(cast["aim"])]
	return "stick %s  pad: %s  dev %d\npads %s  raw up %s down %s\nheld %s  aim %s\nlast cast: %s" % [
		_vec(Controls.last_stick), Controls.last_pad_name if Controls.last_pad_name != "" else "none",
		Controls.last_device, Input.get_connected_joypads(),
		_num(Input.get_action_raw_strength("aim_up")), _num(Input.get_action_raw_strength("aim_down")),
		_vec(held), _vec(_player.aim_vector()), cast_text]

static func _vec(v: Vector2) -> String:
	return "(%s, %s)" % [_num(v.x), _num(v.y)]

static func _num(x: float) -> String:
	return str(int(roundf(x))) if is_equal_approx(x, roundf(x)) else "%.2f" % x

func level_text() -> String:
	var p := _player.progression
	return "Lv %d  XP %d/%d  EP %d" % [p.level, p.xp, Progression.xp_to_next(p.level), p.ep]

func menu_hint_text() -> String:
	return "%s  Skills" % ("Start" if Controls.using_joypad else "Esc")

func mp_text() -> String:
	return "MP %d/%d" % [_player.mana.mp, _player.mana.max_mp]

func popup_text() -> String:
	var current := _queue.current()
	return current.get("text", "") if not current.is_empty() else ""

func _on_inspect_report(lines: PackedStringArray) -> void:
	_panel.text = "\n".join(lines)
	_panel_left = PANEL_SECONDS
