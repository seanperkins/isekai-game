class_name WorldView
extends Control
## A read-only overview of the world: every room as a rectangle at its world position, scaled to fit, the current room outlined.
## A click on a room chooses it (RoomEditor opens it). Moving rooms is a later phase.

signal room_chosen(id: String)

const AREA_FILL := {"cave": Color(0.42, 0.33, 0.58), "grotto": Color(0.62, 0.4, 0.2), "deep": Color(0.3, 0.35, 0.55), "flooded": Color(0.2, 0.5, 0.6)}
const FILL_UNKNOWN := Color(0.4, 0.4, 0.4)
const MARGIN := 16.0
const FONT := 10

var _layout: Array = []
var _areas := {}
var _current := ""

func _init() -> void:
	position = Vector2(0, 48)
	size = Vector2(640, 296)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

## One {id, rect} per room: the rooms' world rectangles scaled by one factor to fit `rect` and centred in it.
static func layout(rooms: Dictionary, rect: Rect2) -> Array:
	if rooms.is_empty():
		return []
	var bounds := Rect2()
	var first := true
	for id in rooms:
		var w: Rect2 = (rooms[id] as RoomDef).world_rect()
		bounds = w if first else bounds.merge(w)
		first = false
	var scale := minf(rect.size.x / bounds.size.x, rect.size.y / bounds.size.y)
	var origin := rect.position + (rect.size - bounds.size * scale) / 2.0
	var out: Array = []
	for id in rooms:
		var w: Rect2 = (rooms[id] as RoomDef).world_rect()
		out.append({"id": id, "rect": Rect2(origin + (w.position - bounds.position) * scale, w.size * scale)})
	return out

## The id of the room whose rectangle holds `point`, or "".
static func room_at(items: Array, point: Vector2) -> String:
	for item in items:
		if (item["rect"] as Rect2).has_point(point):
			return item["id"]
	return ""

func setup(rooms: Dictionary, current_id: String) -> void:
	_layout = layout(rooms, Rect2(Vector2(MARGIN, MARGIN), size - Vector2(MARGIN, MARGIN) * 2.0))
	_areas = {}
	for id in rooms:
		_areas[id] = (rooms[id] as RoomDef).area
	_current = current_id
	queue_redraw()

func layout_items() -> Array:
	return _layout

func click(point: Vector2) -> void:
	var id := room_at(_layout, point)
	if id != "":
		room_chosen.emit(id)

func _gui_input(event: InputEvent) -> void:
	var e := event as InputEventMouseButton
	if e != null and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		click(e.position)
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.16))
	var font := get_theme_default_font()
	for item in _layout:
		var rect: Rect2 = item["rect"]
		var id: String = item["id"]
		draw_rect(rect, AREA_FILL.get(_areas.get(id, ""), FILL_UNKNOWN))
		draw_rect(rect, Color.WHITE if id == _current else Color(0.05, 0.05, 0.08), false, 2.0 if id == _current else 1.0)
		draw_string(font, rect.position + Vector2(4.0, 12.0), id, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT)
