extends GutTest
## FormGate: a form's gate read against a run's ledger, and the checks that keep a gate honest.

var engine: SkillRulesEngine

func before_each() -> void:
	engine = autofree(SkillRulesEngine.new())
	engine.setup([TestDefs.skill("rise", {"starting": true}), TestDefs.skill("howl", {"unlock": [TestDefs.counter("jumped", 99)]})])
	engine.start_run()

func _def(gate: Array) -> FormDef:
	var d := FormDef.new()
	d.id = "wolf_test"
	d.species = "wolf"
	d.stage = 2
	d.lineage = "test"
	d.parents = ["wolf"]
	d.gate = gate
	return d

func _counter(event: String, n: int, tags := {}, text := "a deed") -> Dictionary:
	return {"kind": "counter", "event": event, "tags": tags, "n": n, "text": text}

func _feed(event: String, times: int, tags := {}) -> void:
	for i in times:
		engine.handle_event(event, tags.duplicate())

func test_a_counter_atom_is_met_at_its_n_and_not_before() -> void:
	var d := _def([_counter("absorbed", 3, {"essence": "dark"}, "dark essence")])
	_feed("absorbed", 2, {"essence": "dark", "source": "bat"})
	assert_false(FormGate.met(d, engine))
	_feed("absorbed", 1, {"essence": "dark", "source": "bat"})
	assert_true(FormGate.met(d, engine))
	_feed("absorbed", 5, {"essence": "water", "source": "bat"})
	assert_eq(engine.condition_value(d.gate[0]), 3, "another element does not count")

func test_a_gate_is_met_only_when_every_atom_is() -> void:
	var d := _def([_counter("jumped", 1), _counter("wall_touched", 1)])
	_feed("jumped", 1)
	assert_false(FormGate.met(d, engine))
	_feed("wall_touched", 1)
	assert_true(FormGate.met(d, engine))

func test_an_empty_gate_is_met() -> void:
	assert_true(FormGate.met(_def([]), engine))
	assert_eq(FormGate.progress(_def([]), engine), [])

func test_a_streak_restarts_when_the_reset_event_comes() -> void:
	var streak := {"kind": "reset_counter", "event": "defeated", "tags": {}, "reset_on": "damaged", "n": 3, "text": "kills without a hit"}
	var d := _def([streak])
	_feed("defeated", 2)
	engine.handle_event("damaged", {"damage_type": "physical"})
	_feed("defeated", 2)
	assert_false(FormGate.met(d, engine), "the hit between the kills restarted it")
	_feed("defeated", 1)
	assert_true(FormGate.met(d, engine))

func test_a_skill_level_atom_needs_the_skill_owned() -> void:
	var d := _def([{"kind": "skill_level", "id": "rise", "n": 1, "text": "Rise"}, {"kind": "skill_level", "id": "howl", "n": 1, "text": "Howl"}])
	assert_false(FormGate.met(d, engine), "howl is not owned")
	var only_rise := _def([d.gate[0]])
	assert_true(FormGate.met(only_rise, engine))

func test_a_held_atom_reads_what_is_still_held() -> void:
	var d := _def([{"kind": "held", "element": "blood", "n": 5, "text": "a full cap of blood"}])
	_feed("absorbed", 5, {"essence": "blood", "source": "bat"})
	assert_true(FormGate.met(d, engine))
	assert_true(engine.spend_essence("blood", 2))
	assert_false(FormGate.met(d, engine), "spent essence is no longer held")

func test_an_any_atom_is_met_when_one_member_is_and_shows_the_best_progress() -> void:
	var any := {"kind": "any", "text": "a kill in moonlight or a Moonstone", "of": [_counter("defeated", 3, {"moonlit": true}), _counter("part_harvested", 1, {})]}
	var d := _def([any])
	_feed("defeated", 2, {"moonlit": true})
	assert_false(FormGate.met(d, engine))
	var row: Dictionary = FormGate.progress(d, engine)[0]
	assert_eq([row["have"], row["need"], row["met"]], [2, 3, false], "the nearer member")
	_feed("part_harvested", 1)
	assert_true(FormGate.met(d, engine))

func test_progress_has_a_row_per_atom_with_have_capped_at_need() -> void:
	var d := _def([_counter("jumped", 3, {}, "jumps"), _counter("wall_touched", 2, {}, "wall touches")])
	_feed("jumped", 7)
	_feed("wall_touched", 1)
	var rows := FormGate.progress(d, engine)
	assert_eq(rows.size(), 2)
	assert_eq([rows[0]["text"], rows[0]["have"], rows[0]["need"], rows[0]["met"]], ["jumps", 3, 3, true])
	assert_eq([rows[1]["text"], rows[1]["have"], rows[1]["need"], rows[1]["met"]], ["wall touches", 1, 2, false])

func test_the_summary_names_what_is_missing_and_says_ready_when_nothing_is() -> void:
	var d := _def([_counter("jumped", 3, {}, "jumps"), _counter("wall_touched", 2, {}, "wall touches")])
	_feed("jumped", 3)
	_feed("wall_touched", 1)
	assert_eq(FormGate.summary(d, engine), "wall touches 1/2")
	_feed("wall_touched", 1)
	assert_eq(FormGate.summary(d, engine), "ready")

func test_validate_accepts_a_good_gate_and_a_reserved_event() -> void:
	var d := _def([_counter("absorbed", 10, {"essence": "dark"}, "dark essence"), _counter("graft_attached", 1, {"part": "ribs"}, "a rib graft"),
		_counter("defeated", 5, {"behind": true}, "kills from behind")])
	assert_eq(FormGate.validate(d), PackedStringArray())

func test_validate_rejects_each_kind_of_bad_atom() -> void:
	var bad := {
		"an unknown event": _counter("nothing_happened", 1),
		"a tag the event does not have": _counter("defeated", 1, {"colour": "red"}),
		"n below one": _counter("jumped", 0),
		"no text": {"kind": "counter", "event": "jumped", "tags": {}, "n": 1},
		"an unknown kind": {"kind": "feeling", "n": 1, "text": "x"},
		"an any with no members": {"kind": "any", "text": "x", "of": []},
		"a held atom of an unknown element": {"kind": "held", "element": "plasma", "n": 1, "text": "x"},
		"a skill_level with no skill": {"kind": "skill_level", "n": 1, "text": "x"},
		"a reset on nothing": {"kind": "reset_counter", "event": "defeated", "tags": {}, "reset_on": "nothing_happened", "n": 1, "text": "x"},
	}
	for what in bad:
		assert_gt(FormGate.validate(_def([bad[what]])).size(), 0, what)

func test_the_form_validator_includes_a_forms_gate_errors() -> void:
	var forms := FormLoader.load_all()
	forms["wolf_moonbound"].gate = [_counter("nothing_happened", 1)]
	var errs := FormValidator.validate(forms, SkillRules.skill_defs.map(func(d: SkillDef) -> String: return d.id))
	assert_true(Array(errs).any(func(e: String) -> bool: return e.begins_with("wolf_moonbound:") and e.contains("nothing_happened")))

func test_every_deed_has_tags_and_every_reserved_name_is_a_real_event() -> void:
	for e in Deeds.EVENTS:
		assert_true(Deeds.TAGS.has(e), "%s has a tag list" % e)
		assert_true(Deeds.known(e))
	for key in Deeds.RESERVED:
		var event: String = str(key).split(".")[0]
		assert_true(Deeds.known(event), "%s is reserved but is no event" % key)
	assert_true(Deeds.known("absorbed") and Deeds.known("defeated"))
	assert_false(Deeds.known("nothing_happened"))
	assert_false(Events.ALL.has(Deeds.DEFEATED), "deeds stay out of the pinned list")

func test_the_rules_engine_and_the_def_validator_accept_a_deed() -> void:
	var skill := TestDefs.skill("ambusher", {"unlock": [TestDefs.counter("defeated", 3, {"behind": true})]})
	var errors := DefValidator.validate([skill], TestDefs.all_creatures())
	assert_false(Array(errors).any(func(e: String) -> bool: return e.contains("unknown event")), str(errors))
