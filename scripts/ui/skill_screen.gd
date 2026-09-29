class_name SkillScreen
extends CanvasLayer
## Great Sage skill window (Style D): Skills, Compendium, Bestiary, Map and Sound tabs, stats, grouped list and a
## detail card. Esc / Start opens it and pauses the game; Q/E or LB/RB switch tabs;
## Enter / A assigns an active to the U/O slots; Esc / B closes. Laid out for 640x360.

## The five base tabs. A sixth, "form", joins once the body has evolved or can (see tabs()).
const TABS := ["skills", "compendium", "bestiary", "map", "sound"]
const FORM_TAB := "form"
## Five tabs share the top row: they end at x = 532 on the 640 px canvas; six are narrower.
const TAB_X := 28.0
const TAB_STRIDE := 102.0
const TAB_W := 96.0
const TAB_STRIDE_SIX := 88.0
const TAB_W_SIX := 84.0
## Sprite frame used as each creature's Bestiary portrait.
const PORTRAIT := {"bat": "bat_1", "toad": "toad_idle", "lizard": "lizard_1", "spider": "spider_crawl",
	"serpent": "serpent"}
## Creatures that only have a sheet (no single sprite) use this frame of it as their portrait.
const PORTRAIT_FRAME := {"spore_moth": "fly_1", "mushroom_crab": "idle_1", "vine_snake": "hide_1", "pale_moth": "fly_1"}
const ROW_H := 22.0
const HEADER_H := 16.0
const LIST_X := 158.0
const LIST_W := 244.0
const LIST_TOP := 46.0
const LIST_BOTTOM := 320.0
const DETAIL_X := 418.0
const MAP_BOX := Rect2(158, 60, 454, 236)
const COL_MAP_POOL := Color(0.4, 1.0, 0.9)
const COL_DIM_BG := Color(0.0, 0.0, 0.05, 0.6)
const COL_BG := Color(0.03, 0.07, 0.2, 0.94)
const COL_BORDER := Color(0.45, 0.8, 1.0)
const COL_ROW := Color(0.05, 0.11, 0.27, 0.95)
const COL_SELECTED := Color(0.1, 0.32, 0.6, 1.0)
const COL_TITLE := Color(0.55, 0.85, 1.0)
const COL_DIM := Color(0.55, 0.62, 0.75)
const COL_CAPPED := Color(1.0, 0.8, 0.35)
const COL_PIP_ON := Color(0.35, 0.85, 1.0)
const COL_PIP_OFF := Color(0.2, 0.28, 0.42)
const FONT_BIG := 12
const FONT_MAIN := 10
const FONT_SMALL := 8
## Stick navigation: one row per push; held past NAV_DELAY it repeats every NAV_REPEAT.
const NAV_THRESHOLD := 0.5
const NAV_DELAY := 0.35
const NAV_REPEAT := 0.12

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
var _tab_strip := Control.new()
var _hint := Label.new()
var _nav_dir := 0
var _world: World
var _progress
var _map_found := ""
var _map_rooms := 0
var _nav_timer := 0.0

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
	EventBus.world_event.emit("menu_opened", {})

func close() -> void:
	visible = false
	get_tree().paused = false
	EventBus.world_event.emit("menu_closed", {})

func toggle() -> void:
	if visible:
		close()
	else:
		open()

## The tabs showing now: the base five, plus Form once the body has evolved or can.
func tabs() -> Array:
	var t: Array = TABS.duplicate()
	if _form_tab_shown():
		t.append(FORM_TAB)
	return t

func _form_tab_shown() -> bool:
	return _player != null and (_player.form.stage > 1 or _player.progression.can_evolve())

## (stride, width) of a tab for a strip of `n` tabs.
static func tab_layout(n: int) -> Vector2:
	return Vector2(TAB_STRIDE, TAB_W) if n <= TABS.size() else Vector2(TAB_STRIDE_SIX, TAB_W_SIX)

func tab() -> String:
	var t := tabs()
	return t[clampi(_tab, 0, t.size() - 1)]

func switch_tab(i: int) -> void:
	_tab = posmod(i, tabs().size())
	_sel = 0
	_scroll = 0
	_refresh()
	EventBus.world_event.emit("menu_move", {})

func move(delta: int) -> void:
	if _selectable.is_empty():
		return
	var before := _sel
	_sel = clampi(_sel + delta, 0, _selectable.size() - 1)
	_refresh()
	if _sel != before:
		EventBus.world_event.emit("menu_move", {})

func selected_id() -> String:
	if _selectable.is_empty():
		return ""
	return _rows[_selectable[_sel]].get("id", "")

## Evolves a ready evolution (spending EP), or moves the selected active to the next slot
## (U → O → H → L → U).
func accept() -> void:
	var id := selected_id()
	if tab() == FORM_TAB:
		if id != "" and _player.advance_form(id):
			EventBus.world_event.emit("menu_confirm", {})
			_sel = 0
			close()  # the evolution moment plays in the world, not under the menu
			return
		_refresh()
		return
	if id != "" and _rows[_selectable[_sel]]["kind"] == "ready":
		if _player.try_evolve(id):
			EventBus.world_event.emit("menu_confirm", {})
		_refresh()
		return
	if tab() != "skills" or id == "" or SkillEffects.active_scene(_defs[id]) == "":
		return
	var slots := _player.skillset.slots
	slots.assign(slots.next_slot_for(id), id)
	EventBus.world_event.emit("menu_confirm", {})
	_refresh()

## Sound tab: changes the selected slider by one step (direction is -1 or +1).
func adjust(direction: int) -> void:
	if tab() != "sound" or _selectable.is_empty():
		return
	Audio.adjust_setting(str(_rows[_selectable[_sel]]["id"]), direction)
	EventBus.world_event.emit("menu_move", {})
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
			"slot", "creature":
				out.append(r["name"])
	return out

func hint_text() -> String:
	return _hint.text

func detail_texts() -> Array:
	return _detail.find_children("*", "Label", true, false).map(func(l): return l.text)

## Rows to move for a stick reading: an edge-triggered step, then slow repeats while held.
## Stick motion arrives as a stream of events, so reading it per event skipped rows.
func nav_step(stick_y: float, delta: float) -> int:
	var dir := 0
	if stick_y <= -NAV_THRESHOLD:
		dir = -1
	elif stick_y >= NAV_THRESHOLD:
		dir = 1
	if dir == 0:
		_nav_dir = 0
		return 0
	if dir != _nav_dir:
		_nav_dir = dir
		_nav_timer = NAV_DELAY
		return dir
	_nav_timer -= delta
	if _nav_timer <= 0.0:
		_nav_timer = NAV_REPEAT
		return dir
	return 0

func _process(delta: float) -> void:
	if not visible:
		_nav_dir = 0
		return
	var step := nav_step(Controls.last_stick.y, delta)
	if step != 0:
		move(step)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if not visible and _player != null and _player.health.is_dead():
			return  # no menu over the death card: the restart would inherit the pause
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()  # the stick is read in _process
		return
	if event.is_action_pressed("ui_up") or event.is_action_pressed("aim_up"):
		move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("aim_down"):
		move(1)
	elif event.is_action_pressed("tab_prev"):
		switch_tab(_tab - 1)
	elif event.is_action_pressed("tab_next"):
		switch_tab(_tab + 1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		adjust(-1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		adjust(1)
	elif event.is_action_pressed("menu_accept") or event.is_action_pressed("ui_accept"):
		accept()
	elif event.is_action_pressed("menu_back") or event.is_action_pressed("ui_cancel"):
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
	_frame.add_child(_tab_strip)
	_build_tabs()
	for c in [_stats, _list, _detail]:
		_frame.add_child(c)
	_hint.position = Vector2(20, 334)
	_hint.size = Vector2(600, 14)
	_hint.clip_text = true
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", FONT_SMALL)
	_hint.add_theme_color_override("font_color", COL_DIM)
	_frame.add_child(_hint)

## (Re)builds the tab strip for the tabs showing now.
func _build_tabs() -> void:
	_clear(_tab_strip)
	_tab_labels.clear()
	var names := tabs()
	var layout := tab_layout(names.size())
	for i in names.size():
		var tab_panel := _panel(_tab_strip, Vector2(TAB_X + i * layout.x, 10), Vector2(layout.y, 20), COL_ROW, 1)
		var l := _label(tab_panel, str(names[i]).to_upper(), Vector2(0, 3), Vector2(layout.y, 14), FONT_MAIN, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tab_labels.append(tab_panel)

func _refresh() -> void:
	if _player == null:
		return
	if _tab_labels.size() != tabs().size():
		_build_tabs()
	_tab = clampi(_tab, 0, tabs().size() - 1)
	for i in _tab_labels.size():
		var style: StyleBoxFlat = _tab_labels[i].get_theme_stylebox("panel")
		style.bg_color = COL_SELECTED if i == _tab else COL_ROW
	if tab() == "map":
		_rows = []
		_selectable = []
		_hint.text = "LB/RB Tabs    B Back" if Controls.using_joypad else "Q/E Tabs    Esc Back"
		_build_stats()
		_clear(_list)
		_clear(_detail)
		_build_map()
		return
	if tab() == FORM_TAB:
		_refresh_form()
		return
	if tab() == "sound":
		_rows = SkillScreenModel.sound_rows(Audio.settings)
		_selectable = []
		for i in _rows.size():
			_selectable.append(i)
		_sel = clampi(_sel, 0, _rows.size() - 1)
		_hint.text = "LB/RB Tabs    Left/Right Adjust    B Back" if Controls.using_joypad else "Q/E Tabs    A/D Adjust    Esc Back"
		_build_stats()
		_clear(_list)
		_clear(_detail)
		_build_sound()
		return
	match tab():
		"skills":
			_rows = SkillScreenModel.skill_rows(_rules, _all)
		"compendium":
			_rows = SkillScreenModel.compendium_rows(_compendium, _all)
		_:
			_rows = SkillScreenModel.bestiary_rows(_compendium)
	_selectable = []
	for i in _rows.size():
		if ["skill", "slot", "ready", "creature"].has(_rows[i]["kind"]):
			_selectable.append(i)
	_sel = clampi(_sel, 0, maxi(0, _selectable.size() - 1))
	var verb := "Evolve" if not _selectable.is_empty() and _rows[_selectable[_sel]]["kind"] == "ready" else "Assign"
	if tab() == "skills" or verb == "Evolve":
		_hint.text = ("LB/RB Tabs    A %s    B Back" if Controls.using_joypad else "Q/E Tabs    Enter %s    Esc Back") % verb
	else:
		_hint.text = "LB/RB Tabs    B Back" if Controls.using_joypad else "Q/E Tabs    Esc Back"
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
	_bar(_stats, Vector2(36, 106), Vector2(108, 4), float(p.xp) / Progression.xp_to_next(p.level, p.stage), Color(1.0, 0.8, 0.3))
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
	if r["kind"] == "creature":
		_panel(_list, Vector2(LIST_X, y), Vector2(LIST_W, ROW_H - 2), COL_SELECTED if selected else COL_ROW, 2 if selected else 1)
		_portrait(_list, r["id"], r["seen"], Vector2(LIST_X + 3, y + 2), 16)
		_label(_list, r["name"], Vector2(LIST_X + 24, y + 4), Vector2(140, 12), FONT_MAIN, Color.WHITE if r["seen"] else COL_DIM)
		_label(_list, r["status"], Vector2(LIST_X + 170, y + 5), Vector2(70, 10), FONT_SMALL, COL_DIM)
		return
	var locked: bool = r["kind"] == "locked" or r.get("state", -1) == CompendiumModel.State.UNKNOWN
	_panel(_list, Vector2(LIST_X, y), Vector2(LIST_W, ROW_H - 2), COL_SELECTED if selected else COL_ROW, 2 if selected else 1)
	_icon(_list, "icon_locked" if locked else "icon_" + r.get("id", ""), Vector2(LIST_X + 3, y + 2), 16)
	var name_text: String = "???" if r["kind"] == "locked" else r["name"]
	_label(_list, name_text, Vector2(LIST_X + 24, y + 4), Vector2(128, 12), FONT_MAIN, COL_DIM if locked else Color.WHITE)
	if r["kind"] == "skill":
		_label(_list, "Lv%d" % r["level"], Vector2(LIST_X + 156, y + 4), Vector2(28, 12), FONT_MAIN, COL_CAPPED if r.get("capped", false) else Color.WHITE)
		_bar(_list, Vector2(LIST_X + 186, y + 9), Vector2(50, 4), float(r["level"]) / maxf(1.0, float(r["max_level"])), COL_CAPPED if r.get("capped", false) else COL_PIP_ON)
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
	if tab() == "bestiary":
		_build_creature_card(id)
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
	_bar(_detail, Vector2(DETAIL_X + 48, 85), Vector2(140, 4), float(card["level"]) / maxf(1.0, float(card["max_level"])), COL_CAPPED if card.get("capped", false) else COL_PIP_ON)
	_label(_detail, card["description"], Vector2(DETAIL_X, 100), Vector2(190, 30), FONT_SMALL, Color.WHITE, true)
	var y := 134.0
	if card["mp_cost"] > 0:
		_label(_detail, "MP cost %d" % card["mp_cost"], Vector2(DETAIL_X, y), Vector2(190, 12), FONT_MAIN, COL_TITLE)
		y += 14.0
	for line in card["lines"]:
		_label(_detail, line, Vector2(DETAIL_X, y), Vector2(190, 12), FONT_MAIN, Color.WHITE)
		y += 14.0
	if card.get("capped", false):
		_label(_detail, SkillScreenModel.capped_text(), Vector2(DETAIL_X, 262), Vector2(190, 12), FONT_SMALL, COL_CAPPED)
	if card["progress"] >= 0.0:
		_label(_detail, "Next level", Vector2(DETAIL_X, 272), Vector2(100, 12), FONT_SMALL, COL_DIM)
		_bar(_detail, Vector2(DETAIL_X, 286), Vector2(150, 6), card["progress"], COL_CAPPED if card.get("capped", false) else COL_PIP_ON)
	else:
		_label(_detail, "MAX LEVEL", Vector2(DETAIL_X, 280), Vector2(100, 12), FONT_SMALL, COL_TITLE)
	if card["slot"] >= 0:
		var labels: Array = Controls.slot_labels()
		var badge := _panel(_detail, Vector2(DETAIL_X + 160, 276), Vector2(28, 18), COL_ROW, 1)
		var l := _label(badge, "[%s]" % labels[card["slot"]], Vector2(0, 2), Vector2(28, 14), FONT_SMALL, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_creature_card(id: String) -> void:
	var c := SkillScreenModel.bestiary_detail(_compendium, id)
	_portrait(_detail, id, c["seen"], Vector2(DETAIL_X, 50), 40)
	_label(_detail, c["name"], Vector2(DETAIL_X + 46, 52), Vector2(146, 16), FONT_BIG, Color.WHITE)
	if not c["seen"]:
		_label(_detail, "Not yet encountered.", Vector2(DETAIL_X + 46, 70), Vector2(146, 12), FONT_SMALL, COL_DIM)
		return
	_label(_detail, c["status"].capitalize() if c["status"] != "" else "Seen", Vector2(DETAIL_X + 46, 70), Vector2(146, 12), FONT_SMALL, COL_TITLE)
	var lines: Array = []
	if c.has("stats"):
		var st: Dictionary = c["stats"]
		lines.append("HP %d   ATK %d   DEF %d   SPD %d" % [st.get("max_hp", 0), st.get("atk", 0), st.get("def", 0), st.get("spd", 0)])
	elif c.has("hp"):
		lines.append("HP %d" % c["hp"])
	if c.has("essences"):
		var ess: Dictionary = c["essences"]
		lines.append("Essences: " + ", ".join(ess.keys().map(func(k): return "%s %d" % [k, ess[k]])))
		var b: Dictionary = c["eat_bonus"]
		if not b.is_empty():
			lines.append("Eat bonus: +%d %s per %d eaten" % [b.get("amount", 0), str(b.get("stat", "")).to_upper(), b.get("per", 1)])
	if c.has("skills"):
		lines.append("Skills: " + ", ".join(c["skills"]))
	if not c.has("stats") and not c.has("hp"):
		lines.append("Appraise it (I / Y) to learn more.")
	lines.append("Eaten %d    Defeated %d" % [c["eaten"], c["defeated"]])
	var y := 100.0
	for line in lines:
		var l := _label(_detail, line, Vector2(DETAIL_X, y), Vector2(190, 28), FONT_SMALL, Color.WHITE, true)
		y += maxf(14.0, l.get_line_count() * 11.0 + 3.0)

## A creature's portrait: its single sprite, else a frame of its sheet, else the locked icon.
static func portrait_texture(id: String) -> Texture2D:
	if PORTRAIT.has(id):
		return Art.texture(PORTRAIT[id])
	if PORTRAIT_FRAME.has(id) and SpriteSheet.available(id):
		var sheet := SpriteSheet.load_set(id)
		if sheet != null and sheet.has_frame(PORTRAIT_FRAME[id]):
			return sheet.frame_texture(PORTRAIT_FRAME[id])
	return Art.texture("icon_locked")

func _portrait(parent: Node, id: String, seen: bool, pos: Vector2, px: float) -> void:
	var t := TextureRect.new()
	t.texture = portrait_texture(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = Vector2(px, px)
	if not seen:
		t.modulate = Color(0, 0, 0, 0.8)  # silhouette
	parent.add_child(t)

## The Map tab needs the world's rooms and what the player has visited.
func bind_world(world: World, progress) -> void:
	_world = world
	_progress = progress

func map_found_text() -> String:
	return _map_found

func map_room_count() -> int:
	return _map_rooms

func _build_map() -> void:
	_map_found = ""
	_map_rooms = 0
	_label(_list, "MAP", Vector2(LIST_X + 4, LIST_TOP + 2), Vector2(200, 12), FONT_SMALL, COL_TITLE)
	if _world == null or _progress == null or _world.rooms.is_empty():
		_label(_list, "No map yet.", Vector2(LIST_X + 4, LIST_TOP + 20), Vector2(200, 12), FONT_MAIN, COL_DIM)
		return
	var m := SkillScreenModel.map_view(_world.rooms, _progress, _world.current_id)
	var bounds: Rect2 = m["bounds"]
	var scale := minf(MAP_BOX.size.x / bounds.size.x, MAP_BOX.size.y / bounds.size.y)
	for r in m["rooms"]:
		var rect: Rect2 = r["rect"]
		var pos := MAP_BOX.position + (rect.position - bounds.position) * scale
		_panel(_list, pos, rect.size * scale, COL_SELECTED if r["current"] else COL_ROW, 2 if r["current"] else 1)
		var mark := pos + Vector2(3, 3)
		for key in ["pool", "tablet", "rebirth"]:
			if r[key]:
				var dot := ColorRect.new()
				dot.color = COL_MAP_POOL if key == "pool" else (Color(1.0, 0.85, 0.45) if key == "tablet" else (Color(0.9, 0.85, 1.0) if r.get("attuned", false) else Color(0.55, 0.5, 0.7)))
				dot.position = mark
				dot.size = Vector2(3, 3)
				_list.add_child(dot)
				mark.x += 5.0
		_map_rooms += 1
	for s in m["stubs"]:
		var stub := ColorRect.new()
		stub.color = COL_PIP_ON
		stub.size = Vector2(4, 4)
		stub.position = MAP_BOX.position + (s["point"] - bounds.position) * scale - Vector2(2, 2)
		_list.add_child(stub)
	_map_found = m["found"]
	_label(_list, _map_found, Vector2(LIST_X + 4, MAP_BOX.end.y + 6), Vector2(220, 12), FONT_SMALL, COL_DIM)

func _build_sound() -> void:
	_label(_list, "SOUND", Vector2(LIST_X, LIST_TOP), Vector2(200, 14), FONT_BIG, COL_TITLE)
	var y := LIST_TOP + 30.0
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		if i == _sel:
			_panel(_list, Vector2(LIST_X - 4.0, y - 5.0), Vector2(454.0, 24.0), COL_SELECTED, 1)
		_label(_list, r["name"], Vector2(LIST_X, y), Vector2(110, 14), FONT_MAIN, Color.WHITE)
		_bar(_list, Vector2(LIST_X + 120.0, y + 3.0), Vector2(240, 8), r["value"], COL_PIP_ON)
		_label(_list, "%d%%" % int(round(r["value"] * 100.0)), Vector2(LIST_X + 372.0, y), Vector2(60, 14), FONT_MAIN, COL_DIM)
		y += 34.0

# --- helpers --------------------------------------------------------------

## Form tab: the offers are the selectable rows (empty below the level cap).
func _refresh_form() -> void:
	_rows = []
	for f in _player.form_offers():
		_rows.append({"kind": "offer", "id": f.id, "name": f.display_name})
	_selectable = []
	for i in _rows.size():
		_selectable.append(i)
	_sel = clampi(_sel, 0, maxi(0, _selectable.size() - 1))
	if _selectable.is_empty():
		_hint.text = "LB/RB Tabs    B Back" if Controls.using_joypad else "Q/E Tabs    Esc Back"
	else:
		_hint.text = "LB/RB Tabs    A Evolve    B Back" if Controls.using_joypad else "Q/E Tabs    Enter Evolve    Esc Back"
	_build_stats()
	_clear(_list)
	_clear(_detail)
	_build_form()

## The plain slime's sheet, for form thumbnails (loaded once); null if the game has none.
var _base_sheet_cache: SpriteSheet

func _base_sheet() -> SpriteSheet:
	if _base_sheet_cache == null:
		_base_sheet_cache = SpriteSheet.load_set("slime")
	return _base_sheet_cache

## One paragraph about the body: who you are, and what evolving offers (or that it is the only path).
func form_note() -> String:
	var d := _player.form_def()
	var who := "Slime" if d == null else d.display_name
	var note := "%s, stage %d of %d. Skills reach Lv%d." % [who, _player.form.stage, Progression.MAX_STAGE, _player.form.cap()]
	var offers := _player.form_offers()
	if offers.size() == 1:
		note += " Your body can evolve. There is only one path: %s." % (offers[0] as FormDef).display_name
	elif offers.size() > 1:
		note += " Your body can evolve: choose a form."
	elif _player.progression.stage < Progression.MAX_STAGE:
		note += " Reach level %d to evolve." % Progression.LEVEL_CAP
	else:
		note += " This is your final form."
	return note

func _build_form() -> void:
	_label(_list, form_note(), Vector2(LIST_X, LIST_TOP + 4), Vector2(LIST_W, 44), FONT_MAIN, Color.WHITE, true)
	var d := _player.form_def()
	var y := LIST_TOP + 52.0
	if d != null:
		for t in d.traits:
			_label(_list, FormEffects.TRAITS.get(t, str(t)), Vector2(LIST_X, y), Vector2(LIST_W, 12), FONT_SMALL, COL_TITLE)
			y += 12.0
		for line in FormEffects.stat_lines(d):
			_label(_list, line, Vector2(LIST_X, y), Vector2(LIST_W, 12), FONT_SMALL, COL_DIM)
			y += 11.0
		y += 8.0
	if _selectable.is_empty():
		return
	for i in _selectable.size():
		var row: Dictionary = _rows[_selectable[i]]
		var selected := i == _sel
		_panel(_list, Vector2(LIST_X, y), Vector2(LIST_W, ROW_H - 2), COL_SELECTED if selected else COL_ROW, 2 if selected else 1)
		var f: FormDef = _player.forms[row["id"]]
		var look := FormEffects.look(f, _base_sheet())
		var thumb := TextureRect.new()
		thumb.texture = look["texture"]  # null with no sheet: an empty thumbnail, not a crash
		thumb.modulate = look["tint"]
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.position = Vector2(LIST_X + 3, y + 2)
		thumb.size = Vector2(18, 16)
		_list.add_child(thumb)
		_label(_list, row["name"], Vector2(LIST_X + 26, y + 4), Vector2(200, 12), FONT_MAIN, Color.WHITE)
		y += ROW_H
	# the selected offer's card
	var sel: FormDef = _player.forms[_rows[_selectable[_sel]]["id"]]
	var look2 := FormEffects.look(sel, _base_sheet())
	var big := TextureRect.new()
	big.texture = look2["texture"]
	big.modulate = look2["tint"]
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big.position = Vector2(DETAIL_X, 48)
	big.size = Vector2(190, 70)
	_detail.add_child(big)
	_label(_detail, sel.display_name, Vector2(DETAIL_X, 122), Vector2(190, 16), FONT_BIG, Color.WHITE)
	_label(_detail, "Stage %d" % sel.stage, Vector2(DETAIL_X, 138), Vector2(190, 12), FONT_SMALL, COL_TITLE)
	_label(_detail, sel.blurb, Vector2(DETAIL_X, 152), Vector2(190, 34), FONT_SMALL, Color.WHITE, true)
	var dy := 190.0
	for line in FormEffects.stat_lines(sel):
		_label(_detail, line, Vector2(DETAIL_X, dy), Vector2(190, 12), FONT_SMALL, COL_DIM)
		dy += 11.0
	for t in sel.traits:
		_label(_detail, FormEffects.TRAITS.get(t, str(t)), Vector2(DETAIL_X, dy), Vector2(190, 22), FONT_SMALL, COL_TITLE, true)
		dy += 22.0
	var names: Array = []
	for g in sel.grants:
		if _rules.is_retired(g):
			continue  # the player evolved it: the form can no longer give it
		var sd = _defs.get(g)
		names.append(sd.display_name if sd != null else g)
	if not names.is_empty():
		_label(_detail, "Grants: " + ", ".join(names), Vector2(DETAIL_X, dy), Vector2(190, 24), FONT_SMALL, Color.WHITE, true)

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
