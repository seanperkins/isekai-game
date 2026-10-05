extends GutTest
## The five feature kinds the deeds read: a barrier the dissolve verb opens, a hidden door the reveal verb shows, a gap crossed airborne, a
## lamp drunk, a vigil kept. Each is built by RoomFeatures.make and reports its deed on the event bus.

## A player as the gap and the vigil see it: a position, whether it stands on something, a health.
class PlayerDouble extends Node2D:
	var health := Health.new(10)
	var on_floor := false
	signal inspect_report(lines: PackedStringArray)
	func is_on_floor() -> bool:
		return on_floor

var skills: Array
var rules: SkillRulesEngine
var player: Player
var events: Array

func before_all() -> void:
	skills = DefLoader.load_dir("res://data/skills")

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(skills)
	events = []
	player = Player.new()
	player.setup(rules, CompendiumModel.new(skills, []), [], func(n: String, t: Dictionary) -> void:
		events.append([n, t])
		rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	EventBus.game_event.connect(_on_bus)

func after_each() -> void:
	EventBus.game_event.disconnect(_on_bus)

func _on_bus(name: String, tags: Dictionary) -> void:
	events.append([name, tags])

func _named(name: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == name)

func _built(f: Dictionary) -> Node2D:
	var n := RoomFeatures.make(f, {})
	assert_not_null(n, str(f["kind"]))
	add_child_autofree(n)
	return n

func _double() -> PlayerDouble:
	var p := PlayerDouble.new()
	add_child_autofree(p)
	return p

func _cast(skill_id: String) -> void:
	var a: Ability = player._ability(skill_id)
	player.facing = 1
	a.aim = Vector2.RIGHT
	assert_true(a.activate(), "%s cast" % skill_id)

# --- barrier ---

func test_a_barrier_is_a_solid_block_centred_on_its_box_in_the_dissolvable_group() -> void:
	var b := _built({"kind": "barrier", "id": "T_b", "pos": Vector2(100, 320), "size": Vector2(24, 120)})
	assert_true(b.is_in_group("dissolvable"))
	assert_eq(b.global_position, Vector2(100, 260), "its origin is the middle of the block, where the dissolve verb measures from")
	var bodies := b.find_children("*", "StaticBody2D", true, false)
	assert_eq(bodies.size(), 1)
	assert_eq(((bodies[0].get_child(0) as CollisionShape2D).shape as RectangleShape2D).size, Vector2(24, 120))

func test_dissolving_a_barrier_removes_it() -> void:
	var b := _built({"kind": "barrier", "id": "T_b", "pos": Vector2(100, 320), "size": Vector2(24, 120)})
	b.dissolve()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(b))

func test_the_dissolve_verb_cast_at_a_built_barrier_breaks_it_and_says_so() -> void:
	var b := _built({"kind": "barrier", "id": "T_b", "pos": Vector2(30, 320), "size": Vector2(24, 60)})
	player.global_position = Vector2(0, 290)
	_cast("verb_wolf_fenrir")
	await wait_physics_frames(2)
	assert_eq(_named(Deeds.BARRIER_BROKEN).size(), 1)
	assert_false(is_instance_valid(b))

# --- hidden ---

func test_a_hidden_door_is_a_solid_until_revealed_and_then_a_lit_outline() -> void:
	var h := _built({"kind": "hidden", "id": "T_h", "pos": Vector2(100, 320), "size": Vector2(24, 120)})
	assert_true(h.is_in_group("hidden"))
	assert_eq(h.find_children("*", "StaticBody2D", true, false).size(), 1)
	h.reveal()
	await wait_physics_frames(2)
	assert_false(h.is_in_group("hidden"), "a second cast does not find it again")
	assert_eq(h.find_children("*", "StaticBody2D", true, false).size(), 0, "the way through is open")
	assert_gt(h.get_child_count(), 0, "and the doorway is drawn")
	h.reveal()  # harmless

func test_the_reveal_verb_cast_near_a_hidden_door_shows_it_and_says_so_once() -> void:
	var h := _built({"kind": "hidden", "id": "T_h", "pos": Vector2(60, 320), "size": Vector2(24, 60)})
	player.global_position = Vector2(0, 290)
	_cast("verb_wolf_wepwawet")
	await wait_physics_frames(2)
	assert_eq(_named(Deeds.HIDDEN_FOUND).size(), 1)
	assert_false(h.is_in_group("hidden"), "it is shown now: a later cast finds nothing more")

# --- gap ---

func test_a_gap_crossed_in_the_air_above_its_edge_is_a_deed_once() -> void:
	var gap := _built({"kind": "gap", "id": "T_g", "pos": Vector2(300, 268), "width": 50.0})
	var p := _double()
	p.global_position = Vector2(250, 240)
	gap.step(p)
	p.global_position = Vector2(300, 220)
	gap.step(p)
	assert_eq(_named(Deeds.GAP_CROSSED).size(), 0, "still over the gap")
	p.global_position = Vector2(350, 240)
	gap.step(p)
	assert_eq(_named(Deeds.GAP_CROSSED), [[Deeds.GAP_CROSSED, {"id": "T_g"}]])
	p.global_position = Vector2(250, 240)
	gap.step(p)
	p.global_position = Vector2(350, 240)
	gap.step(p)
	assert_eq(_named(Deeds.GAP_CROSSED).size(), 1, "once per gap")

func test_walking_past_below_the_gap_or_on_the_floor_is_no_crossing() -> void:
	var gap := _built({"kind": "gap", "id": "T_g", "pos": Vector2(300, 268), "width": 50.0})
	var p := _double()
	p.global_position = Vector2(250, 300)  # below the ledges' tops
	gap.step(p)
	p.global_position = Vector2(350, 300)
	gap.step(p)
	p.on_floor = true
	p.global_position = Vector2(250, 240)
	gap.step(p)
	p.global_position = Vector2(350, 240)
	gap.step(p)
	assert_eq(_named(Deeds.GAP_CROSSED).size(), 0)

func test_a_gap_already_crossed_this_life_is_not_a_deed_again_in_a_new_room_visit() -> void:
	rules.handle_event(Deeds.GAP_CROSSED, {"id": "T_g"})  # the ledger of this life
	var gap := _built({"kind": "gap", "id": "T_g", "pos": Vector2(300, 268), "width": 50.0})
	gap.ledger = rules
	var p := _double()
	p.global_position = Vector2(250, 240)
	gap.step(p)
	p.global_position = Vector2(350, 240)
	gap.step(p)
	assert_eq(_named(Deeds.GAP_CROSSED).size(), 0)

# --- lamp ---

func test_a_lamp_is_drunk_once_and_the_prompt_says_drink() -> void:
	var lamp := _built({"kind": "lamp", "id": "T_l", "pos": Vector2(200, 320)})
	assert_true(lamp.is_in_group("interactable"))
	assert_eq(lamp.prompt(), "drink")
	var p := _double()
	lamp.interact(p)
	assert_eq(_named(Deeds.LAMP_DRUNK), [[Deeds.LAMP_DRUNK, {"id": "T_l"}]])
	lamp.interact(p)
	assert_eq(_named(Deeds.LAMP_DRUNK).size(), 1)

func test_a_lamp_drunk_earlier_this_life_gives_nothing_when_its_room_is_built_again() -> void:
	rules.handle_event(Deeds.LAMP_DRUNK, {"id": "T_l"})
	var lamp := _built({"kind": "lamp", "id": "T_l", "pos": Vector2(200, 320)})
	lamp.ledger = rules
	lamp.interact(_double())
	assert_eq(_named(Deeds.LAMP_DRUNK).size(), 0)

# --- vigil ---

func test_a_vigil_kept_ten_seconds_undamaged_is_a_deed_once() -> void:
	var vigil := _built({"kind": "vigil", "id": "T_v", "pos": Vector2(200, 320)})
	var p := _double()
	p.global_position = Vector2(210, 300)
	for i in 99:
		vigil.step(p, 0.1)
	assert_eq(_named(Deeds.VIGIL_KEPT).size(), 0, "9.9 s")
	vigil.step(p, 0.2)
	assert_eq(_named(Deeds.VIGIL_KEPT), [[Deeds.VIGIL_KEPT, {"id": "T_v"}]])
	for i in 200:
		vigil.step(p, 0.1)
	assert_eq(_named(Deeds.VIGIL_KEPT).size(), 1, "once per vigil")

func test_a_hit_or_walking_away_starts_the_vigil_again() -> void:
	var vigil := _built({"kind": "vigil", "id": "T_v", "pos": Vector2(200, 320)})
	var p := _double()
	p.global_position = Vector2(210, 300)
	for i in 80:
		vigil.step(p, 0.1)
	p.health.take_hit(1, "physical")
	for i in 80:
		vigil.step(p, 0.1)
	assert_eq(_named(Deeds.VIGIL_KEPT).size(), 0, "8 s, a hit, 8 s")
	p.global_position = Vector2(400, 300)
	vigil.step(p, 0.1)
	p.global_position = Vector2(210, 300)
	for i in 80:
		vigil.step(p, 0.1)
	assert_eq(_named(Deeds.VIGIL_KEPT).size(), 0, "walking away reset it")
	for i in 30:
		vigil.step(p, 0.1)
	assert_eq(_named(Deeds.VIGIL_KEPT).size(), 1)

# --- the registrations ---

func test_a_room_with_all_five_kinds_is_written_and_read_back_equal() -> void:
	var r := AreaKit.room("TF1", "forest", Vector2i(40, 40))
	AreaKit.feature(r, "barrier", "TF1_barrier", 44.0, 320.0, {"size": Vector2(24, 120)})
	AreaKit.feature(r, "hidden", "TF1_hidden", 600.0, 320.0, {"size": Vector2(24, 120)})
	AreaKit.feature(r, "gap", "TF1_gap", 300.0, 268.0, {"width": 50.0})
	AreaKit.feature(r, "lamp", "TF1_lamp", 200.0, 320.0)
	AreaKit.feature(r, "vigil", "TF1_vigil", 400.0, 320.0)
	var path := "user://deed_features_%d.tres" % Time.get_ticks_usec()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(AreaBuilder.serialize(r))
	f.close()
	var back: RoomDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_true(AreaBuilder.same(back, r))
	for feature in back.features:
		assert_not_null(RoomFeatures.make(feature, {}), str(feature["kind"]))

func test_the_validator_and_the_lint_know_every_kind() -> void:
	for k in ["barrier", "hidden", "gap", "lamp", "vigil"]:
		assert_true(WorldValidator.FEATURE_KINDS.has(k), k)
		assert_not_null(RoomFeatures.make({"kind": k, "id": "T_%s" % k, "pos": Vector2(100, 320), "size": Vector2(24, 60), "width": 40.0}, {}), k)
	assert_null(RoomFeatures.make({"kind": "nonsense", "id": "x", "pos": Vector2.ZERO}, {}))

func test_the_deeds_that_carry_an_id_may_name_it() -> void:
	for e in [Deeds.GAP_CROSSED, Deeds.LAMP_DRUNK, Deeds.VIGIL_KEPT]:
		assert_true((Deeds.TAGS[e] as Array).has("id"), e)
