class_name BossArena
extends Node2D
## A boss room's arena, a child of the room node: it watches for the player on the threshold, and BossArenaModel says when to do what.
## The intro rumbles at once, the doors slam halfway (a gate on every exit of the room, in GATE_GROUP) and the boss wakes at the end (no
## longer dormant, and hunting); when the boss is downed the doors open. Only its own gates are ever freed, never a shortcut's.
## Exit transitions are the world's to refuse while it is locked (World._physics_process asks).

const GATE_GROUP := "boss_gate"
## How hard the doors' slam shakes the camera, and for how long.
const SLAM_SHAKE := 6.0
const SLAM_SECONDS := 0.4

var model := BossArenaModel.new()

var _def: RoomDef
var _ctx: Dictionary
var _boss: Enemy
var _solids: Array = []
var _painted := false
var _threshold: Area2D
var _downed := false

## `solids` and `painted` are what RoomBuilder.make_gate needs to draw the doors the way the room draws its rock.
func setup(def: RoomDef, ctx: Dictionary, boss: Enemy, solids: Array, painted: bool) -> void:
	_def = def
	_ctx = ctx
	_boss = boss
	_solids = solids
	_painted = painted
	name = "BossArena"
	var rect: Rect2 = def.boss["threshold"]
	_threshold = Area2D.new()
	_threshold.position = rect.position + rect.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	_threshold.add_child(shape)
	add_child(_threshold)
	if boss != null:
		boss.dormant = true
		boss.downed.connect(_on_boss_downed)

func locked() -> bool:
	return model.state == BossArenaModel.State.INTRO or model.state == BossArenaModel.State.FIGHT

func _on_boss_downed(_def_downed: CreatureDef) -> void:
	_downed = true  # read by the next physics tick, after the game's own downed handlers have run

func _physics_process(delta: float) -> void:
	var on_line := false
	for body in _threshold.get_overlapping_bodies():
		if body.is_in_group("player"):
			on_line = true
	for event in model.tick(delta, on_line, _downed):
		_handle(event)

func _handle(event: String) -> void:
	match event:
		"intro":
			EventBus.world_event.emit("boss_intro", {"pos": global_position})
		"seal":
			var room := get_parent() as Node2D
			for e in _def.exits:
				RoomBuilder.make_gate(room, _def, e, _solids, _painted, GATE_GROUP)
			EventBus.world_event.emit("boss_slam", {"pos": global_position})
			var shake: Callable = _ctx.get("shake", Callable())
			if shake.is_valid():
				shake.call(SLAM_SHAKE, SLAM_SECONDS)
		"wake":
			if _boss != null and is_instance_valid(_boss):
				_boss.dormant = false
				_boss.hunting = true
			EventBus.world_event.emit("boss_wake", {"pos": global_position})
		"won":
			for n in get_parent().get_children():
				if n.is_in_group(GATE_GROUP):
					n.queue_free()
			var progress = _ctx.get("progress")
			if progress != null:
				progress.defeat_boss(str(_def.boss["creature"]))  # a tick after the downed signal: the Bestiary has the defeat by now
			EventBus.world_event.emit("boss_defeated", {"pos": global_position})
