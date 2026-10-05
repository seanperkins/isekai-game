extends GutTest
## A form's verb: a form_verb skill the form grants on arrival. It is never unlocked, never in the Compendium or a rebirth kit,
## and the next form's verb takes its slot.

class Foe extends Node2D:
	var team := "enemy"
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])

var rules: SkillRulesEngine
var player: Player

func after_each() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()

func _verb_skill(id: String, spec: Variant = {"kind": "bolt"}, fields := {}) -> SkillDef:
	var f := {"source": "form_verb", "mp_cost": 2, "max_level": 1,
		"effects": [{"kind": "active", "scene": "res://scenes/abilities/verb.tscn", "values": [4], "spec": spec}]}
	f.merge(fields, true)
	return TestDefs.skill(id, f)

func _form(id: String, stage: int, parent: String, verb := "") -> FormDef:
	var f := FormDef.new()
	f.id = id
	f.display_name = id
	f.species = "slime"
	f.stage = stage
	f.lineage = "weaver"
	f.parents = [parent]
	f.verb = verb
	if verb != "":
		f.grants = [verb]
	return f

func _build(defs: Array, forms: Array) -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(defs)
	player = Player.new()
	player.setup(rules, CompendiumModel.new(defs, []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	player.forms = {}
	for f in forms:
		player.forms[f.id] = f

func _slots() -> Array:
	return player.skillset.slots.slots

func _evolve(id: String) -> void:
	assert_true(player.advance_form(id, true), "evolved into %s" % id)

# --- the skill source ---

## What the validator says about one skill (the data check also wants creatures for the real sources, which these fixtures lack).
func _about(skill: SkillDef) -> Array:
	return Array(DefValidator.validate([skill], [])).filter(func(m: String) -> bool: return m.begins_with("<%s>" % skill.id))

func test_a_form_verb_skill_validates_without_an_unlock() -> void:
	assert_eq(_about(_verb_skill("fv")), [])

func test_a_form_verb_with_a_bad_spec_is_reported() -> void:
	var errs := "\n".join(DefValidator.validate([_verb_skill("fv", {"kind": "bolt", "range": "far"})], []))
	assert_string_contains(errs, "bolt: range must be a number")
	assert_string_contains("\n".join(DefValidator.validate([_verb_skill("fv", {"kind": "swoosh"})], [])), "unknown verb kind 'swoosh'")
	assert_string_contains("\n".join(DefValidator.validate([_verb_skill("fv", {})], [])), "unknown verb kind ''")

func test_a_form_verb_that_is_unlocked_or_levelled_or_passive_is_reported() -> void:
	var unlocked := _verb_skill("fv", {"kind": "bolt"}, {"unlock": [TestDefs.counter("jumped", 3)]})
	assert_string_contains("\n".join(DefValidator.validate([unlocked], [])), "form_verb skill must not have an unlock")
	var levelled := _verb_skill("fv", {"kind": "bolt"}, {"max_level": 2})
	assert_string_contains("\n".join(DefValidator.validate([levelled], [])), "form_verb skill must have max_level 1")
	var passive := TestDefs.skill("fv", {"source": "form_verb", "mp_cost": 2})
	assert_string_contains("\n".join(DefValidator.validate([passive], [])), "form_verb skill needs an active effect")
	var free := _verb_skill("fv", {"kind": "bolt"}, {"mp_cost": 0})
	assert_string_contains("\n".join(DefValidator.validate([free], [])), "needs a positive mp_cost")

func test_a_form_verb_whose_spec_is_not_a_dictionary_is_reported_not_crashed() -> void:
	for bad in ["bolt", [1], 3]:
		assert_string_contains("\n".join(_about(_verb_skill("fv", bad))), "spec must be a dictionary")

func test_nothing_can_unlock_on_a_form_verb() -> void:
	var needs := TestDefs.skill("needy", {"unlock": [TestDefs.level("fv", 1)]})
	assert_string_contains("\n".join(DefValidator.validate([_verb_skill("fv"), needs], [])), "references form_verb skill 'fv'")

func test_the_compendium_has_no_slot_for_a_form_verb() -> void:
	var model := CompendiumModel.new([_verb_skill("fv"), TestDefs.skill("plain")], [])
	assert_false(model.states().has("fv"))
	assert_true(model.states().has("plain"))
	assert_false(model.raise("fv", CompendiumModel.State.OWNED_ONCE))

func test_a_rebirth_kit_never_offers_a_form_verb() -> void:
	var as_power := TestDefs.skill("fv")  # a compendium slot under the same id, so only the kit's own filter can drop it
	var model := CompendiumModel.new([as_power], [])
	model.raise("fv", CompendiumModel.State.OWNED_ONCE)
	assert_eq(HeadStart.eligible_powers(model, [_verb_skill("fv")]), [])
	assert_eq(HeadStart.eligible_powers(model, [as_power]), ["fv"], "the same id as a plain power is offered")

func test_a_tablet_hint_cannot_name_a_form_verb() -> void:
	assert_eq(RoomLint.hintable_from([_verb_skill("fv"), TestDefs.skill("plain"), TestDefs.skill("foe", {"source": "enemy_only"})]), ["plain"])

# --- the form's verb ---

func test_evolving_into_a_form_grants_its_verb_into_a_slot() -> void:
	_build([_verb_skill("va")], [_form("fa", 2, "slime", "va")])
	_evolve("fa")
	assert_true(rules.owned().has("va"))
	assert_true(_slots().has("va"))
	assert_true(player.skillset.slots.owned.has("va"))

func test_using_the_verb_spends_mp_and_hits_a_foe() -> void:
	_build([_verb_skill("va")], [_form("fa", 2, "slime", "va")])
	_evolve("fa")
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	var foe := Foe.new()
	add_child_autofree(foe)
	foe.add_to_group("actors")
	foe.global_position = player.global_position + Vector2(60, 0)
	var mp := player.mana.mp
	player.use_active(_slots().find("va"))
	assert_eq(player.mana.mp, mp - 2)
	assert_eq(foe.hits.size(), 1)
	assert_eq(foe.hits[0][1], "physical")

func test_the_next_form_replaces_the_verb_in_the_same_slot() -> void:
	_build([_verb_skill("va"), _verb_skill("vb")],
		[_form("fa", 2, "slime", "va"), _form("fb", 3, "fa", "vb")])
	_evolve("fa")
	var slot := _slots().find("va")
	assert_gte(slot, 0)
	_evolve("fb")
	assert_eq(_slots()[slot], "vb", "the same slot")
	assert_false(_slots().has("va"))
	assert_false(player.skillset.slots.owned.has("va"))
	assert_true(player.skillset.slots.owned.has("vb"))
	assert_lte(player.skillset.slots.owned.size(), ActiveSlots.SLOT_COUNT)

func test_a_verb_still_in_a_slot_the_player_moved_is_replaced_where_it_is() -> void:
	_build([_verb_skill("va"), _verb_skill("vb")], [_form("fa", 2, "slime", "va"), _form("fb", 3, "fa", "vb")])
	_evolve("fa")
	player.skillset.slots.assign(3, "va")
	_evolve("fb")
	assert_eq(_slots()[3], "vb")

func test_a_form_without_a_verb_evolves_as_before() -> void:
	_build([_verb_skill("va")], [_form("fa", 2, "slime", "va"), _form("fb", 3, "fa")])
	_evolve("fa")
	var before := _slots().duplicate()
	_evolve("fb")
	assert_eq(_slots(), before)
	assert_true(player.skillset.slots.owned.has("va"))

func test_a_form_with_a_verb_after_one_without_takes_a_free_slot() -> void:
	_build([_verb_skill("vb")], [_form("fa", 2, "slime"), _form("fb", 3, "fa", "vb")])
	_evolve("fa")
	_evolve("fb")
	assert_true(_slots().has("vb"))

# --- the Skills tab ---

func _skill_ids_listed(rows: Array) -> Array:
	return rows.filter(func(r: Dictionary) -> bool: return r["kind"] == "skill").map(func(r: Dictionary) -> String: return r["id"])

func test_the_skills_tab_lists_the_form_verbs_the_player_can_equip() -> void:
	var defs := [_verb_skill("va"), _verb_skill("vb"), TestDefs.skill("plain")]
	_build(defs, [])
	rules.grant("va")
	rules.grant("vb")
	var rows := SkillScreenModel.skill_rows(rules, defs, ["va"])
	assert_eq(_skill_ids_listed(rows), ["va"], "a verb that was replaced is not offered, and an unheld skill is not a row")
	assert_true(rows.any(func(r: Dictionary) -> bool: return r["kind"] == "header" and r["text"] == "BODY"))
	assert_false(SkillScreenModel.skill_rows(rules, defs).any(func(r: Dictionary) -> bool: return r["kind"] == "header" and r["text"] == "BODY"),
		"no verb to equip, no BODY header")

func test_the_compendium_never_lists_a_form_verb() -> void:
	var defs := [_verb_skill("fv"), TestDefs.skill("plain")]
	var rows := SkillScreenModel.compendium_rows(CompendiumModel.new(defs, []), defs)
	assert_false(rows.any(func(r: Dictionary) -> bool: return r.get("id", "") == "fv"))

func test_an_evicted_form_verb_stays_equippable_and_can_be_put_back() -> void:
	var defs := [_verb_skill("va")]
	_build(defs, [_form("fa", 2, "slime", "va")])
	_evolve("fa")
	var slots: ActiveSlots = player.skillset.slots
	for id in ["x1", "x2", "x3", "x4"]:
		slots.add(id)
	assert_false(slots.slots.has("va"), "pushed out by four newer actives")
	assert_true(slots.owned.has("va"))
	assert_eq(_skill_ids_listed(SkillScreenModel.skill_rows(rules, defs, slots.owned)), ["va"])
	slots.assign(slots.next_slot_for("va"), "va")
	assert_true(slots.slots.has("va"))

# --- the form validator ---

func _check(f: FormDef, verbs: Array, known: Array) -> String:
	return "\n".join(FormValidator.validate({f.id: f}, known, false, verbs))

func test_form_validator_checks_the_verb_is_granted_and_known() -> void:
	var f := _form("fa", 2, "slime", "va")
	f.species = "slime"
	assert_false(_check(f, ["va"], ["va"]).contains("verb '"), "a granted, known form_verb skill is fine")
	assert_string_contains(_check(f, ["va"], []), "grants unknown skill 'va'")
	assert_string_contains(_check(f, [], ["va"]), "fa: verb 'va' is not a form_verb skill")
	f.grants = []
	assert_string_contains(_check(f, ["va"], ["va"]), "fa: verb 'va' must be in its grants")
	var plain := _form("fb", 2, "slime")
	assert_false(_check(plain, [], []).contains("verb '"), "no verb, nothing to check")
