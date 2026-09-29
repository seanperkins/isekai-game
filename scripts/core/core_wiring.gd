class_name CoreWiring
extends RefCounted
## The one place the core pieces are connected. Autoloads and tests both call this.

static func connect_core(rules: SkillRulesEngine, compendium: CompendiumModel, announcer: AnnouncerQueue) -> void:
	rules.skill_unlocked.connect(func(id: String) -> void:
		compendium.on_skill_unlocked(id)
		var d: SkillDef = rules.get_def(id)
		announcer.push_unlock(id, d.announce if d != null else id))
	rules.skill_leveled.connect(func(id: String, level: int) -> void:
		if not rules.rechecking:  # an evolution re-check says one line instead (below)
			announcer.push_level(id, level))
	rules.rechecked.connect(func(levels_gained: int) -> void:
		if levels_gained > 0:
			announcer.push_note("Your skills grew."))
	rules.run_started.connect(func() -> void: compendium.on_run_started(rules))
	rules.evolution_ready.connect(func(id: String) -> void:
		compendium.raise(id, CompendiumModel.State.NAMED)
		var d: SkillDef = rules.get_def(id)
		announcer.push_unlock(id, "Evolution available: [%s] — %d EP in Skills" % [d.display_name, rules.evolution_cost(id)]))
	rules.inspect_processed.connect(func(tags: Dictionary, level: int) -> void:
		compendium.on_inspect_processed(tags, level, rules))
