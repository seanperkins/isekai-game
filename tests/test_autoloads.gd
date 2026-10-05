extends GutTest

func test_autoloads_boot_with_valid_content_and_wiring() -> void:
	assert_eq(SkillRules.skill_defs.filter(func(d: SkillDef) -> bool: return d.source != "form_verb").size(), 32, "the authored skills; form verbs are generated")
	assert_eq(SkillRules.creature_defs.size(), Sources.ALL.size(), "19 shipped, 140 twins and 28 support monsters")
	assert_not_null(SkillRules.get_def("leap"))
	assert_not_null(Compendium.model)
	assert_not_null(Announcer.queue)
	assert_true(SkillRules.skill_unlocked.get_connections().size() >= 1)
	assert_true(EventBus.game_event.is_connected(SkillRules._on_game_event))
	assert_not_null(Audio.catalog)
	assert_eq(Audio.catalog.validate(func(p: String) -> bool: return ResourceLoader.exists(p)), [])
	assert_true(EventBus.world_event.is_connected(Audio._on_event))
	assert_true(EventBus.game_event.is_connected(Audio._on_event))
