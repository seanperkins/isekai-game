extends GutTest
## Transmute and copy, and every slime form-four verb cast for real.

class Foe extends Node2D:
	var team := "enemy"
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

var rules: SkillRulesEngine
var player: Player
var skills: Array
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in skills:
		skills_by_id[d.id] = d

func before_each() -> void:
	_new_player()

func _new_player() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	player = Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()

func after_each() -> void:
	for group in ["verb_fields", "verb_allies", "verb_vines", "verb_husks"]:
		for n in get_tree().get_nodes_in_group(group):
			n.free()

func _absorb(element: String, units: int) -> void:
	for i in units:
		rules.handle_event(Events.ABSORBED, {"essence": element, "source": "test"})

func _verb(spec: Dictionary, value := 2) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [value], 1)
	return a

func _row_verb(form_id: String) -> VerbAbility:
	var d: SkillDef = skills_by_id["verb_" + form_id]
	var a: VerbAbility = load(SkillEffects.active_scene(d)).instantiate()
	player.add_child(a)
	a.spec = SkillEffects.active_spec(d)
	a.setup(player, SkillEffects.active_values(d), 1)
	return a

# --- the pair Transmute picks ---

func test_transmute_picks_the_most_held_for_the_least_held() -> void:
	assert_eq(Essences.transmute_pair({"water": 5, "earth": 1, "air": 0, "light": 2, "dark": 0}, 3), ["water", "air"])
	assert_eq(Essences.transmute_pair({"water": 3, "earth": 3, "air": 0, "light": 0, "dark": 0}, 3), ["water", "air"], "ties go in element order")

func test_transmute_picks_nothing_without_enough_of_one_element() -> void:
	assert_eq(Essences.transmute_pair({"water": 2, "earth": 2, "air": 2, "light": 0, "dark": 0}, 3), [])
	assert_eq(Essences.transmute_pair({"water": 9, "earth": 9, "air": 9, "light": 9, "dark": 9}, 3), [], "everything held equally: nowhere to move it")

# --- transmute ---

func test_transmute_turns_the_most_held_element_into_the_least_held() -> void:
	_absorb("water", 5)
	_verb({"kind": "transmute", "from_units": 3, "to_units": 2}).activate()
	assert_eq(rules.held("water"), 2)
	assert_eq(rules.held("earth"), 2)
	for e in Essences.ALL:
		assert_gte(rules.held(e), 0, e)

func test_transmute_with_less_than_the_cost_does_nothing() -> void:
	_absorb("water", 2)
	_verb({"kind": "transmute", "from_units": 3, "to_units": 2}).activate()
	assert_eq(rules.held("water"), 2)
	assert_eq(rules.held("earth"), 0)

func test_transmute_never_makes_a_later_element() -> void:
	_absorb("water", 9)
	var a := _verb({"kind": "transmute", "from_units": 3, "to_units": 2})
	for i in 3:
		a.activate()
		a._process(1.0)
	for e in Essences.LATER:
		assert_eq(rules.held(e), 0, e)

# --- copy ---

func test_copy_takes_the_last_appraised_creatures_stats_for_its_time_and_survives_a_refresh() -> void:
	var lizard: CreatureDef = creatures["lizard"]
	player.last_inspected = lizard
	var atk := player.stats.get_stat("atk")
	var def := player.stats.get_stat("def")
	_verb({"kind": "copy", "seconds": 0.3}).activate()
	assert_eq(player.stats.get_stat("atk"), atk + int(lizard.stats.get("atk", 0)))
	assert_eq(player.stats.get_stat("def"), def + int(lizard.stats.get("def", 0)))
	player.skillset.refresh()
	assert_eq(player.stats.get_stat("atk"), atk + int(lizard.stats.get("atk", 0)), "a refresh does not end it")
	await wait_seconds(0.6)
	assert_eq(player.stats.get_stat("atk"), atk)
	assert_eq(player.stats.get_stat("def"), def)

func test_copy_with_nothing_appraised_does_nothing() -> void:
	var atk := player.stats.get_stat("atk")
	assert_true(_verb({"kind": "copy", "seconds": 1.0}).activate())
	assert_eq(player.stats.get_stat("atk"), atk)

func test_appraising_a_creature_remembers_it() -> void:
	var e := Enemy.new()
	e.setup(creatures["lizard"], skills_by_id)
	e.position = Vector2(30, 0)
	add_child_autofree(e)
	assert_null(player.last_inspected)
	player.do_inspect()
	assert_eq(player.last_inspected, creatures["lizard"])

# --- the whole set ---

## What a cast can change, read off the arena: damage and roots, spawned nodes, a mark, stats, essence, a glide, a ward. (Not the
## player's position or speed: it falls in this arena, so they change whatever is cast.)
func _snapshot(foes: Array, lizard: Enemy) -> Dictionary:
	var hits := 0
	for f in foes:
		hits += f.hits.size()
	return {"hits": hits, "hp": lizard.health.hp, "rooted": lizard.is_rooted(), "state": lizard.status.state,
		"fields": get_tree().get_nodes_in_group("verb_fields").size(), "clouds": get_tree().get_nodes_in_group("player_clouds").size(), "allies": get_tree().get_nodes_in_group("verb_allies").size(),
		"vines": get_tree().get_nodes_in_group("verb_vines").size(), "husks": get_tree().get_nodes_in_group("verb_husks").size(),
		"mark": player.has_meta(VerbKinds.ANCHOR_META), "atk": player.stats.get_stat("atk"), "water": rules.held("water"),
		"glide": player._glide, "ward": player._ward}

func test_every_slime_form_four_but_quicksilver_has_a_working_verb() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tools/form_verbs.json"))
	assert_eq(rows.size(), 17, "the 17 verbs of the design's slime form-fours")
	for row in rows:
		_new_player()  # a clean body for each verb: a glide or a buff from the last would otherwise change this snapshot
		var foes: Array = []
		for x in [40.0, 80.0, 120.0]:
			var f := Foe.new()
			add_child_autofree(f)
			f.add_to_group("actors")
			f.global_position = Vector2(x, 0)
			foes.append(f)
		var lizard := Enemy.new()
		lizard.setup(creatures["lizard"], skills_by_id)
		lizard.position = Vector2(30, 0)
		add_child_autofree(lizard)
		lizard.health.max_hp = 100
		lizard.health.hp = 100
		player.global_position = Vector2.ZERO
		player.facing = 1
		_absorb("water", 5)
		player.last_inspected = creatures["lizard"]
		var before := _snapshot(foes, lizard)
		var verb := _row_verb(row["form"])
		assert_true(verb.activate(), row["form"])
		await wait_physics_frames(2)
		assert_ne(_snapshot(foes, lizard), before, "%s (%s) did something" % [row["name"], row["form"]])
		for group in ["verb_fields", "verb_allies", "verb_vines", "verb_husks", "player_clouds"]:
			for n in get_tree().get_nodes_in_group(group):
				n.free()
		for n in foes + [lizard]:
			n.free()
		player.free()

func test_quicksilver_has_no_verb_and_still_evolves() -> void:
	var forms := FormLoader.load_all()
	assert_eq(forms["quicksilver_slime"].verb, "")
	assert_eq(forms["quicksilver_slime"].grants.filter(func(g: String) -> bool: return g.begins_with("verb_")), [])
	assert_true(forms["quicksilver_slime"].parents.has("radiant"))

func test_validate_knows_transmute_and_copy() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "transmute", "from_units": 3, "to_units": 2})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "copy", "seconds": 8})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "copy", "units": 1})), ["copy: unknown key 'units'"])
