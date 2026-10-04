extends GutTest
## Which powers a creature names when it is appraised (Appraisal level 2), with the real content.

const S := CompendiumModel.State

func _model() -> CompendiumModel:
	return CompendiumModel.new(DefLoader.load_dir("res://data/skills"), DefLoader.load_dir("res://data/creatures"))

func _named_by(creature_id: String) -> Array:
	var m := _model()
	m.creature_report(creature_id, 2, true)
	var out: Array = []
	for id in ["echolocation", "hydraulic_propulsion", "poison_breath", "spore_cloud", "jolt", "body_armor", "hardened_shell", "tremor", "sticky_thread"]:
		if m.state(id) == S.NAMED:
			out.append(id)
	return out

func test_a_bat_names_echolocation_but_not_the_mixes_it_only_half_carries() -> void:
	assert_eq(_named_by("bat"), ["echolocation"], "air alone is not Spore Cloud (needs dark) or Jolt (needs light)")

func test_a_toad_names_poison_breath_and_hydraulic_propulsion() -> void:
	assert_eq(_named_by("toad"), ["hydraulic_propulsion", "poison_breath"])

func test_a_spore_moth_carries_both_halves_of_spore_cloud() -> void:
	var named := _named_by("spore_moth")
	assert_true(named.has("spore_cloud"))
	assert_true(named.has("echolocation"))

func test_a_black_spider_names_sticky_thread_because_it_is_the_creature_to_eat() -> void:
	assert_true(_named_by("spider").has("sticky_thread"))

func test_a_vine_snake_no_longer_names_sticky_thread() -> void:
	var named := _named_by("vine_snake")
	assert_false(named.has("sticky_thread"), "its thread is gone and it is not the source the unlock names")
	assert_true(named.has("poison_breath"))

func test_an_eel_carries_both_halves_of_jolt() -> void:
	assert_true(_named_by("glass_eel").has("jolt"))
