extends GutTest
## The slime's form tree: 42 forms, the legal transitions between stages, and the stage caps.

var forms := {}
var skill_ids: Array = []

func before_all() -> void:
	forms = FormLoader.load_species()
	for d in DefLoader.load_dir("res://data/skills"):
		if d.source != "enemy_only":
			skill_ids.append(d.id)

func test_there_are_42_slime_forms_across_stages_two_to_four() -> void:
	assert_eq(forms.size(), 42)
	var per_stage := {2: 0, 3: 0, 4: 0}
	for id in forms:
		per_stage[(forms[id] as FormDef).stage] += 1
	assert_eq(per_stage, {2: 6, 3: 12, 4: 24})

func test_the_data_passes_its_validator() -> void:
	var errs := FormValidator.validate(forms, skill_ids, false, TestDefs.real_verb_ids())
	assert_eq(errs.size(), 0, str(errs))

func test_every_stage_two_form_grows_from_the_base_slime() -> void:
	var roots := FormLoader.stage2_forms(forms)
	assert_eq(roots.size(), 6)
	for f in roots:
		assert_eq((f as FormDef).parents, ["slime"])

func test_a_stage_two_or_three_form_has_exactly_two_children() -> void:
	for id in forms:
		var f: FormDef = forms[id]
		var kids := FormLoader.children_of(forms, id)
		if f.stage < 4:
			assert_eq(kids.size(), 2, "%s: two children" % id)
		else:
			assert_eq(kids.size(), 0, "%s: the last stage" % id)

func test_no_branch_rejoins_every_stage_three_and_four_form_has_one_parent() -> void:
	for id in forms:
		var f: FormDef = forms[id]
		if f.stage > 2:
			assert_eq(f.parents.size(), 1, "%s: one parent" % id)

func test_every_branch_reaches_stage_four() -> void:
	var frontier: Array = ["slime"]
	var reached := {}
	while not frontier.is_empty():
		var id: String = frontier.pop_back()
		var kids: Array = FormLoader.children_of(forms, id) if id != "slime" else FormLoader.stage2_forms(forms)
		if kids.is_empty():
			reached[id] = (forms[id] as FormDef).stage
		for k in kids:
			frontier.append((k as FormDef).id)
	assert_eq(reached.size(), 24, "twenty-four form-4s, each its own ending")
	for id in reached:
		assert_eq(reached[id], 4, id)

func test_the_eighteen_new_forms_hang_where_the_design_puts_them() -> void:
	var expected := {"snare": ["gleipnir", "silkbound"], "arachne": ["ariadne", "beanstalk"], "brook": ["selkie", "tidal"],
		"tempest": ["kraken", "tiamat"], "acid": ["alkahest", "venom"], "blight": ["pestilence", "slime_mold"],
		"golem": ["stone", "talos"], "crystal": ["cube", "philosophers_stone"], "phantom": ["mimic", "poltergeist"],
		"sky": ["cloud_rider", "storm"], "vast": ["prime", "shoggoth"], "radiant": ["king_slime", "quicksilver_slime"]}
	for parent in expected:
		var ids: Array = FormLoader.children_of(forms, parent).map(func(f: FormDef) -> String: return f.id)
		assert_eq(ids, expected[parent], parent)

func test_advance_only_takes_legal_steps() -> void:
	var f := Form.new()
	assert_false(f.advance("silkbound", forms), "cannot skip stages")
	assert_false(f.advance("snare", forms), "a stage-3 form is not a child of the base slime")
	assert_false(f.advance("no_such_form", forms))
	assert_eq(f.stage, 1)
	assert_true(f.advance("weaver", forms))
	assert_eq([f.stage, f.form_id], [2, "weaver"])
	assert_false(f.advance("brook", forms), "a child of Tide, not of Weaver")
	assert_true(f.advance("snare", forms))
	assert_false(f.advance("arachne", forms), "Arachne is Snare's sibling, not its child")
	assert_true(f.advance("silkbound", forms))
	assert_eq([f.stage, f.form_id], [4, "silkbound"])
	assert_false(f.advance("prime", forms), "no stage five")

func test_the_skill_cap_follows_the_stage() -> void:
	var f := Form.new()
	assert_eq(f.cap(), 5)
	f.advance("greater_slime", forms)
	assert_eq(f.cap(), 8)
	f.advance("vast", forms)
	assert_eq(f.cap(), 12)
	f.advance("prime", forms)
	assert_eq(f.cap(), 15)
	f.reset()
	assert_eq([f.stage, f.form_id, f.cap()], [1, "slime", 5])

func test_sizes_grow_with_the_stage_and_stay_modest() -> void:
	var by_stage := {2: 0.0, 3: 0.0, 4: 0.0}
	for id in forms:
		var f: FormDef = forms[id]
		assert_between(f.size, 1.0, 1.5, id)
		by_stage[f.stage] = maxf(by_stage[f.stage], f.size)
	assert_lt(by_stage[2], by_stage[3])
	assert_lt(by_stage[3], by_stage[4])

func test_a_form_names_only_real_stats_skills_and_traits() -> void:
	for id in forms:
		var f: FormDef = forms[id]
		for s in f.stats:
			assert_true(StatKeys.ALL.has(s), "%s: unknown stat %s" % [id, s])
		for g in f.grants:
			assert_true(skill_ids.has(g), "%s: unknown skill %s" % [id, g])
		for t in f.traits:
			assert_true(FormEffects.TRAITS.has(t), "%s: unknown trait %s" % [id, t])

func test_each_lineage_has_its_own_look_and_the_weaver_line_has_art() -> void:
	for id in ["weaver", "snare", "arachne", "silkbound"]:
		assert_eq((forms[id] as FormDef).sprite_set, "form_" + id, id)
	for id in forms:
		if not ["weaver", "snare", "arachne", "silkbound"].has(id):
			assert_eq((forms[id] as FormDef).sprite_set, "", "%s uses the tinted base sheet until its art is generated" % id)

func test_a_later_stage_is_stronger_than_an_earlier_one_in_the_same_lineage() -> void:
	for chain in [["weaver", "snare", "silkbound"], ["tide", "brook", "tidal"], ["toxic", "acid", "venom"],
			["bulwark", "golem", "stone"], ["echo", "phantom", "storm"], ["greater_slime", "vast", "prime"]]:
		var hp := -1
		for id in chain:
			var v := int((forms[id] as FormDef).stats.get("max_hp", 0))
			assert_gt(v, hp, "%s has more max HP than the form before it" % id)
			hp = v

func test_no_form_grants_an_evolution() -> void:
	var by_id := {}
	for d in DefLoader.load_dir("res://data/skills"):
		by_id[d.id] = d
	for id in forms:
		for g in (forms[id] as FormDef).grants:
			assert_ne((by_id[g] as SkillDef).source, "evolution", "%s grants %s" % [id, g])

func test_every_lineage_form_names_the_powers_that_open_it() -> void:
	var expected := {
		"weaver": ["sticky_thread"],
		"tide": ["hydraulic_propulsion"],
		"toxic": ["poison_breath", "spore_cloud"],
		"bulwark": ["body_armor", "hardened_shell", "tremor"],
		"echo": ["echolocation"],
	}
	for id in expected:
		assert_eq((forms[id] as FormDef).powers, expected[id], id)
	for id in forms:
		if not expected.has(id):
			assert_eq((forms[id] as FormDef).powers, [], "%s opens nothing" % id)

func test_the_validator_rejects_an_unknown_power_and_a_power_on_a_later_stage() -> void:
	var bad := forms.duplicate()
	var weaver := (forms["weaver"] as FormDef).duplicate() as FormDef
	weaver.powers = ["no_such_skill"]
	bad["weaver"] = weaver
	assert_string_contains("\n".join(FormValidator.validate(bad, skill_ids)), "no_such_skill")
	var snare := (forms["snare"] as FormDef).duplicate() as FormDef
	snare.powers = ["sticky_thread"]
	bad = forms.duplicate()
	bad["snare"] = snare
	assert_string_contains("\n".join(FormValidator.validate(bad, skill_ids)), "only stage-2")
	var empty := (forms["echo"] as FormDef).duplicate() as FormDef
	empty.powers = []
	bad = forms.duplicate()
	bad["echo"] = empty
	assert_string_contains("\n".join(FormValidator.validate(bad, skill_ids)), "opening power")
