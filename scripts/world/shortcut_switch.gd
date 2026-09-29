class_name ShortcutSwitch
extends Node2D
## A cracked stone that holds a shortcut shut. Tackle it (or hit it with a skill) and the
## shortcut opens for good. It counts as an actor so tackles and skills find it, but it never
## reports a stun.

var team := "terrain"
var facing := 1
var shortcut := ""
var _progress

func setup(f: Dictionary, ctx: Dictionary) -> void:
	shortcut = f["shortcut"]
	position = f["pos"]
	_progress = ctx.get("progress")
	add_to_group("actors")

func _ready() -> void:
	if get_child_count() == 0:
		var stone := ColorRect.new()
		stone.color = Color(0.42, 0.36, 0.32)
		stone.size = Vector2(18, 22)
		stone.position = Vector2(-9, -22)
		add_child(stone)
		var crack := ColorRect.new()
		crack.color = Color(0.1, 0.08, 0.08)
		crack.size = Vector2(2, 14)
		crack.position = Vector2(-1, -18)
		add_child(crack)

func receive_tackle(_atk: int, _from_behind: bool, _from: Vector2 = Vector2.INF) -> bool:
	open()
	return false

func receive_hit(_raw: int, _damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
	open()

func open() -> void:
	if _progress != null:
		_progress.open_shortcut(shortcut)
	queue_free()
