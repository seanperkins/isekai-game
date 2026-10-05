extends GutTest
## The parts a body can carry or wear: the ten of the design's table, their slots and their passives.

var parts: Dictionary

func before_all() -> void:
	parts = PartLoader.load_all()

func _part(fields := {}) -> PartDef:
	var p := PartDef.new()
	p.id = "test_part"
	p.display_name = "Test part"
	p.kind = "graft"
	p.slot = "ribs"
	p.text = "A test."
	for key in fields:
		p.set(key, fields[key])
	return p

func test_the_ten_parts_load() -> void:
	var ids := parts.keys()
	ids.sort()
	assert_eq(ids, ["bow_arm", "claw", "flesh", "focus", "moonstone", "phylactery_shard", "ribs", "skull", "weapon_arm", "wrappings"])

func test_every_shipped_part_validates() -> void:
	assert_eq(PartValidator.validate(parts), PackedStringArray())

func test_the_grafts_and_the_others() -> void:
	for id in ["ribs", "flesh", "claw", "weapon_arm", "bow_arm", "skull", "focus", "wrappings"]:
		assert_eq(parts[id].kind, "graft", id)
		assert_ne(parts[id].slot, "", id)
	assert_eq(parts["phylactery_shard"].kind, "held")
	assert_eq(parts["moonstone"].kind, "key")
	for id in ["phylactery_shard", "moonstone"]:
		assert_eq(parts[id].slot, "")
		assert_true(parts[id].stats.is_empty())

func test_two_claws_and_two_wrappings_can_be_worn_and_every_other_graft_one() -> void:
	for id in ["claw", "wrappings"]:
		assert_eq(parts[id].worn_max, 2, id)
	for id in ["ribs", "flesh", "weapon_arm", "bow_arm", "skull", "focus"]:
		assert_eq(parts[id].worn_max, 1, id)

func test_the_passives() -> void:
	assert_eq(parts["ribs"].stats, {"def": 1})
	assert_eq(parts["flesh"].stats, {"max_hp": 4})
	assert_eq(parts["claw"].stats, {"atk": 1})
	assert_eq(parts["weapon_arm"].stats, {"atk": 2})
	assert_eq(parts["bow_arm"].stats, {"spd": 10})
	assert_eq(parts["skull"].stats, {"max_mp": 3})
	assert_eq(parts["focus"].stats, {"max_mp": 4})
	assert_eq(parts["wrappings"].stats, {"def": 1})

func test_every_part_has_a_name_a_text_and_a_colour_of_its_own() -> void:
	var colours := {}
	for id in parts:
		var p: PartDef = parts[id]
		assert_ne(p.display_name, "", id)
		assert_ne(p.text, "", id)
		assert_false(colours.has(p.color), "%s shares a colour" % id)
		colours[p.color] = true

func test_the_validator_accepts_a_good_part() -> void:
	assert_eq(PartValidator.validate({"test_part": _part()}), PackedStringArray())

func test_the_validator_rejects_each_kind_of_bad_part() -> void:
	var bad := {
		"an unknown kind": _part({"kind": "trinket"}),
		"a graft with no slot": _part({"slot": ""}),
		"a graft worn zero times": _part({"worn_max": 0}),
		"a graft worn three times": _part({"worn_max": 3}),
		"a held part with a slot": _part({"kind": "held", "slot": "ribs"}),
		"an unknown stat": _part({"stats": {"luck": 1}}),
		"no name": _part({"display_name": ""}),
		"no text": _part({"text": ""}),
		"an id that is not its key": _part({"id": "other"}),
	}
	for what in bad:
		assert_gt(PartValidator.validate({"test_part": bad[what]}).size(), 0, what)
