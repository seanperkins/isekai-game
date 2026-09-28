extends GutTest

func test_autoloads_boot_with_valid_content_and_wiring() -> void:
	assert_eq(SkillRules.skill_defs.size(), 21)
	assert_eq(SkillRules.creature_defs.size(), 6)
	assert_not_null(SkillRules.get_def("leap"))
	assert_not_null(Compendium.model)
	assert_not_null(Announcer.queue)
	assert_true(SkillRules.skill_unlocked.get_connections().size() >= 1)
	assert_true(EventBus.game_event.is_connected(SkillRules._on_game_event))
