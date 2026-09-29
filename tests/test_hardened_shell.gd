extends GutTest
## Hardened Shell scales the knockback a hit gives the player, and a player without it takes full knockback.

func _player() -> Player:
	var skills := DefLoader.load_dir("res://data/skills")
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	rules.start_run()
	var comp := CompendiumModel.new(skills, DefLoader.load_dir("res://data/creatures"))
	var p := Player.new()
	p.setup(rules, comp, [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	return p

func test_a_player_without_the_skill_takes_full_knockback() -> void:
	var p := _player()
	p.receive_hit(1, "physical", Vector2(-50, 0))
	assert_almost_eq(p.velocity.x, Player.KNOCKBACK.x, 0.01)
	assert_almost_eq(p.velocity.y, Player.KNOCKBACK.y, 0.01)

func test_the_skill_scales_both_components() -> void:
	var p := _player()
	assert_true(p.skillset.rules.grant("hardened_shell", false))
	p.skillset.refresh()
	assert_almost_eq(p.skillset.knockback_factor(), 0.92, 0.0001)
	p.receive_hit(1, "physical", Vector2(-50, 0))
	assert_almost_eq(p.velocity.x, Player.KNOCKBACK.x * 0.92, 0.01)
	assert_almost_eq(p.velocity.y, Player.KNOCKBACK.y * 0.92, 0.01)

func test_the_skill_screen_reads_knockback_in_percent() -> void:
	var d: SkillDef = null
	for s in DefLoader.load_dir("res://data/skills"):
		if s.id == "hardened_shell":
			d = s
	assert_true(SkillScreenModel.effect_lines(d, 3).has("Knockback taken −24%"), str(SkillScreenModel.effect_lines(d, 3)))
	assert_true(SkillScreenModel.effect_lines(d, 8).has("Knockback taken −64%"))
