extends GutTest
## The shipped gates: every wolf, undead, spider and goblin form has one, it is valid, and the deeds it waits for are listed.

## The deeds something emits today (the rest of Deeds.EVENTS is in Deeds.RESERVED).
const EMITTED := ["defeated", "guard_broken", "room_cleared", "room_entered", "skill_hit", "skill_missed", "switch_hit"]
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
	assert_true(waiting.has("E1") and waiting.has("E2") and waiting.has("F2"), str(waiting))
	gut.p("gate atoms waiting on a later piece: %s" % waiting)
