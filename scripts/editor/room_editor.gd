class_name RoomEditor
extends Node
## The room editor scene root. For now it only takes its model back from Game.editor_resume; the view and panels follow.

## Tests inject a root; "" means HOME from the environment (the launcher sets it to .tmp/editor-home).
static var sandbox_root := ""

var model: RoomEditModel
var room_id := ""
var view_state := {}

func _ready() -> void:
	var resume = Game.editor_resume
	Game.editor_resume = null
	if resume != null:
		model = resume["model"]
		room_id = resume["room"]
		view_state = resume["view"]
	else:
		var ids: Array = SkillRules.creature_defs.map(func(c: CreatureDef) -> String: return c.id)
		model = RoomEditModel.new(World.load_rooms("res://data/rooms"), ids)
		room_id = "C1"

## Is `user_dir` (OS.get_user_data_dir()) inside `root`? A trailing-slash prefix test, so `editor-home2` is not inside
## `editor-home`.
static func in_sandbox(user_dir: String, root: String) -> bool:
	if root == "":
		return false
	var r := root.trim_suffix("/")
	var u := user_dir.trim_suffix("/")
	return u == r or u.begins_with(r + "/")

## True when the editor was launched through tools/edit_rooms.sh (its HOME is `.tmp/editor-home`), so user:// is a throwaway
## directory and Play cannot write the real profile. An injected `sandbox_root` is trusted (tests).
static func sandbox_ok() -> bool:
	if sandbox_root != "":
		return in_sandbox(OS.get_user_data_dir(), sandbox_root)
	var home := OS.get_environment("HOME")
	return home.ends_with("/.tmp/editor-home") and in_sandbox(OS.get_user_data_dir(), home)
