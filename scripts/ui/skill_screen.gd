class_name SkillScreen
extends CanvasLayer
## Great Sage skill window (Style D): Skills and Compendium tabs, stats, grouped list and a
## detail card. Esc / Start opens it and pauses the game; Q/E or LB/RB switch tabs;
## Enter / A assigns an active to the U/O slots; Esc / B closes. Laid out for 640x360.

const TABS := ["skills", "compendium"]
const ROW_H := 22.0
const HEADER_H := 16.0
const LIST_X := 158.0
const LIST_W := 244.0
const LIST_TOP := 46.0
const LIST_BOTTOM := 320.0
const DETAIL_X := 418.0
const COL_DIM_BG := Color(0.0, 0.0, 0.05, 0.6)
const COL_BG := Color(0.03, 0.07, 0.2, 0.94)
const COL_BORDER := Color(0.45, 0.8, 1.0)
const COL_ROW := Color(0.05, 0.11, 0.27, 0.95)
const COL_SELECTED := Color(0.1, 0.32, 0.6, 1.0)
const COL_TITLE := Color(0.55, 0.85, 1.0)
const COL_DIM := Color(0.55, 0.62, 0.75)
const COL_PIP_ON := Color(0.35, 0.85, 1.0)
const COL_PIP_OFF := Color(0.2, 0.28, 0.42)
const FONT_BIG := 12
const FONT_MAIN := 10
const FONT_SMALL := 8

var _player: Player
var _rules
var _compendium: CompendiumModel
var _all: Array = []
var _defs := {}
var _tab := 0
var _rows: Array = []
var _selectable: Array = []  # indices into _rows
var _sel := 0
var _scroll := 0
var _frame := Control.new()
var _list := Control.new()
var _detail := Control.new()
var _stats := Control.new()
var _tab_labels: Array = []
var _hint := Label.new()

func bind(player: Player, rules, compendium: CompendiumModel, skill_defs: Array) -> void:
	_player = player
	_rules = rules
	_compendium = compendium
	_all = skill_defs
	for d in skill_defs:
		_defs[d.id] = d

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_frame()

func is_open() -> bool:
	return visible

func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func tab() -> String:
	return TABS[_tab]

func switch_tab(i: int) -> void:
	_tab = posmod(i, TABS.size())
	_sel = 0
	_scroll = 0
	_refresh()

func move(delta: int) -> void:
	if _selectable.is_empty():
		return
	_sel = clampi(_sel + delta, 0, _selectable.size() - 1)
	_refresh()

func selected_id() -> String:
	if _selectable.is_empty():
		return ""
	return _rows[_selectable[_sel]].get("id", "")

## Evolves a ready evolution (spending EP), or moves the selected active to the next slot
## (U → O → H → L → U).
func accept() -> void:
	var id := selected_id()
	if id != "" and _rows[_selectable[_sel]]["kind"] == "ready":
		_player.try_evolve(id)
		_refresh()
		return
	if tab() != "skills" or id == "" or SkillEffects.active_scene(_defs[id]) == "":
		return
	var slots := _player.skillset.slots
	slots.assign(slots.next_slot_for(id), id)
	_refresh()

func row_texts() -> Array:
	var out: Array = []
	for r in _rows:
		match r["kind"]:
			"header":
				out.append(r["text"])
			"skill":
				out.append("%s Lv%d" % [r["name"], r["level"]])
			"locked":
				out.append("???")
			"ready":
				out.append("%s  EVOLVE %d EP" % [r["name"], r["cost"]])
			"slot":
				out.append(r["name"])
	return out

func detail_texts() -> Array:
	return _detail.find_children("*", "Label", true, false).map(func(l): return l.text)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		move(1)
	elif event.is_action_pressed("tab_prev"):
		switch_tab(_tab - 1)
	elif event.is_action_pressed("tab_next"):
		switch_tab(_tab + 1)
	elif event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("ui_cancel"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()

# --- building -------------------------------------------------------------

func _build_frame() -> void:
	var dim := ColorRect.new()
	dim.color = COL_DIM_BG
	dim.size = Vector2(640, 360)
	add_child(dim)
	add_child(_frame)
	_panel(_frame, Vector2(20, 34), Vector2(600, 292), COL_BG, 2)
	_panel(_frame, Vector2(28, 40), Vector2(124, 280), Color(0.02, 0.05, 0.14, 0.9), 1)
	_panel(_frame, Vector2(410, 40), Vector2(202, 280), Color(0.02, 0.05, 0.14, 0.9), 1)
	for i in TABS.size():
		var tab_panel := _panel(_frame, Vector2(28 + i * 128, 10), Vector2(120, 20), COL_ROW, 1)
		var l := _label(tab_panel, TABS[i].to_upper(), Vector2(0, 3), Vector2(120, 14), FONT_MAIN, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tab_labels.append(tab_panel)
	for c in [_stats, _list, _detail]:
		_frame.add_child(c)
	_hint.position = Vector2(20, 334)
	_hint.size = Vector2(600, 14)
	_hint.clip_text = true
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", FONT_SMALL)
	_hint.add_theme_color_override("font_color", COL_DIM)
	_frame.add_child(_hint)

func _refresh() -> void:
	if _player == null:
		return
	for i in _tab_labels.size():
		var style: StyleBoxFlat = _tab_labels[i].get_theme_stylebox("panel")
		style.bg_color = COL_SELECTED if i == _tab else COL_ROW
	_rows = SkillScreenModel.skill_rows(_rules, _all) if tab() == "skills" else SkillScreenModel.compendium_rows(_compendium, _all)
	_selectable = []
	for i in _rows.size():
		if ["skill", "slot", "ready"].has(_rows[i]["kind"]):
			_selectable.append(i)
	_sel = clampi(_sel, 0, maxi(0, _selectable.size() - 1))
	_hint.text = "LB/RB Tabs    A Assign    B Back" if Controls.using_joypad else "Q/E Tabs    Enter Assign    Esc Back"
	_build_stats()
	_build_list()
	_build_detail()

func _build_stats() -> void:
	_clear(_stats)
	var portrait := TextureRect.new()
	portrait.texture = Art.texture("slime_idle")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.position = Vector2(40, 44)
	portrait.size = Vector2(100, 46)
	_stats.add_child(portrait)
	var h := _player.health
	var m := _player.mana
	var p := _player.progression
	_label(_stats, "Lv %d    EP %d" % [p.level, p.ep], Vector2(36, 92), Vector2(110, 12), FONT_MAIN, Color(1.0, 0.85, 0.45))
	_bar(_stats, Vector2(36, 106), Vector2(108, 4), float(p.xp) / Progression.xp_to_next(p.level), Color(1.0, 0.8, 0.3))
	_label(_stats, "HP  %d/%d" % [h.hp, h.max_hp], Vector2(36, 114), Vector2(110, 12), FONT_MAIN, Color.WHITE)
	_bar(_stats, Vector2(36, 128), Vector2(108, 6), float(h.hp) / h.max_hp, Color(0.85, 0.25, 0.3))
	_label(_stats, "MP  %d/%d" % [m.mp, m.max_mp], Vector2(36, 138), Vector2(110, 12), FONT_MAIN, Color.WHITE)
	_bar(_stats, Vector2(36, 152), Vector2(108, 6), float(m.mp) / maxi(1, m.max_mp), Color(0.3, 0.6, 1.0))
	var y := 166.0
	for key in ["atk", "def", "spd"]:
		_label(_stats, "%s   %d" % [key.to_upper(), _player.stats.get_stat(key)], Vector2(36, y), Vector2(110, 12), FONT_MAIN, Color.WHITE)
		y += 14.0
	_label(_stats, "Essences", Vector2(36, y + 6), Vector2(110, 10), FONT_SMALL, COL_TITLE)
	y += 18.0
	for ess in Essences.ALL:
		var n: int = _rules.count(Events.ABSORBED, {"essence": ess})
		if n > 0 and y < 306.0:
			_label(_stats, "%s  %d" % [ess, n], Vector2(40, y), Vector2(106, 10), FONT_SMALL, COL_DIM)
			y += 11.0

func _build_list() -> void:
	_clear(_list)
	var sel_row: int = _selectable[_sel] if not _selectable.is_empty() else -1
	# Scroll so the selected row stays visible.
	var needed := 0.0
	for i in range(_scroll, maxi(sel_row + 1, _scroll)):
		needed += _row_height(_rows[i])
	while sel_row >= 0 and needed > LIST_BOTTOM - LIST_TOP and _scroll < sel_row:
		needed -= _row_height(_rows[_scroll])
		_scroll += 1
	if sel_row >= 0 and sel_row < _scroll:
		_scroll = sel_row
	var y := LIST_TOP
	for i in range(_scroll, _rows.size()):
		var r: Dictionary = _rows[i]
		if y + _row_height(r) > LIST_BOTTOM:
			break
		if r["kind"] == "header":
			_label(_list, r["text"], Vector2(LIST_X + 4, y + 2), Vector2(LIST_W - 8, 12), FONT_SMALL, COL_TITLE)
		else:
			_build_row(r, y, i == sel_row)
		y += _row_height(r)

func _build_row(r: Dictionary, y: float, selected: bool) -> void:
	var locked: bool = r["kind"] == "locked" or r.get("state", -1) == CompendiumModel.State.UNKNOWN
	_panel(_list, Vector2(LIST_X, y), Vector2(LIST_W, ROW_H - 2), COL_SELECTED if selected else COL_ROW, 2 if selected else 1)
	_icon(_list, "icon_locked" if locked else "icon_" + r.get("id", ""), Vector2(LIST_X + 3, y + 2), 16)
	var name_text: String = "???" if r["kind"] == "locked" else r["name"]
	_label(_list, name_text, Vector2(LIST_X + 24, y + 4), Vector2(128, 12), FONT_MAIN, COL_DIM if locked else Color.WHITE)
	if r["kind"] == "skill":
		_label(_list, "Lv%d" % r["level"], Vector2(LIST_X + 156, y + 4), Vector2(28, 12), FONT_MAIN, Color.WHITE)
		_pips(_list, Vector2(LIST_X + 186, y + 8), r["level"], r["max_level"])
	elif r["kind"] == "ready":
		_label(_list, "EVOLVE %d EP" % r["cost"], Vector2(LIST_X + 170, y + 5), Vector2(70, 10), FONT_SMALL, Color(1.0, 0.85, 0.45))
	elif r["kind"] == "slot":
		var state_text: String = ["", "known", "hinted", "found"][r["state"]]
		_label(_list, state_text, Vector2(LIST_X + 186, y + 5), Vector2(54, 10), FONT_SMALL, COL_DIM)

func _build_detail() -> void:
	_clear(_detail)
	var id := selected_id()
	if id == "":
		_label(_detail, "No skills yet.", Vector2(DETAIL_X, 52), Vector2(190, 12), FONT_MAIN, COL_DIM)
		return
	var d: SkillDef = _defs[id]
	if tab() == "compendium":
		var r: Dictionary = _rows[_selectable[_sel]]
		var unknown: bool = r["state"] == CompendiumModel.State.UNKNOWN
		_icon(_detail, "icon_locked" if unknown else "icon_" + id, Vector2(DETAIL_X, 50), 40)
		_label(_detail, r["name"], Vector2(DETAIL_X + 46, 52), Vector2(146, 16), FONT_BIG, Color.WHITE)
		_label(_detail, ["Undiscovered", "Known", "Hinted", "Discovered"][r["state"]], Vector2(DETAIL_X + 46, 70), Vector2(146, 12), FONT_SMALL, COL_TITLE)
		var y := 100.0
		if r.has("hint"):
			_label(_detail, r["hint"], Vector2(DETAIL_X, y), Vector2(190, 34), FONT_SMALL, Color.WHITE, true)
			y += 38.0
		if r.has("condition"):
			_label(_detail, "How: " + r["condition"], Vector2(DETAIL_X, y), Vector2(190, 46), FONT_SMALL, COL_DIM, true)
		return
	if _rows[_selectable[_sel]]["kind"] == "ready":
		var cost: int = _rules.evolution_cost(id)
		_icon(_detail, "icon_" + id, Vector2(DETAIL_X, 50), 40)
		_label(_detail, d.display_name, Vector2(DETAIL_X + 46, 50), Vector2(146, 16), FONT_BIG, Color.WHITE)
		_label(_detail, "Ready to evolve", Vector2(DETAIL_X + 46, 68), Vector2(146, 12), FONT_MAIN, Color(1.0, 0.85, 0.45))
		_label(_detail, d.description, Vector2(DETAIL_X, 100), Vector2(190, 30), FONT_SMALL, Color.WHITE, true)
		_label(_detail, "Costs %d EP  (you have %d)" % [cost, _player.progression.ep], Vector2(DETAIL_X, 134), Vector2(190, 12), FONT_MAIN, COL_TITLE)
		var can := _player.progression.ep >= cost
		_label(_detail, ("[%s] Evolve" % ("A" if Controls.using_joypad else "Enter")) if can else "Level up to earn EP",
			Vector2(DETAIL_X, 152), Vector2(190, 12), FONT_MAIN, Color.WHITE if can else COL_DIM)
		return
	var card := SkillScreenModel.detail(_rules, d, _player.skillset.slots)
	_icon(_detail, "icon_" + id, Vector2(DETAIL_X, 50), 40)
	_label(_detail, card["name"], Vector2(DETAIL_X + 46, 50), Vector2(146, 16), FONT_BIG, Color.WHITE)
	_label(_detail, "Lv %d / %d" % [card["level"], card["max_level"]], Vector2(DETAIL_X + 46, 68), Vector2(80, 12), FONT_MAIN, COL_TITLE)
	_pips(_detail, Vector2(DETAIL_X + 48, 84), card["level"], card["max_level"])
	_label(_detail, card["description"], Vector2(DETAIL_X, 100), Vector2(190, 30), FONT_SMALL, Color.WHITE, true)
	var y := 134.0
	if card["mp_cost"] > 0:
		_label(_detail, "MP cost %d" % card["mp_cost"], Vector2(DETAIL_X, y), Vector2(190, 12), FONT_MAIN, COL_TITLE)
		y += 14.0
	for line in card["lines"]:
		_label(_detail, line, Vector2(DETAIL_X, y), Vector2(190, 12), FONT_MAIN, Color.WHITE)
		y += 14.0
	if card["progress"] >= 0.0:
		_label(_detail, "Next level", Vector2(DETAIL_X, 272), Vector2(100, 12), FONT_SMALL, COL_DIM)
		_bar(_detail, Vector2(DETAIL_X, 286), Vector2(150, 6), card["progress"], COL_PIP_ON)
	else:
		_label(_detail, "MAX LEVEL", Vector2(DETAIL_X, 280), Vector2(100, 12), FONT_SMALL, COL_TITLE)
	if card["slot"] >= 0:
		var labels: Array = Controls.slot_labels()
		var badge := _panel(_detail, Vector2(DETAIL_X + 160, 276), Vector2(28, 18), COL_ROW, 1)
		var l := _label(badge, "[%s]" % labels[card["slot"]], Vector2(0, 2), Vector2(28, 14), FONT_SMALL, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# --- helpers --------------------------------------------------------------

func _row_height(r: Dictionary) -> float:
	return HEADER_H if r["kind"] == "header" else ROW_H

func _clear(node: Node) -> void:
	for c in node.get_children():
		c.free()

func _panel(parent: Node, pos: Vector2, size: Vector2, color: Color, border: int) -> Panel:
	var p := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = COL_BORDER
	style.set_border_width_all(border)
	style.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", style)
	p.position = pos
	p.size = size
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, pos: Vector2, size: Vector2, font: int, color: Color, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", color)
	l.clip_text = true
	parent.add_child(l)
	if wrap:
		# Wrap width must be fixed after entering the tree, or the label sizes to one line.
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(size.x, 0)
	l.size = size
	return l

func _icon(parent: Node, sprite: String, pos: Vector2, px: float) -> void:
	var t := TextureRect.new()
	t.texture = Art.texture(sprite)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = pos
	t.size = Vector2(px, px)
	parent.add_child(t)

func _pips(parent: Node, pos: Vector2, level: int, max_level: int) -> void:
	for i in max_level:
		var pip := ColorRect.new()
		pip.color = COL_PIP_ON if i < level else COL_PIP_OFF
		pip.position = pos + Vector2(i * 8, 0)
		pip.size = Vector2(5, 5)
		parent.add_child(pip)

func _bar(parent: Node, pos: Vector2, size: Vector2, fraction: float, color: Color) -> void:
	var back := ColorRect.new()
	back.color = Color(0.1, 0.12, 0.2)
	back.position = pos
	back.size = size
	parent.add_child(back)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = pos
	fill.size = Vector2(size.x * clampf(fraction, 0.0, 1.0), size.y)
	parent.add_child(fill)
