extends GutTest
## The form tree: 24 static forms, the legal transitions between stages, and the stage caps.

var forms := {}
var skill_ids: Array = []

func before_all() -> void:
	forms = FormLoader.load_all()
	for d in DefLoader.load_dir("res://data/skills"):
		if d.source != "enemy_only":
			skill_ids.append(d.id)

func test_there_are_24_forms_across_stages_two_to_four() -> void:
	assert_eq(forms.size(), 24)
	var per_stage := {2: 0, 3: 0, 4: 0}
	for id in forms:
		per_stage[(forms[id] as FormDef).stage] += 1
	assert_eq(per_stage, {2: 6, 3: 12, 4: 6})

func test_the_data_passes_its_validator() -> void:
	var errs := FormValidator.validate(forms, skill_ids)
	assert_eq(errs.size(), 0, str(errs))

func test_every_stage_two_form_grows_from_the_base_slime() -> void:
	var roots := FormLoader.stage2_forms(forms)
	assert_eq(roots.size(), 6)
	for f in roots:
		assert_eq((f as FormDef).parents, ["slime"])

func test_a_stage_two_form_has_exactly_two_children_and_a_stage_three_form_exactly_one() -> void:
	for id in forms:
		var f: FormDef = forms[id]
		var kids := FormLoader.children_of(forms, id)
		if f.stage == 2:
			assert_eq(kids.size(), 2, "%s: two stage-3 children" % id)
		elif f.stage == 3:
			assert_eq(kids.size(), 1, "%s: one Sovereign" % id)
		else:
			assert_eq(kids.size(), 0, "%s: the last stage" % id)

func test_both_stage_three_forms_of_a_lineage_lead_to_the_same_sovereign() -> void:
	for id in forms:
		var f: FormDef = forms[id]
		if f.stage != 2:
			continue
		var kids := FormLoader.children_of(forms, id)
		var sovereigns := {}
		for k in kids:
			sovereigns[FormLoader.children_of(forms, (k as FormDef).id)[0].id] = true
		assert_eq(sovereigns.size(), 1, "%s: both children share a Sovereign" % id)

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
	assert_eq(reached.size(), 6, "six Sovereigns")
	for id in reached:
		assert_eq(reached[id], 4, id)

func test_advance_only_takes_legal_steps() -> void:
	var f := Form.new()
	assert_false(f.advance("silkbound", forms), "cannot skip stages")
	assert_false(f.advance("snare", forms), "a stage-3 form is not a child of the base slime")
	assert_false(f.advance("no_such_form", forms))
	assert_eq(f.stage, 1)
	assert_true(f.advance("weaver", forms))
	assert_eq([f.stage, f.form_id], [2, "weaver"])
	assert_false(f.advance("brook", forms), "a child of Tide, not of Weaver")
	assert_true(f.advance("arachne", forms))
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
