extends GutTest

func test_autoloads_boot_with_valid_content_and_wiring() -> void:
	assert_eq(SkillRules.skill_defs.size(), 32)
	assert_eq(SkillRules.creature_defs.size(), 19)
	assert_not_null(SkillRules.get_def("leap"))
	assert_not_null(Compendium.model)
	assert_not_null(Announcer.queue)
	assert_true(SkillRules.skill_unlocked.get_connections().size() >= 1)
	assert_true(EventBus.game_event.is_connected(SkillRules._on_game_event))
	assert_not_null(Audio.catalog)
	assert_eq(Audio.catalog.validate(func(p: String) -> bool: return ResourceLoader.exists(p)), [])
	assert_true(EventBus.world_event.is_connected(Audio._on_event))
	assert_true(EventBus.game_event.is_connected(Audio._on_event))
