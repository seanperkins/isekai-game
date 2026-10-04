class_name SkillTreeView
extends Control
## The Tree tab's drawing: a clipped box filled with one panel per node and one _draw pass for the edges. The camera is a
## pure function of the selected node and the zoom level (camera()), so a rebuild with the same two draws the same picture.
## Clicks and the wheel arrive through gui_input and leave as signals deferred to the end of the frame: the screen rebuilds
## on them, and a panel must not be freed while its own gui_input is running.

signal node_clicked(id: String)
signal zoom_requested(overview: bool)

## The skill screen's list column; the card stays beside it.
const BOX := Rect2(158, 46, 244, 274)
const COL_STUB := Color(0.03, 0.06, 0.16, 0.9)

## The edges as drawn, in box coordinates: [{"a", "b", "color"}], from the right middle of the first node to the left
## middle of the second.
var segments: Array = []
var _panels := {}

func _init() -> void:
	position = BOX.position
	size = BOX.size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input.bind(""))

## {"scale", "offset"}: a node's box position is offset + pos * scale. The overview fits the whole canvas in the box. The
## normal zoom is 1:1 and centred on the selected node together with its edge neighbors, as far as that keeps the
## selection itself inside the box, then clamped to the canvas. The selection is always inside the box, and so is every
## neighbor whenever the group fits.
static func camera(model: Dictionary, sel: String, overview: bool, box_size := BOX.size) -> Dictionary:
	var canvas: Vector2 = model["size"]
	if overview:
		var s := minf(1.0, minf(box_size.x / maxf(1.0, canvas.x), box_size.y / maxf(1.0, canvas.y)))
		return {"scale": s, "offset": ((box_size - canvas * s) / 2.0).floor()}
	var focus := canvas / 2.0
	if model["nodes"].has(sel):
		var me := Rect2(model["nodes"][sel]["pos"], SkillTreeModel.NODE_SIZE)
		focus = neighborhood(model, sel).get_center()
		focus.x = clampf(focus.x, me.end.x - box_size.x / 2.0, me.position.x + box_size.x / 2.0)
		focus.y = clampf(focus.y, me.end.y - box_size.y / 2.0, me.position.y + box_size.y / 2.0)
	return {"scale": 1.0, "offset": Vector2(_axis(box_size.x, canvas.x, focus.x), _axis(box_size.y, canvas.y, focus.y)).floor()}

## The canvas rect around a node and every node an edge joins it to.
static func neighborhood(model: Dictionary, id: String) -> Rect2:
	var nodes: Dictionary = model["nodes"]
	var r := Rect2(nodes[id]["pos"], SkillTreeModel.NODE_SIZE)
	for e in model["edges"]:
		if e["from"] == id:
			r = r.merge(Rect2(nodes[e["to"]]["pos"], SkillTreeModel.NODE_SIZE))
		elif e["to"] == id:
			r = r.merge(Rect2(nodes[e["from"]]["pos"], SkillTreeModel.NODE_SIZE))
	return r

static func _axis(box: float, canvas: float, focus: float) -> float:
	if canvas <= box:
		return (box - canvas) / 2.0
	return clampf(box / 2.0 - focus, box - canvas, 0.0)

## A node's colours, {"bg", "border", "text"}: a ready evolution and the current form are outlined in gold; retired, closed
## and stub nodes are dim; a named node's text is dim.
static func look_for(state: String, selected: bool) -> Dictionary:
	var look := {"bg": SkillScreen.COL_SELECTED if selected else SkillScreen.COL_ROW, "border": SkillScreen.COL_BORDER,
		"text": Color.WHITE}
	if state == SkillTreeModel.READY or state == SkillTreeModel.CURRENT:
		look["border"] = SkillScreen.COL_CAPPED
	elif state == SkillTreeModel.NAMED:
		look["text"] = SkillScreen.COL_DIM
	elif state == SkillTreeModel.RETIRED or state == SkillTreeModel.CLOSED:
		look["text"] = SkillScreen.COL_DIM
		look["border"] = SkillScreen.COL_DIM
	elif state == SkillTreeModel.STUB:
		look["bg"] = SkillScreen.COL_SELECTED if selected else COL_STUB
		look["text"] = SkillScreen.COL_DIM
		look["border"] = SkillScreen.COL_DIM
	return look

## Rebuilds the picture for `model` with `sel` selected, at the overview (dots and edges) or the normal zoom (names).
## Panels wholly outside the box are not built.
func show_model(model: Dictionary, sel: String, overview: bool) -> void:
	for c in get_children():
		c.free()
	_panels.clear()
	segments.clear()
	var cam := camera(model, sel, overview, size)
	var s: float = cam["scale"]
	var off: Vector2 = cam["offset"]
	var nodes: Dictionary = model["nodes"]
	var half := SkillTreeModel.NODE_SIZE.y / 2.0
	for e in model["edges"]:
		var a: Vector2 = nodes[e["from"]]["pos"] + Vector2(SkillTreeModel.NODE_SIZE.x, half)
		var b: Vector2 = nodes[e["to"]]["pos"] + Vector2(0.0, half)
		segments.append({"a": off + a * s, "b": off + b * s, "color": SkillScreen.COL_BORDER if e["known"] else SkillScreen.COL_DIM})
	var ids := nodes.keys()
	ids.sort()
	for id in ids:
		var n: Dictionary = nodes[id]
		var at: Vector2 = n["pos"]
		var rect := Rect2(off + at * s, SkillTreeModel.NODE_SIZE * s)
		if not Rect2(Vector2.ZERO, size).intersects(rect):
			continue
		var look := look_for(n["state"], id == sel)
		var p := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = look["bg"]
		style.border_color = look["border"]
		style.set_border_width_all(2 if id == sel else 1)
		style.set_corner_radius_all(2)
		p.add_theme_stylebox_override("panel", style)
		p.position = rect.position
		p.size = rect.size
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.gui_input.connect(_on_input.bind(id))
		add_child(p)
		_panels[id] = p
		if not overview:
			var l := Label.new()
			l.text = "???" if n["state"] == SkillTreeModel.STUB else n["name"]
			l.position = Vector2(SkillTreeModel.LABEL_INSET, 0)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.clip_text = true
			l.add_theme_font_size_override("font_size", SkillScreen.FONT_SMALL)
			l.add_theme_color_override("font_color", look["text"])
			p.add_child(l)
			l.size = Vector2(rect.size.x - 2.0 * SkillTreeModel.LABEL_INSET, rect.size.y)
	queue_redraw()

## The panel drawn for `id`, or null when it lies outside the box or is not a node.
func panel_for(id: String) -> Panel:
	return _panels.get(id)

func panel_count() -> int:
	return _panels.size()

func _draw() -> void:
	for seg in segments:
		draw_line(seg["a"], seg["b"], seg["color"], 1.0)

func _on_input(event: InputEvent, id: String) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed:
		return
	if b.button_index == MOUSE_BUTTON_LEFT and id != "":
		call_deferred("_emit_click", id)
	elif b.button_index == MOUSE_BUTTON_WHEEL_UP:
		call_deferred("_emit_zoom", false)
	elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		call_deferred("_emit_zoom", true)
	else:
		return
	accept_event()

func _emit_click(id: String) -> void:
	node_clicked.emit(id)

func _emit_zoom(overview: bool) -> void:
	zoom_requested.emit(overview)
