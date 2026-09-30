class_name RoomEditor
extends Node
## The room editor scene root. For now it only takes its model back from Game.editor_resume; the view and panels follow.

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
