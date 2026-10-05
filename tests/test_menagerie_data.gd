extends GutTest
## The twins and support monsters as creature data: every one is a real creature the game can spawn.

var creatures := {}
var forms: Dictionary

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	forms = FormLoader.load_all()

func test_every_source_is_counted() -> void:
	assert_eq(Sources.SHIPPED.size(), 19)
	assert_eq(MenagerieIds.TWINS.size(), 140)
	assert_eq(MenagerieIds.SUPPORT.size(), 28)
	assert_eq(MenagerieIds.ALL.size(), 168)
	assert_eq(Sources.ALL.size(), 187)
	assert_eq(Sources.ALL.slice(0, 19), Sources.SHIPPED, "the shipped creatures keep their places")

func test_every_source_has_exactly_one_creature_and_the_content_loads_clean() -> void:
	var content := DefLoader.load_content("res://data/skills", "res://data/creatures")
	assert_eq(content["errors"], [], "no errors")
	assert_eq(content["creatures"].size(), 187)
	for id in Sources.ALL:
		assert_true(creatures.has(id), id)

func test_a_twin_is_the_twin_of_a_real_form_of_its_species_with_its_verb() -> void:
	for id in MenagerieIds.TWINS:
		var c: CreatureDef = creatures[id]
		assert_eq(c.origin, "twin", id)
		var f: FormDef = forms.get(c.form)
		assert_not_null(f, "%s names form %s" % [id, c.form])
		if f == null:
			continue
		assert_eq(id, "twin_" + c.form)
		assert_eq(c.species, f.species, id)
		assert_eq(c.stage, f.stage, id)
		assert_eq(c.verb, f.verb, id)
		if f.sprite_set != "":
			assert_eq([c.sprite_set, c.sprite_frame], [f.sprite_set, f.sprite_frame if f.sprite_frame != "" else "idle_1"], id)
		else:
			assert_eq([c.sprite_set, c.sprite_frame], ["slime", "idle_1"], "%s wears the slime sheet tinted" % id)
			assert_eq(c.sprite_tint, f.tint, id)
		assert_eq(c.display_name, f.display_name, id)

func test_every_creature_carries_essence_it_can_pay() -> void:
	for id in MenagerieIds.ALL:
		var c: CreatureDef = creatures[id]
		assert_false(c.essences.is_empty(), id)
		for e in c.essences:
			assert_true(Essences.ALL.has(e), "%s: %s" % [id, e])
		assert_gt(c.xp, 0, id)
		assert_true(c.predatable, id)

func test_a_higher_stage_is_stronger() -> void:
	var stage_hp := {}
	for id in MenagerieIds.TWINS:
		var c: CreatureDef = creatures[id]
		var stage: int = forms[c.form].stage
		stage_hp[stage] = maxi(int(stage_hp.get(stage, 0)), int(c.stats["max_hp"]))
	assert_lt(stage_hp[2], stage_hp[3])
	assert_lt(stage_hp[3], stage_hp[4])

func test_support_monsters_are_no_stage() -> void:
	for id in MenagerieIds.SUPPORT:
		assert_eq(creatures[id].stage, 0, id)
		assert_eq(creatures[id].origin, "support", id)

func test_the_shipped_creatures_are_untouched() -> void:
	assert_eq(creatures["taratect"].stats["max_hp"], 24)
	assert_eq(creatures["spider"].origin, "")
	assert_eq(creatures["gloom_wolf"].verb, "")
	assert_eq(creatures["gloom_wolf"].sprite_set, "")

func test_the_wolf_twins_hunt_in_packs_and_charge() -> void:
	var c: CreatureDef = creatures["twin_wolf_fenrir"]
	assert_true(c.pack)
	assert_true(c.charges)
	assert_false(creatures["twin_undead_zombie"].pack)
