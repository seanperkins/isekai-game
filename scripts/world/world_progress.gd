class_name WorldProgress
extends RefCounted
## What the player has found, kept across runs: visited rooms (the map), opened shortcuts and
## read tablets. Saves through the Profile when one is given; without one it lives in memory.

signal shortcut_opened(id: String)

var profile  # Profile, or null
var visited: Array = []
var shortcuts: Array = []
var tablets: Array = []

func _init(p_profile = null) -> void:
	profile = p_profile
	if profile != null:
		visited = profile.list_section("map")
		shortcuts = profile.list_section("shortcuts")
		tablets = profile.list_section("tablets")

func visit(id: String) -> void:
	if not visited.has(id):
		visited.append(id)
		_save()

func is_visited(id: String) -> bool:
	return visited.has(id)

func open_shortcut(id: String) -> void:
	if shortcuts.has(id):
		return
	shortcuts.append(id)
	_save()
	shortcut_opened.emit(id)

func is_open(id: String) -> bool:
	return shortcuts.has(id)

func read_tablet(id: String) -> void:
	if not tablets.has(id):
		tablets.append(id)
		_save()

func is_read(id: String) -> bool:
	return tablets.has(id)

func _save() -> void:
	if profile == null:
		return
	profile.set_section("map", visited.duplicate())
	profile.set_section("shortcuts", shortcuts.duplicate())
	profile.set_section("tablets", tablets.duplicate())
	profile.save()
