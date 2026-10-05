extends GutTest
## A verb's spec may name a deed it earns when the player casts it (the Tomte's and the Hearth God's ward-stones).

class Hands extends Node2D:
	var team := "player"
	var facing := 1
	var deeds: Array = []
	func apply_impulse(_v: Vector2) -> void:
		pass
	func emit_deed(event_name: String, tags := {}) -> void:
		deeds.append([event_name, tags])

class Bare extends Node2D:
	var team := "player"
	var facing := 1
	func apply_impulse(_v: Vector2) -> void:
		pass

func _cast(actor: Node2D, spec: Dictionary) -> void:
	add_child_autofree(actor)
	actor.add_to_group("actors")
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	add_child_autofree(a)
	a.spec = spec
	a.setup(actor, [0], 1)
	a.activate()

func after_each() -> void:
	for f in get_tree().get_nodes_in_group("player_clouds"):
		f.free()

func test_a_zone_that_names_a_deed_says_it_once_when_cast() -> void:
	var h := Hands.new()
	_cast(h, {"kind": "zone", "deed": "ward_stone_placed"})
	assert_eq(h.deeds, [["ward_stone_placed", {}]])

func test_a_spec_without_a_deed_says_nothing() -> void:
	var h := Hands.new()
	_cast(h, {"kind": "zone"})
	assert_eq(h.deeds, [])

func test_a_caster_that_cannot_say_deeds_earns_nothing_and_nothing_breaks() -> void:
	var b := Bare.new()
	_cast(b, {"kind": "zone", "deed": "ward_stone_placed"})
	assert_eq(get_tree().get_nodes_in_group("player_clouds").size(), 1, "the zone was still cast")

func test_the_deed_is_said_for_any_kind() -> void:
	var h := Hands.new()
	_cast(h, {"kind": "ring", "deed": "ward_stone_placed"})
	assert_eq(h.deeds.size(), 1)

func test_validate_accepts_a_known_deed_on_any_kind() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "zone", "deed": "ward_stone_placed"})), [])
	assert_eq(Array(VerbKinds.validate({"kind": "bolt", "deed": "trap_sprung"})), [])

func test_validate_rejects_a_deed_that_is_not_one() -> void:
	assert_eq(Array(VerbKinds.validate({"kind": "zone", "deed": "nope"})), ["zone: deed 'nope' is not a deed"])
	assert_eq(Array(VerbKinds.validate({"kind": "zone", "deed": 3})), ["zone: deed must be a deed name"])

func test_the_two_ward_stone_verbs_name_the_deed() -> void:
	for id in ["verb_goblin_tomte", "verb_goblin_hearth_god"]:
		var sd: SkillDef = null
		for d in DefLoader.load_dir("res://data/skills"):
			if d.id == id:
				sd = d
		assert_not_null(sd, id)
		assert_eq(SkillEffects.active_spec(sd).get("deed"), "ward_stone_placed", id)
