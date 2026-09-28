extends Node
## The Announcer autoload: owns the pop-up/ticker queue and connects the core.
## Registered last so SkillRules and Compendium are ready.

var queue := AnnouncerQueue.new()

func _ready() -> void:
	CoreWiring.connect_core(SkillRules, Compendium.model, queue)

func _process(delta: float) -> void:
	queue.advance(delta)
