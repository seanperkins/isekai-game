class_name RoomView
extends Node2D
## The room as the game draws it (RoomBuilder and TerrainPainter), seen through a Camera2D in the root viewport. Overlays
## (markers, selection outlines, the drag rect) live on a follow_viewport CanvasLayer so the per-area CanvasModulate does not
## dim them. All positions are in the 640x360 viewport space the project's canvas_items stretch gives mouse events.

const PICK_PX := 8.0
const ZOOM_MIN := 0.25
const ZOOM_MAX := 4.0

var camera := Camera2D.new()
var overlay := Node2D.new()
var _model: RoomEditModel
var _room_id := ""
var _room: Node2D
var _tint := CanvasModulate.new()
var _overlay_layer := CanvasLayer.new()

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
		_room.queue_free()
	var def: RoomDef = model.rooms[room_id]
	_room = RoomBuilder.build_room(def, {"progress": null})  # no progress: closed shortcuts draw as gates
	_room.position = Vector2.ZERO
	add_child(_room)
	_tint.color = TerrainArt.ambient(def.area, Game.AMBIENT)
	fit()

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
	var size: Vector2 = _model.rooms[_room_id].pixel_size()
	var z := minf(640.0 / size.x, 360.0 / size.y)
	camera.zoom = Vector2(z, z)
	camera.position = (size - Vector2(640, 360) / z) / 2.0

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
