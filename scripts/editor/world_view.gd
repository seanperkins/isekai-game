class_name WorldView
extends Control
## A read-only overview of the world: every room as a rectangle at its world position, scaled to fit, the current room outlined.
## A click on a room chooses it (RoomEditor opens it). Moving rooms is a later phase.

signal room_chosen(id: String)

const AREA_FILL := {"cave": Color(0.42, 0.33, 0.58), "grotto": Color(0.62, 0.4, 0.2), "deep": Color(0.3, 0.35, 0.55), "flooded": Color(0.2, 0.5, 0.6)}
const FILL_UNKNOWN := Color(0.4, 0.4, 0.4)
const MARGIN := 16.0
const FONT := 10
## The strips above and below the map: the size numbers (WorldSize, informational) and the rooms per area against the budget.
const HEADER := 46.0
const FOOTER := 34.0
const AREAS_PER_ROW := 8
const INK := Color(0.85, 0.85, 0.9)
const INK_DIM := Color(0.55, 0.55, 0.63)
const BAR_BACK := Color(0.22, 0.22, 0.28)
const BAR_FILL := Color(0.4, 0.8, 0.7)

var _layout: Array = []
var _areas := {}
var _current := ""
var _stats := {}

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
	_layout = layout(rooms, Rect2(Vector2(MARGIN, HEADER), Vector2(size.x - MARGIN * 2.0, size.y - HEADER - FOOTER)))
	_stats = WorldSize.measure(rooms)
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
	_draw_size(font)

## The size numbers: totals and the three yardsticks above the map, the rooms per area against the budget below it. Read-only.
func _draw_size(font: Font) -> void:
	if _stats.is_empty():
		return
	draw_string(font, Vector2(MARGIN, 14.0), "%d rooms | %d screens | %.1f per room    Super Metroid: %d rooms, %d screens    (informational)" % [
		_stats["rooms"], _stats["screens"], _stats["avg"], WorldSize.SM_ROOMS, WorldSize.SM_SCREENS], HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT, INK)
	var gap := 12.0
	var w := (size.x - MARGIN * 2.0 - gap * 2.0) / 3.0
	var i := 0
	for y in WorldSize.yardsticks(_stats):
		var x := MARGIN + i * (w + gap)
		draw_string(font, Vector2(x, 29.0), "%s %d / %d  %d%%" % [y["label"], y["now"], y["target"], roundi(y["frac"] * 100.0)],
			HORIZONTAL_ALIGNMENT_LEFT, w, FONT - 1, INK_DIM)
		draw_rect(Rect2(x, 33.0, w, 5.0), BAR_BACK)
		draw_rect(Rect2(x, 33.0, w * clampf(y["frac"], 0.0, 1.0), 5.0), BAR_FILL)
		i += 1
	var cell := (size.x - MARGIN * 2.0) / float(AREAS_PER_ROW)
	var n := 0
	for a in WorldSize.area_rows(_stats):
		var p := Vector2(MARGIN + (n % AREAS_PER_ROW) * cell, size.y - FOOTER + 12.0 + floori(n / float(AREAS_PER_ROW)) * 12.0)
		draw_string(font, p, "%s %d/%d" % [a["area"], a["rooms"], a["target"]], HORIZONTAL_ALIGNMENT_LEFT, cell - 4.0, FONT - 1,
			INK if a["rooms"] > 0 else INK_DIM)
		n += 1
