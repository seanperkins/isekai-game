extends GutTest
## The support monsters' kits as the design agreed them: the imp holds its post and curses, the demon hound dashes after a wind-up, the caller emits imps while its glyph
## is lit, the blinker teleports and fakes, the ward-bearer nullifies hits from one side, the rider possesses a corpse, the priest spits holy light and carries the
## emitter, the shield guard is an armoured charger, the gargoyle drops from the ceiling, the ghost drifts.

class StubPlayer extends Node2D:
	var team := "player"
	var facing := 1
	var hits: Array = []
	var slowed := 0.0
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func slow_for(seconds: float) -> void:
		slowed += seconds

var creatures := {}
var skills_by_id := {}
var player: StubPlayer

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 16)
	add_child_autofree(ground)
	player = StubPlayer.new()
	add_child_autofree(player)
	player.add_to_group("player")
	player.add_to_group("actors")

func after_each() -> void:
	for g in ["glyphs", "minions"]:
		for n in get_tree().get_nodes_in_group(g):
			n.free()

func _enemy(id: String, at := Vector2.ZERO) -> Enemy:
	var e := Enemy.new()
	e.setup(creatures[id], skills_by_id)
	e.position = at
	add_child_autofree(e)
	return e

func test_the_imp_holds_its_post_and_curses_from_there() -> void:
	var imp := _enemy("imp", Vector2(0, 0))
	player.global_position = Vector2(100, 0)
	await wait_seconds(1.2)
	assert_lt(absf(imp.global_position.x), 4.0, "it holds its position")
	assert_gt(imp.verb_casts, 0)
	assert_gt(player.slowed, 0.0, "the curse slows")
	assert_eq(player.hits[0][1], "dark")

func test_the_demon_hound_dashes_after_a_wind_up() -> void:
	var hound := _enemy("demon_hound", Vector2(0, 0))
	assert_eq(hound.kind, Enemy.Kind.CHARGER)
	player.global_position = Vector2(100, 0)
	await wait_physics_frames(10)
	assert_eq(hound.charge_state(), "windup", "it winds up first")
	await wait_seconds(1.0)
	assert_gt(hound.global_position.x, 20.0, "then it dashes")

func test_the_caller_emits_imps_while_its_glyph_is_lit_and_stops_when_it_is_doused() -> void:
	var glyph := RoomGlyph.new()
	glyph.setup({"id": "G", "pos": Vector2(0, 16)}, {})
	add_child_autofree(glyph)
	var caller := _enemy("caller", Vector2(0, 0))
	player.global_position = Vector2(100, 0)
	await wait_seconds(1.5)
	var imps := get_tree().get_nodes_in_group("minions").filter(func(n): return n.get_meta("minion_of", null) == caller)
	assert_gt(imps.size(), 0, "it emits imps")
	assert_eq(imps[0].def.id, "imp")
	for m in get_tree().get_nodes_in_group("minions"):
		m.free()
	glyph.douse()
	await wait_seconds(2.0)
	assert_eq(get_tree().get_nodes_in_group("minions").size(), 0, "no glyph, no imps")

func test_a_caller_without_a_lit_glyph_emits_nothing() -> void:
	var caller := _enemy("caller", Vector2(0, 0))
	player.global_position = Vector2(100, 0)
	await wait_seconds(1.2)
	assert_eq(caller.verb_casts, 0)

func test_the_glyph_is_doused_by_standing_on_it_and_relights() -> void:
	var glyph := RoomGlyph.new()
	glyph.setup({"id": "G", "pos": Vector2(0, 16)}, {})
	add_child_autofree(glyph)
	assert_true(glyph.is_lit())
	player.global_position = Vector2(0, 0)
	await wait_seconds(2.0)
	assert_false(glyph.is_lit(), "put out by standing on it")
	player.global_position = Vector2(400, 0)
	await wait_seconds(RoomGlyph.RELIGHT_SECONDS + 0.5)
	assert_true(glyph.is_lit(), "and it relights")

func test_the_blinker_fakes_out_then_really_teleports() -> void:
	var blinker := _enemy("blinker", Vector2(0, 0))
	player.global_position = Vector2(140, 0)
	var x0 := blinker.global_position.x
	await wait_seconds(0.9)
	assert_gte(blinker.verb_casts, 1)
	assert_lt(absf(blinker.global_position.x - x0), 12.0, "the first is a fake-out: it stays")
	await wait_seconds(4.0)
	assert_gt(blinker.global_position.x, x0 + 40.0, "then it blinks toward you")

func test_the_ward_bearer_nullifies_hits_from_the_side_it_faces_only() -> void:
	var bearer := _enemy("ward_bearer", Vector2(0, 0))
	bearer.facing = 1
	var hp := bearer.health.hp
	bearer.receive_hit(5, "physical", Vector2(40, 0))  # from the front
	assert_eq(bearer.health.hp, hp, "nullified")
	bearer.receive_hit(5, "physical", Vector2(-40, 0))  # from behind
	assert_lt(bearer.health.hp, hp, "from behind it takes it")

func test_the_rider_possesses_a_corpse_and_the_corpse_stands_up() -> void:
	var corpse := _enemy("skeleton", Vector2(120, 0))
	corpse.health.hp = 0
	corpse.status.down()
	var rider := _enemy("rider", Vector2(0, 0))
	player.global_position = Vector2(-300, 0)
	await wait_seconds(3.0)
	assert_eq(corpse.status.state, EnemyStatus.ACTIVE, "the corpse stands")
	assert_gt(corpse.health.hp, 0)
	assert_true(not is_instance_valid(rider) or rider.is_queued_for_deletion(), "the rider went into it")

func test_the_priest_spits_holy_light_holds_its_post_and_carries_the_emitter() -> void:
	var priest := _enemy("chapel_priest", Vector2(0, 0))
	player.global_position = Vector2(110, 0)
	await wait_seconds(1.4)
	assert_gt(priest.verb_casts, 0)
	assert_eq(player.hits[0][1], "holy")
	assert_lt(absf(priest.global_position.x), 4.0)
	assert_true(priest.get_children().any(func(n): return n is PointLight2D or n.name.begins_with("Light")), "it carries a light")
	assert_true(creatures["chapel_priest"].drops.any(func(d): return d["part"] == "focus"), "and drops a focus")

func test_the_shield_guard_is_an_armoured_charger_that_drops_a_weapon_arm() -> void:
	var g := _enemy("shield_guard")
	assert_true(g.def.armored_charger)
	assert_eq(g.kind, Enemy.Kind.CHARGER)
	assert_true(g.def.drops.any(func(d): return d["part"] == "weapon_arm"))

func test_the_gargoyle_hangs_from_the_ceiling_and_drops_on_prey() -> void:
	var g := _enemy("gargoyle", Vector2(0, -60))
	assert_eq(g.kind, Enemy.Kind.DROPPER)
	assert_true(g._on_ceiling)
	player.global_position = Vector2(5, 0)
	await wait_seconds(1.0)
	assert_false(g._on_ceiling, "it dropped on its prey")

func test_the_ghost_is_a_drifter() -> void:
	assert_eq(_enemy("ghost", Vector2(0, -30)).kind, Enemy.Kind.DRIFTER)
