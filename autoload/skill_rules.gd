extends SkillRulesEngine
## The SkillRules autoload: loads and validates content, then listens to EventBus.
## Invalid content quits the game: no partial rule set ever runs.

var skill_defs: Array = []
var creature_defs: Array = []
var _unknown_seen := {}

func _ready() -> void:
	var content := DefLoader.load_content("res://data/skills", "res://data/creatures")
	skill_defs = content["skills"]
	creature_defs = content["creatures"]
	var errors: Array = content["errors"]
	if not errors.is_empty():
		for e in errors:
			push_error(e)
		get_tree().quit(1)
		return
	setup(skill_defs)
	EventBus.game_event.connect(_on_game_event)

func _on_game_event(event_name: String, tags: Dictionary) -> void:
	if OS.is_debug_build() and not Events.ALL.has(event_name) and not _unknown_seen.has(event_name):
		_unknown_seen[event_name] = true
		push_warning("SkillRules: unknown event '%s'" % event_name)
	handle_event(event_name, tags)
