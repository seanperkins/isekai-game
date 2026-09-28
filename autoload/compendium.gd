extends Node
## The Compendium autoload: persistent knowledge, saved to user://compendium.json.

var model: CompendiumModel

func _ready() -> void:
	model = CompendiumModel.new(SkillRules.skill_defs, SkillRules.creature_defs,
		CompendiumStore.new("user://compendium.json"))
