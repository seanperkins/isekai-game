class_name World
extends Node2D
## Owns the one live room. Walking through an open exit follows the exploration spec's
## transition sequence:
##   1. build the neighbour;
##   2. freeze the player, keeping their velocity;
##   3. slide the camera;
##   4. free the old room;
##   5. unfreeze the player.
## Nothing carries across: bodies and projectiles stay behind, and ropes are dropped.

signal room_entered(id: String)

const SLIDE_SECONDS := 0.35
## Entering a room through its floor pushes you up at least this fast, so you clear the lip. It must
## lift the feet (BodyConfig.BOTTOM below the origin) over the floor lip (RoomDef.FLOOR) with a margin:
## 330^2 / (2 * 900) = 60 px for the 40 px lip + 12 px feet + 8 px spare. tests/test_world_entry.gd
## fails if the body or the lip changes and this is left behind.
const ENTRY_BOOST := -330.0
const VIEW := Vector2(640, 360)

var rooms := {}
var current_id := ""
var room: Node2D
var camera := Camera2D.new()
var player: CharacterBody2D
var ctx := {}
var sliding := false

static func load_rooms(dir: String) -> Dictionary:
	var out := {}
	for r in DefLoader.load_dir(dir, "RoomDef"):
		out[r.id] = r
	return out

func setup(p_rooms: Dictionary, p_player: CharacterBody2D, p_ctx: Dictionary) -> void:
	rooms = p_rooms
	player = p_player
	ctx = p_ctx
	ctx["shake"] = Callable(self, "shake")  # the boss arena's slam and the tremor rooms jolt the camera through this
	camera.name = "Camera"
	camera.zoom = Vector2(1, 1)  # the 640x360 internal resolution is scaled to the window
	add_child(camera)
	player.z_index = 5  # over the room's contents
	add_child(player)
	var progress = ctx.get("progress")
	if progress != null:
		progress.shortcut_opened.connect(_open_gate)
	if is_inside_tree():
		camera.make_current()

func _ready() -> void:
	if camera.is_inside_tree():
		camera.make_current()

func enter_start() -> void:
	for id in rooms:
		var r: RoomDef = rooms[id]
		if r.is_start():
			enter(id)
			player.global_position = r.world_rect().position + r.start
			_follow()
			return

## Starts the life in `room_id` at local position `pos` (a rebirth pool's room and spot). enter_start() stays
## the default, and the validator keeps requiring exactly one start room.
func enter_at(room_id: String, pos: Vector2) -> void:
	enter(room_id)
	player.global_position = (rooms[room_id] as RoomDef).world_rect().position + pos
	_follow()

func enter(id: String) -> void:
	if room != null:
		room.queue_free()
	_build(id)
	_follow()
	room_entered.emit(id)

func current_rect() -> Rect2:
	return (rooms[current_id] as RoomDef).world_rect()

## The camera centre that shows `focus` without leaving `rect`.
static func view_center(rect: Rect2, focus: Vector2) -> Vector2:
	var half := VIEW / 2.0
	return Vector2(
		clampf(focus.x, rect.position.x + half.x, maxf(rect.position.x + half.x, rect.end.x - half.x)),
		clampf(focus.y, rect.position.y + half.y, maxf(rect.position.y + half.y, rect.end.y - half.y)))

## The open exit the point has crossed, or {} while it is inside the room.
func exit_beyond(pos: Vector2) -> Dictionary:
	var rect := current_rect()
	var edge := ""
	if pos.x >= rect.end.x:
		edge = "right"
	elif pos.x < rect.position.x:
		edge = "left"
	elif pos.y >= rect.end.y:
		edge = "bottom"
	elif pos.y < rect.position.y:
		edge = "top"
	if edge == "":
		return {}
	var along := pos.y - rect.position.y if edge == "left" or edge == "right" else pos.x - rect.position.x
	for e in (rooms[current_id] as RoomDef).exits:
		if e["edge"] == edge and along >= float(e["from"]) and along <= float(e["to"]) \
				and RoomBuilder.is_exit_open(e, ctx.get("progress")):
			return e
	return {}

func _physics_process(_delta: float) -> void:
	if sliding or room == null or player == null:
		return
	var e := exit_beyond(player.global_position)
	if not e.is_empty() and not _arena_locked():
		_transition(e)
		return
	_follow()
	_note_seen()

func _build(id: String) -> void:
	current_id = id
	room = RoomBuilder.build_room(rooms[id], ctx)
	add_child(room)
	move_child(room, 0)
	var progress = ctx.get("progress")
	if progress != null:
		progress.visit(id)

func _follow() -> void:
	camera.global_position = view_center(current_rect(), player.global_position)

func _transition(e: Dictionary) -> void:
	sliding = true
	var vel: Vector2 = player.velocity
	if player.has_method("drop_rope"):
		player.drop_rope()
	if player.has_method("end_channel"):
		player.end_channel()  # before the slide freezes the player: no spray or strand during it
	player.set_physics_process(false)
	var old := room
	old.process_mode = Node.PROCESS_MODE_DISABLED
	_build(e["room"])
	room.process_mode = Node.PROCESS_MODE_DISABLED
	var tw := create_tween()
	tw.tween_property(camera, "global_position", view_center(current_rect(), player.global_position), SLIDE_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if is_instance_valid(old):
		old.queue_free()
	room.process_mode = Node.PROCESS_MODE_INHERIT
	if e["edge"] == "top":
		vel.y = minf(vel.y, ENTRY_BOOST)
	player.velocity = vel
	player.set_physics_process(true)
	sliding = false
	room_entered.emit(current_id)

## True while the room's boss arena is in its intro or its fight: nobody leaves.
func _arena_locked() -> bool:
	for n in room.get_children():
		if n is BossArena:
			return (n as BossArena).locked()
	return false

## Jolts the camera: a few random offsets that decay to nothing over `seconds`.
func shake(amount: float, seconds: float) -> void:
	var tw := create_tween()
	var steps := 8
	for k in steps:
		var strength := amount * (1.0 - float(k) / float(steps))
		tw.tween_property(camera, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), seconds / float(steps))
	tw.tween_property(camera, "offset", Vector2.ZERO, 0.0)

## A shortcut was opened in this room: its gate solids go at once.
func _open_gate(id: String) -> void:
	if room == null:
		return
	for n in room.get_children():
		if n.is_in_group("gate_" + id):
			n.queue_free()

## Bestiary: a creature counts as seen once it is inside the camera's view.
func _note_seen() -> void:
	var compendium = ctx.get("compendium")
	if compendium == null:
		return
	var view := Rect2(camera.global_position - VIEW / 2.0, VIEW)
	for n in room.get_children():
		if n is Enemy and view.has_point(n.global_position):
			compendium.on_creature_seen(n.def.id)
