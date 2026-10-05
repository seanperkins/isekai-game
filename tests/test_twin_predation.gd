extends GutTest
## Eating a twin pays what its data says, through the same path as any creature: its essence one unit at a time, then the eat event.

func test_eating_a_twin_pays_its_essence_and_says_what_was_eaten() -> void:
	var skills := DefLoader.load_dir("res://data/skills")
	var by_id := {}
	for d in skills:
		by_id[d.id] = d
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var events: Array = []
	var rules := SkillRulesEngine.new()
	rules.setup(skills)
	var player := Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void: events.append([n, t]))
	add_child_autofree(player)
	rules.start_run()
	var twin := Enemy.new()
	twin.setup(creatures["twin_wolf_fenrir"], by_id)
	add_child_autofree(twin)
	player._complete_predation(twin)
	var absorbed := events.filter(func(e: Array) -> bool: return e[0] == Events.ABSORBED)
	assert_eq(absorbed.size(), 12, "a stage-4 twin is 12 units")
	for e in absorbed:
		assert_eq(e[1], {"essence": "earth", "source": "twin_wolf_fenrir"})
	var eaten := events.filter(func(e: Array) -> bool: return e[0] == Events.PREDATED)
	assert_eq(eaten.size(), 1)
	assert_eq(eaten[0][1], {"source": "twin_wolf_fenrir", "kind": "creature", "species": "wolf"})
