extends Node
## The Compendium autoload: persistent knowledge. Everything saves through one Profile
## (user://profile.json); the old user://compendium.json is migrated on first load.

var profile: Profile
var model: CompendiumModel
var progress: WorldProgress
var soul: SoulProgress

func _ready() -> void:
	profile = Profile.new("user://profile.json", "user://compendium.json")
	profile.reload()
	model = CompendiumModel.new(SkillRules.skill_defs, SkillRules.creature_defs, profile)
	EventBus.game_event.connect(model.on_game_event)  # Bestiary: creatures eaten
	progress = WorldProgress.new(profile)
	soul = SoulProgress.new(profile, DefLoader.load_dir("res://data/perks", "PerkDef").map(func(p: PerkDef) -> String: return p.id))
