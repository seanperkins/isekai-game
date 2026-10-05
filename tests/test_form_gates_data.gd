extends GutTest
## The shipped gates: every wolf, undead, spider and goblin form has one, it is valid, and the deeds it waits for are listed.

## The deeds something emits today (the rest of Deeds.EVENTS is in Deeds.RESERVED).
const EMITTED := ["defeated", "guard_broken", "room_cleared", "room_entered", "skill_hit", "skill_missed", "switch_hit",
	"part_harvested", "graft_attached", "graft_shed", "item_carried", "corpse_left", "lesson_learned", "bond_formed",
	"trap_sprung", "weapon_forged", "item_stolen", "ward_stone_placed", "prey_cocooned", "prey_freed"]
const TOTAL := {2: 26, 3: 34, 4: 44}

var forms: Dictionary
var gated: Array

func before_all() -> void:
	forms = FormLoader.load_all()
	gated = forms.values().filter(func(f: FormDef) -> bool: return f.species != Form.DEFAULT_SPECIES)

func _atoms(f: FormDef) -> Array:
	var out: Array = []
	for a in f.gate:
		if a.get("kind", "") == "any":
			out.append_array(a["of"])
		else:
			out.append(a)
	return out

func test_the_four_species_have_99_forms_each_with_a_gate_and_the_slime_has_none() -> void:
	assert_eq(gated.size(), 99)
	for f: FormDef in gated:
		assert_false(f.gate.is_empty(), f.id)
	for f: FormDef in forms.values():
		if f.species == Form.DEFAULT_SPECIES:
			assert_true(f.gate.is_empty(), f.id)

func test_every_gate_validates_and_so_does_the_whole_tree() -> void:
	for f: FormDef in gated:
		assert_eq(FormGate.validate(f), PackedStringArray(), f.id)
	var skill_ids: Array = SkillRules.skill_defs.map(func(d: SkillDef) -> String: return d.id)
	var verb_ids: Array = SkillRules.skill_defs.filter(func(d: SkillDef) -> bool: return d.source == "form_verb").map(func(d: SkillDef) -> String: return d.id)
	assert_eq(FormValidator.validate(forms, skill_ids, true, verb_ids), PackedStringArray())

func test_a_gates_essence_atoms_are_the_forms_reads_and_total_its_stages_amount() -> void:
	for f: FormDef in gated:
		var essences := {}
		for a in f.gate:
			if a["event"] == "absorbed" if a.has("event") else false:
				essences[a["tags"]["essence"]] = int(a["n"])
		var keys := essences.keys()
		keys.sort()
		var reads := f.reads.duplicate()
		reads.sort()
		assert_eq(keys, reads, "%s asks for the essences it reads" % f.id)
		var total := 0
		for e in essences:
			total += int(essences[e])
		assert_gte(total, int(TOTAL[f.stage]), "%s asks for at least its stage's total" % f.id)

func test_a_gate_names_only_skills_that_exist() -> void:
	var ids: Array = SkillRules.skill_defs.map(func(d: SkillDef) -> String: return d.id)
	for f: FormDef in gated:
		for a in _atoms(f):
			if a["kind"] == "skill_level":
				assert_true(ids.has(a["id"]), "%s: %s" % [f.id, a["id"]])
			if a.get("event", "") == "skill_used":
				assert_true(ids.has(a["tags"]["id"]), "%s: %s" % [f.id, a["tags"]["id"]])

func test_the_reserved_list_is_exactly_the_deeds_the_gates_still_wait_for() -> void:
	var used := {}
	for f: FormDef in gated:
		for a in _atoms(f):
			var event: String = a.get("event", "")
			if event != "":
				used[event] = true
				for tag in a.get("tags", {}):
					used["%s.%s" % [event, tag]] = true
	for key in Deeds.RESERVED:
		assert_true(used.has(key), "%s is reserved but no gate waits for it: drop it" % key)
	for key in used:
		if Deeds.EVENTS.has(key) and not EMITTED.has(key):
			assert_true(Deeds.RESERVED.has(key), "%s is used, nothing emits it and it is not reserved" % key)
	for e in EMITTED:
		assert_false(Deeds.RESERVED.has(e), "%s is emitted now" % e)

func test_the_gates_that_wait_on_a_later_piece_are_known() -> void:
	var waiting := {}
	for f: FormDef in gated:
		var needs: Array = []
		for a in _atoms(f):
			var event: String = a.get("event", "")
			if Deeds.RESERVED.has(event):
				needs.append(Deeds.RESERVED[event])
			for tag in a.get("tags", {}):
				if Deeds.RESERVED.has("%s.%s" % [event, tag]):
					needs.append(Deeds.RESERVED["%s.%s" % [event, tag]])
		for piece in needs:
			waiting[piece] = int(waiting.get(piece, 0)) + 1
	assert_false(waiting.has("E1"), "E1 is built: " + str(waiting))
	assert_false(waiting.has("E2"), "E2 is built: " + str(waiting))
	assert_true(waiting.has("F2"), str(waiting))
	gut.p("gate atoms waiting on a later piece: %s" % waiting)

func test_a_gate_that_asks_for_a_part_names_a_part_that_exists() -> void:
	var parts := PartLoader.load_all()
	for f: FormDef in gated:
		for a in _atoms(f):
			if ["part_harvested", "graft_attached", "graft_shed"].has(a.get("event", "")) and a.get("tags", {}).has("part"):
				assert_true(parts.has(a["tags"]["part"]), "%s asks for part '%s'" % [f.id, a["tags"]["part"]])

func test_an_undead_run_meets_the_zombies_gate_through_a_real_player() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.species = "undead"
	p.use_sheet = false
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	p.progression.add_xp(Progression.stage_total(p.progression.stage))
	for essence in ["earth", "dark"]:
		for i in 13:
			rules.handle_event("absorbed", {"essence": essence, "source": "test"})
	var offered := func() -> Array: return p.form_offers().map(func(f: FormDef) -> String: return f.id)
	assert_false(offered.call().has("undead_zombie"), "the essence alone is not the gate")
	p.collect_part("ribs")
	assert_false(offered.call().has("undead_zombie"), "a rib without flesh is not the gate")
	p.collect_part("flesh")
	assert_true(offered.call().has("undead_zombie"), "ribs, flesh and the essence open the Zombie")

func test_a_wolf_that_carries_the_same_parts_does_not_open_an_undead_gate() -> void:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.species = "wolf"
	p.use_sheet = false
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	p.collect_part("ribs")
	p.collect_part("flesh")
	assert_eq(SkillRules.condition_value({"kind": "counter", "event": "graft_attached", "tags": {}, "n": 1}), 0, "carried is not attached")

func _goblin() -> Array:
	return _species_player("goblin")

func _species_player(species: String) -> Array:
	var rules: SkillRulesEngine = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	var p := Player.new()
	p.species = species
	p.use_sheet = false
	p.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(p)
	rules.start_run()
	return [p, rules]

func _real_enemy(id: String) -> Enemy:
	var skills_by_id := {}
	for d in SkillRules.skill_defs:
		skills_by_id[d.id] = d
	var def: CreatureDef
	for c in DefLoader.load_dir("res://data/creatures"):
		if c.id == id:
			def = c
	var e := Enemy.new()
	e.setup(def, skills_by_id)
	add_child_autofree(e)
	return e

func test_a_goblin_that_has_learned_from_a_wolf_a_spider_and_a_bat_is_offered_the_beastcaller() -> void:
	var made := _goblin()
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	p.progression.add_xp(Progression.stage_total(p.progression.stage))
	for essence in ["earth", "air"]:
		for i in 13:
			rules.handle_event("absorbed", {"essence": essence, "source": "test"})
	var offered := func() -> Array: return p.form_offers().map(func(f: FormDef) -> String: return f.id)
	assert_false(offered.call().has("goblin_beastcaller"), "the essence alone is not the gate")
	p.learn_from(_real_enemy("gloom_wolf"))
	p.learn_from(_real_enemy("spider"))
	assert_false(offered.call().has("goblin_beastcaller"), "two of the three lessons")
	p.learn_from(_real_enemy("bat"))
	assert_true(offered.call().has("goblin_beastcaller"), "a wolf, a spider and a bat taught it")

func test_the_pucks_lessons_are_a_wisp_and_a_moth() -> void:
	var made := _goblin()
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	for essence in ["air", "dark"]:
		for i in 17:
			rules.handle_event("absorbed", {"essence": essence, "source": "test"})
	var puck: FormDef = forms["goblin_puck"]
	assert_false(FormGate.met(puck, rules))
	p.learn_from(_real_enemy("bog_wisp"))
	assert_false(FormGate.met(puck, rules), "a wisp is not enough")
	p.learn_from(_real_enemy("pale_moth"))
	assert_true(FormGate.met(puck, rules))

func test_the_tinkers_junk_lesson_has_a_creature_to_learn_from() -> void:
	var ids: Array = DefLoader.load_dir("res://data/creatures").map(func(c: CreatureDef) -> String: return c.id)
	for f: FormDef in gated:
		for a in _atoms(f):
			if a.get("event", "") == "lesson_learned" and a.get("tags", {}).has("creature"):
				assert_true(ids.has(a["tags"]["creature"]), "%s asks for a lesson from '%s'" % [f.id, a["tags"]["creature"]])

func _bond_atom(rules: SkillRulesEngine, tags: Dictionary) -> int:
	return rules.condition_value({"kind": "counter", "event": "bond_formed", "tags": tags, "n": 1})

func _stun_next_to(p: Player, id: String) -> Enemy:
	var e := _real_enemy(id)
	e.position = p.position + Vector2(10, 0)
	e.status.stun(30.0)
	return e

func test_a_wolf_that_bonds_a_gloom_wolf_meets_the_wargs_gate_atom() -> void:
	var made := _species_player("wolf")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	assert_eq(_bond_atom(rules, {"kind": "pack"}), 0)
	_stun_next_to(p, "gloom_wolf")
	assert_true(p.try_bond())
	assert_eq(_bond_atom(rules, {"kind": "pack"}), 1)

func test_a_goblin_that_tames_a_rat_a_wolf_and_a_boar_meets_those_gate_atoms() -> void:
	var made := _species_player("goblin")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	for id in ["cave_rat", "gloom_wolf", "tusker_boar"]:
		p.collect_part("claw")
		_stun_next_to(p, id)
		assert_true(p.try_bond(), id)
		p._release_companions()
	assert_eq(_bond_atom(rules, {"kind": "tame", "creature": "cave_rat"}), 1)
	assert_eq(_bond_atom(rules, {"creature": "gloom_wolf"}), 1)
	assert_eq(_bond_atom(rules, {"kind": "large"}), 1, "the boar is a large companion")

func test_a_bond_that_lasts_meets_the_long_bond_atom() -> void:
	var made := _species_player("wolf")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	_stun_next_to(p, "gloom_wolf")
	p.try_bond()
	assert_eq(_bond_atom(rules, {"kind": "long"}), 0)
	(p.companions[0] as Companion)._physics_process(Companion.LONG_BOND_SECONDS + 1.0)
	assert_eq(_bond_atom(rules, {"kind": "long"}), 1)

func _count(rules: SkillRulesEngine, event: String) -> int:
	return rules.condition_value({"kind": "counter", "event": event, "tags": {}, "n": 1})

func _slot_of(p: Player, verb_id: String) -> int:
	return p.skillset.slots.slots.find(verb_id)

func _skill(id: String) -> SkillDef:
	for d in SkillRules.skill_defs:
		if d.id == id:
			return d
	return null

func _cast(p: Player, verb_id: String) -> void:
	var d := _skill(verb_id)
	var a: VerbAbility = load(SkillEffects.active_scene(d)).instantiate()
	p.add_child(a)
	a.spec = SkillEffects.active_spec(d)
	a.setup(p, SkillEffects.active_values(d), 1)
	VerbKinds.run(a, a.spec)

func test_a_goblin_smith_that_forges_meets_the_mastersmiths_atom() -> void:
	var made := _species_player("goblin")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	assert_true(p.become_form("goblin_smith"))
	var slot := _slot_of(p, "verb_goblin_smith")
	assert_gte(slot, 0, "the Smith's verb is in a slot")
	p.use_active(slot)
	assert_eq(_count(rules, "weapon_forged"), 0, "no parts, no forge")
	p.collect_part("claw")
	p.collect_part("skull")
	var atk := p.stats.get_stat("atk")
	p.use_active(slot)
	assert_eq(_count(rules, "weapon_forged"), 1)
	assert_eq(p.stats.get_stat("atk"), atk + 2)

func test_a_goblin_tomte_that_plants_three_stones_meets_the_hearth_gods_atom() -> void:
	var made := _species_player("goblin")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	assert_true(p.become_form("goblin_tomte"))
	var slot := _slot_of(p, "verb_goblin_tomte")
	assert_gte(slot, 0)
	p.use_active(slot)
	assert_eq(_count(rules, "ward_stone_placed"), 1)
	_cast(p, "verb_goblin_tomte")
	_cast(p, "verb_goblin_tomte")
	assert_eq(_count(rules, "ward_stone_placed"), 3)
	for c in get_tree().get_nodes_in_group("player_clouds"):
		c.free()

func test_a_goblin_tinker_whose_traps_are_sprung_three_times_meets_the_gremlins_atom() -> void:
	var made := _species_player("goblin")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	assert_true(p.become_form("goblin_tinker"))
	var slot := _slot_of(p, "verb_goblin_tinker")
	assert_gte(slot, 0)
	for i in 3:
		p.global_position = Vector2(200.0 * i, 0)
		if i == 0:
			p.use_active(slot)
		else:
			_cast(p, "verb_goblin_tinker")
	var traps := get_tree().get_nodes_in_group("verb_traps")
	assert_eq(traps.size(), 3)
	for t in traps:
		var e := _real_enemy("lizard")
		e.global_position = t.global_position
		t._physics_process(VerbTrap.ARM_SECONDS + 0.1)
	assert_eq(_count(rules, "trap_sprung"), 3)
	for t in get_tree().get_nodes_in_group("verb_traps"):
		t.free()

func test_a_goblin_that_picks_three_pockets_meets_the_leprechauns_atom() -> void:
	var made := _species_player("goblin")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	for i in 3:
		var d := TestDefs.creature("t_mark_%d" % i, {"drops": [{"part": "claw", "chance": 1.0}]})
		var skills_by_id := {}
		for sd in SkillRules.skill_defs:
			skills_by_id[sd.id] = sd
		var e := Enemy.new()
		e.setup(d, skills_by_id)
		e.position = p.position + Vector2(10, 0)
		add_child_autofree(e)
		assert_true(p.try_pickpocket())
	assert_eq(_count(rules, "item_stolen"), 3)

func test_a_spider_that_webs_a_stunned_creature_meets_the_broodmothers_and_cocoon_mothers_atoms() -> void:
	var made := _species_player("spider")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	assert_eq(_count(rules, "prey_cocooned"), 0)
	_stun_next_to(p, "bat")
	assert_true(p.try_cocoon())
	assert_eq(_count(rules, "prey_cocooned"), 1)
	assert_eq(rules.condition_value({"kind": "counter", "event": "prey_cocooned", "tags": {"creature": "bat"}, "n": 1}), 1)

func test_a_spider_that_lets_a_cocooned_creature_go_meets_anansis_atom() -> void:
	var made := _species_player("spider")
	var p: Player = made[0]
	var rules: SkillRulesEngine = made[1]
	p.collect_part("cocoon:bat")
	assert_eq(_count(rules, "prey_freed"), 0)
	assert_true(p.try_release_prey())
	assert_eq(_count(rules, "prey_freed"), 1)

func test_a_wolf_or_a_goblin_never_meets_a_cocoon_atom() -> void:
	for species in ["wolf", "goblin"]:
		var made := _species_player(species)
		var p: Player = made[0]
		var rules: SkillRulesEngine = made[1]
		_stun_next_to(p, "bat")
		assert_false(p.try_cocoon(), species)
		assert_eq(_count(rules, "prey_cocooned"), 0, species)
