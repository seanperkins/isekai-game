extends GutTest
## Which behaviour each shipped creature gets: the literal map (the old _act precedence chain is gone), and the def
## combinations the single kind cannot express.

const KINDS := {"bat": Enemy.Kind.SWOOPER, "toad": Enemy.Kind.SPITTER, "lizard": Enemy.Kind.CHARGER,
	"spider": Enemy.Kind.DROPPER, "water_pool": Enemy.Kind.WALKER, "serpent": Enemy.Kind.WALKER,
	"spore_moth": Enemy.Kind.DRIFTER, "mushroom_crab": Enemy.Kind.CHARGER, "vine_snake": Enemy.Kind.SNAKE,
	"pale_moth": Enemy.Kind.DRIFTER, "cave_crayfish": Enemy.Kind.CHARGER, "drift_jelly": Enemy.Kind.DRIFTER,
	"glass_eel": Enemy.Kind.SWOOPER, "bog_lizardman": Enemy.Kind.SPITTER, "storm_eel": Enemy.Kind.SWOOPER}

var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func test_every_shipped_creature_has_its_kind() -> void:
	assert_eq(creatures.keys().size(), KINDS.size(), "the map covers every shipped def")
	for id in KINDS:
		var e := Enemy.new()
		e.use_sheet = false
		e.setup(creatures[id], skills_by_id)
		assert_eq(e.kind, KINDS[id], id)
		e.free()

func test_the_initial_state_is_idle_for_a_swooper_and_empty_for_everyone_else() -> void:
	for id in KINDS:
		var e := Enemy.new()
		e.use_sheet = false
		e.setup(creatures[id], skills_by_id)
		assert_eq(e._state, "idle" if KINDS[id] == Enemy.Kind.SWOOPER else "", id)
		assert_eq(e.swoop_state(), "idle", "%s: swoop_state is idle for everyone until a swooper changes it" % id)
		assert_eq(e.charge_state(), "", id)
		e.free()

func _flags(id: String) -> Dictionary:
	var c: CreatureDef = creatures[id]
	var has := {}
	for s in c.skills:
		has[s["id"]] = true
	return {"ceiling": has.has("ceiling_walk"), "flight": has.has("flight"), "drifter": c.drifter,
		"armored": c.armored_charger, "spit": has.has("poison_spit")}

func test_no_def_combines_behaviours_one_kind_cannot_express() -> void:
	for id in creatures:
		var f := _flags(id)
		if id != "vine_snake" and f["ceiling"]:
			assert_false(f["flight"] or f["drifter"] or f["armored"] or f["spit"], "%s: a ceiling walker falls through to a walker after it drops" % id)
		assert_false(f["armored"] and f["spit"], "%s: an armored charger that also spits would need two live states" % id)
