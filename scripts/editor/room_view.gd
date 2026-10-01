class_name RoomView
extends Node2D
## The room as the game draws it (RoomBuilder and TerrainPainter), seen through a Camera2D in the root viewport. Overlays
## (markers, selection outlines, the drag rect) live on a follow_viewport CanvasLayer so the per-area CanvasModulate does not
## dim them. All positions are in the 640x360 viewport space the project's canvas_items stretch gives mouse events.

const PICK_PX := 8.0
const CLICK_PX := 3.0  # a Select press becomes a drag only after the pointer has travelled this many screen pixels
const ZOOM_MIN := 0.25
const ZOOM_MAX := 4.0

signal changed
signal message(text: String)
signal selection_changed

## "select", "solid", "creature", "exit" or "feature".
var tool := "select"
var creature_id := ""
var feature_kind := "tablet"  # what the Feature tool places
var camera := Camera2D.new()
var overlay := Node2D.new()
var _model: RoomEditModel
var _room_id := ""
var _room: Node2D
var _tint := CanvasModulate.new()
var _overlay_layer := CanvasLayer.new()
var _pressed := false          # the left button is down for the current tool
var _panning := false
var _press_room := Vector2.ZERO
var _rect_live := Rect2()      # the Solid tool's drag
var _live_text := ""
var _exit_edge := ""
var _exit_live := Vector2(-1.0, -1.0)  # the Exit tool's span along its edge
var _serial_at_press := 0     # the model's edit counter when a Select press began
var _press_screen := Vector2.ZERO  # where the press was, in screen pixels (the drag threshold is measured there)
var _dragging := false         # the Select press has become a drag

func _ready() -> void:
	camera.name = "Camera"
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT  # position is the room point at the screen's top-left corner
	add_child(camera)
	camera.make_current()
	add_child(_tint)
	_overlay_layer.follow_viewport_enabled = true
	_overlay_layer.layer = 5
	add_child(_overlay_layer)
	_overlay_layer.add_child(overlay)

## Rebuilds the room node from the model and fits the room on screen.
func show_room(model: RoomEditModel, room_id: String) -> void:
	_model = model
	_room_id = room_id
	if _room != null:
		remove_child(_room)  # out of the tree at once: the new room may reuse its name, and its gates leave their groups
		_room.queue_free()
	var def: RoomDef = model.rooms[room_id]
	_room = RoomBuilder.build_room(def, {"progress": null})  # no progress: closed shortcuts draw as gates
	_room.position = Vector2.ZERO
	_ignore_mouse(_room)
	add_child(_room)
	_tint.color = TerrainArt.ambient(def.area, Game.AMBIENT)
	fit()
	_redraw_overlay()

## The built room is decoration here: none of its Controls (tiles, backdrops) may swallow a click meant for the tools.
static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse(c)

func room_node() -> Node2D:
	return _room

func room_id() -> String:
	return _room_id

func to_room(screen: Vector2) -> Vector2:
	return camera.position + screen / camera.zoom.x

func to_screen(room_pt: Vector2) -> Vector2:
	return (room_pt - camera.position) * camera.zoom.x

## The pick radius in room pixels: a fixed 8 screen pixels however far the view is zoomed.
func pick_radius() -> float:
	return PICK_PX / camera.zoom.x

func fit() -> void:
	fit_in(Rect2(Vector2.ZERO, Vector2(640, 360)))

## Fits the whole room into `free`, a screen rectangle (the part of the window the panels leave open).
func fit_in(free: Rect2) -> void:
	var size: Vector2 = _model.rooms[_room_id].pixel_size()
	var z := minf(free.size.x / size.x, free.size.y / size.y)
	camera.zoom = Vector2(z, z)
	camera.position = size / 2.0 - free.get_center() / z

## Pans (never zooms) so the room rectangle `rect` is at the centre of the screen rectangle `free`.
func center_on(rect: Rect2, free: Rect2) -> void:
	camera.position = rect.get_center() - free.get_center() / camera.zoom.x

## The room-space rectangle of the current selection, or an empty Rect2.
func selection_rect() -> Rect2:
	var sel := _model.selection
	if sel.is_empty() or sel["room"] != _room_id:
		return Rect2()
	return _selection_rect(_model.rooms[_room_id], sel)

func one_to_one() -> void:
	var c := to_room(Vector2(320, 180))
	camera.zoom = Vector2.ONE
	camera.position = c - Vector2(320, 180)

func pan(delta_screen: Vector2) -> void:
	camera.position -= delta_screen / camera.zoom.x

## Zooms by `factor` keeping the room point under `around` (a screen point) where it is.
func zoom_by(factor: float, around: Vector2) -> void:
	var before := to_room(around)
	var z := clampf(camera.zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)
	camera.position = before - around / z

func state() -> Dictionary:
	return {"zoom": camera.zoom.x, "position": camera.position}

func restore(s: Dictionary) -> void:
	if s.has("zoom"):
		camera.zoom = Vector2(float(s["zoom"]), float(s["zoom"]))
		camera.position = s.get("position", camera.position)

# --- input ---

func live_label() -> String:
	return _live_text

## Mouse, wheel and Delete/Backspace. Returns true when the event was used. Mouse positions are viewport (screen) points.
func handle_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _button(event)
	if event is InputEventMouseMotion:
		return _motion(event)
	if event is InputEventPanGesture:
		pan(-(event as InputEventPanGesture).delta * 8.0)
		return true
	if event is InputEventMagnifyGesture:
		zoom_by((event as InputEventMagnifyGesture).factor, (event as InputEventMagnifyGesture).position)
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			_report(_model.delete_selection())
			return true
	return false

func _button(e: InputEventMouseButton) -> bool:
	match e.button_index:
		MOUSE_BUTTON_MIDDLE:
			_panning = e.pressed
			return true
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				var up := e.button_index == MOUSE_BUTTON_WHEEL_UP
				if e.ctrl_pressed or e.meta_pressed:
					zoom_by(1.1 if up else 1.0 / 1.1, e.position)
				else:
					pan(Vector2(0.0, 24.0 if up else -24.0))
			return true
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				_press(to_room(e.position), e.alt_pressed, e.position)
			else:
				_release(to_room(e.position))
			return true
	return false

func _motion(e: InputEventMouseMotion) -> bool:
	if _panning or (e.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		pan(e.relative)
		return true
	if not _pressed:
		return false
	var p := to_room(e.position)
	match tool:
		"select":
			if not _dragging and e.position.distance_to(_press_screen) < CLICK_PX:
				return true  # a click with a little jitter is not a drag
			_dragging = true
			_model.move_to(p - _press_room)
		"solid":
			_rect_live = RoomEditModel.drag_rect(_press_room, p).intersection(RoomEditModel.bounds(_model.rooms[_room_id]))
			_live_text = RoomEditModel.label_for(_rect_live, _model.rooms[_room_id].hard_ledges)
		"exit":
			var a := _along(_exit_edge, _press_room)
			var b := _along(_exit_edge, p)
			_exit_live = Vector2(minf(a, b), maxf(a, b))
	_redraw_overlay()
	return true

## A click in the room is the end of any inspector edit: releasing focus commits a pending LineEdit before the room is rebuilt.
func _commit_pending() -> void:
	get_viewport().gui_release_focus()

## A plain press takes the first candidate (what hit returns). An Alt press takes the one after the current selection, wrapping;
## the first when the selection is not among them.
func _pick_candidate(cands: Array, alt: bool) -> Dictionary:
	if cands.is_empty():
		return {}
	if not alt:
		return cands[0]
	return cands[(cands.find(_model.selection) + 1) % cands.size()]  # find is -1 when absent, so the first

func _press(p: Vector2, alt := false, screen := Vector2.ZERO) -> void:
	_commit_pending()
	_pressed = true
	_press_room = p
	_press_screen = screen
	_dragging = false
	match tool:
		"select":
			var sel := _pick_candidate(_model.hit_all(_room_id, p, pick_radius()), alt)
			_model.select(sel)
			if not sel.is_empty():
				_model.begin_move(sel)
			selection_changed.emit()
			_serial_at_press = _model.serial
		"solid":
			_rect_live = Rect2(Vector2(RoomEditModel.snap(p.x), RoomEditModel.snap(p.y)), Vector2.ZERO)
			_live_text = ""
		"exit":
			_exit_edge = _nearest_edge(p)
			_exit_live = Vector2(_along(_exit_edge, p), _along(_exit_edge, p))
		_:
			pass  # "creature" and "feature" place on release
	_redraw_overlay()

func _release(p: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	match tool:
		"select":
			_model.end_move()
			if _model.serial != _serial_at_press:
				_after_edit()
			else:
				_redraw_overlay()
		"solid":
			_rect_live = Rect2()
			_live_text = ""
			_report(_model.add_solid(_room_id, _press_room, p))
		"creature":
			if creature_id == "":
				message.emit("choose a creature in the palette first")
			else:
				_report(_model.add_spawn(_room_id, creature_id, p))
		"feature":
			_report(_model.add_feature(_room_id, feature_kind, p))
		"exit":
			_exit_live = Vector2(-1.0, -1.0)
			_report(_model.add_exit(_room_id, _exit_edge, _along(_exit_edge, _press_room), _along(_exit_edge, p)))

## A refusal goes to the status bar; a success rebuilds the room.
func _report(err: String) -> void:
	if err != "":
		message.emit(err)
		_redraw_overlay()
	else:
		_after_edit()

func _after_edit() -> void:
	var s := state()
	show_room(_model, _room_id)
	restore(s)
	_redraw_overlay()
	changed.emit()

## Rebuilds the room and overlay after an undo or redo (or any change made outside the view).
func refresh() -> void:
	_after_edit()

func _nearest_edge(p: Vector2) -> String:
	var size: Vector2 = _model.rooms[_room_id].pixel_size()
	var best := "left"
	var best_d := p.x
	for pair in [["right", size.x - p.x], ["top", p.y], ["bottom", size.y - p.y]]:
		if pair[1] < best_d:
			best = pair[0]
			best_d = pair[1]
	return best

static func _along(edge: String, p: Vector2) -> float:
	return p.y if edge == "left" or edge == "right" else p.x

# --- overlay: markers, exits, the selection and the live drag (untinted, above the room) ---

const COL_EXIT := Color(0.3, 0.85, 1.0, 0.45)
const COL_EXIT_GATED := Color(1.0, 0.65, 0.2, 0.45)
const COL_SELECT := Color(1.0, 1.0, 0.3, 1.0)
const COL_LIVE := Color(1.0, 1.0, 1.0, 0.9)
const COL_UNKNOWN := Color(1.0, 0.15, 0.15, 0.9)

func markers() -> Array:
	return overlay.get_children().filter(func(n: Node) -> bool: return n.is_in_group("editor_marker"))

## The texture a creature marker shows: the sheet's idle (else first) frame, else the single sprite, else null.
static func marker_texture(id: String) -> Texture2D:
	if SpriteSheet.available(id):
		var sheet := SpriteSheet.load_set(id)
		if sheet != null:
			var names := sheet.frame_names()
			if not names.is_empty():
				var pick: String = names[0]
				for n in names:
					if String(n).contains("idle"):
						pick = n
						break
				return sheet.frame_texture(pick)
	return Art.texture(id)

func _clear_overlay() -> void:
	for c in overlay.get_children():
		overlay.remove_child(c)
		c.queue_free()

func _redraw_overlay() -> void:
	if _model == null or not is_inside_tree():
		return
	_clear_overlay()
	var r: RoomDef = _model.rooms[_room_id]
	var size := r.pixel_size()
	for e in r.exits:
		var band := RoomBuilder.gate_rect(size, e)
		_box(band, COL_EXIT_GATED if (e.has("gate") or e.has("shortcut")) else COL_EXIT, false)
	for i in r.spawns.size():
		_marker(i, r.spawns[i])
	for i in r.features.size():
		_feature_marker(i, r.features[i])
	var sel := _model.selection
	if not sel.is_empty() and sel["room"] == _room_id:
		var outline := _selection_rect(r, sel)
		if outline.size != Vector2.ZERO:
			_box(outline.grow(2.0), COL_SELECT, true)
	if _rect_live.size != Vector2.ZERO or _live_text != "":
		_box(_rect_live, COL_LIVE, true)
		_label(_live_text, _rect_live.position + Vector2(0.0, -10.0))
	if _exit_live.x >= 0.0 and _exit_live.y > _exit_live.x:
		var live := {"edge": _exit_edge, "from": _exit_live.x, "to": _exit_live.y}
		_box(RoomBuilder.gate_rect(size, live), COL_LIVE, true)

func _selection_rect(r: RoomDef, sel: Dictionary) -> Rect2:
	var i: int = sel["index"]
	match sel["kind"]:
		"solid":
			return r.solids[i] if i < r.solids.size() else Rect2()
		"spawn":
			return Rect2((r.spawns[i]["pos"] as Vector2) - Vector2(8, 16), Vector2(16, 20)) if i < r.spawns.size() else Rect2()
		"exit":
			return RoomBuilder.gate_rect(r.pixel_size(), r.exits[i]) if i < r.exits.size() else Rect2()
		"feature":
			if i >= r.features.size():
				return Rect2()
			var box: Rect2 = RoomLint.FEATURE_BOX.get(r.features[i].get("kind", ""), Rect2(-6, -12, 12, 12))
			return Rect2(box.position + (r.features[i]["pos"] as Vector2), box.size)
		_:
			return Rect2()

func _box(rect: Rect2, color: Color, outline: bool) -> void:
	if outline:
		var line := Line2D.new()
		line.width = 1.5
		line.default_color = color
		line.points = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y), rect.position])
		overlay.add_child(line)
	else:
		var fill := ColorRect.new()
		fill.color = color
		fill.position = rect.position
		fill.size = rect.size
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.add_child(fill)

func _label(text: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(l)

## A static stand-in for a creature: its sprite, or a red box for an id the data no longer has, or a labelled box.
func _marker(index: int, spawn: Dictionary) -> void:
	var id: String = spawn.get("id", "")
	var holder := Node2D.new()
	holder.position = spawn["pos"]
	holder.add_to_group("editor_marker")
	holder.set_meta("index", index)
	var known := _model.creature_ids.is_empty() or _model.creature_ids.has(id)
	var tex := marker_texture(id) if known else null
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.name = "Sprite"
		sprite.texture = tex
		sprite.centered = false
		sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		sprite.position = Vector2(0.0, 6.0)  # the frame's bottom sits where the enemy's does (Enemy.BODY_BOTTOM)
		holder.add_child(sprite)
	else:
		var box := ColorRect.new()
		box.color = COL_UNKNOWN if not known else Color(0.7, 0.7, 0.7, 0.8)
		box.position = Vector2(-6, -12)
		box.size = Vector2(12, 12)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(box)
		var l := Label.new()
		l.text = id
		l.position = Vector2(-6, -22)
		l.add_theme_font_size_override("font_size", 6)
		holder.add_child(l)
		if not known:
			holder.set_meta("unknown", true)
	overlay.add_child(holder)

const FEATURE_TINT := {
	"tablet": Color(0.7, 0.7, 0.75, 0.35),
	"switch": Color(0.65, 0.4, 0.2, 0.35),
	"glow_pool": Color(0.3, 0.9, 0.8, 0.3),
	"rebirth_pool": Color(0.8, 0.45, 1.0, 0.3),
}

## A translucent box over a feature, the size of its hit box (RoomLint.FEATURE_BOX), so the built art shows through and a click
## on it selects the feature.
func _feature_marker(index: int, f: Dictionary) -> void:
	var holder := Node2D.new()
	holder.position = f["pos"]
	holder.add_to_group("editor_marker")
	holder.set_meta("feature", index)
	var box: Rect2 = RoomLint.FEATURE_BOX.get(f.get("kind", ""), Rect2(-6, -12, 12, 12))
	var fill := ColorRect.new()
	fill.color = FEATURE_TINT.get(f.get("kind", ""), Color(1.0, 1.0, 1.0, 0.3))
	fill.position = box.position
	fill.size = box.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	overlay.add_child(holder)
