extends GutTest
## What the review of the verbs branch found, each pinned: a mount absorbs before a soul is spent, Copy can be recast, a summoned imp casts, a possessed body lives again
## in the world, turned creatures spare the packmate, a dry lamp gives nothing, a returning throw keeps its line, key items are not craft material, and so on.

var arena: VerbArena
var player: Player
var lizard: Enemy

func before_each() -> void:
	arena = VerbArena.new(self)
	arena.fresh()
	player = arena.player
	lizard = arena.lizard
	lizard.health.max_hp = 1000
	lizard.health.hp = 1000
	lizard.global_position = Vector2(900, 0)
	player._invuln = 1000.0
	await wait_physics_frames(3)
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for g in ["verb_souls", "minions", "glyphs", "loose", "verb_trails", "verb_networks"]:
		for n in get_tree().get_nodes_in_group(g):
			n.free()
	arena.clean()
	SkillRules.reset_run()
	Announcer.queue.clear()

func _verb(spec: Dictionary) -> VerbAbility:
	var a: VerbAbility = load("res://scenes/abilities/verb.tscn").instantiate()
	player.add_child(a)
	a.spec = spec
	a.setup(player, [4], 1)
	return a

func _enemy(id: String, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(VerbAlly._creature(id), VerbAlly.skill_defs())
	e.position = at
	add_child_autofree(e)
	return e

# --- a mount absorbs before a soul is spent ---

func test_a_mount_that_can_absorb_the_hit_leaves_the_soul_unspent() -> void:
	var pal := player.add_companion(VerbAlly._creature("gloom_wolf"), player.global_position, {"hp": 10})
	player.mount_with(pal, 10.0)
	_verb({"kind": "soul", "range": 240.0}).activate()
	player.health.hp = 2
	player._invuln = 0.0
	player.receive_hit(3, "physical", Vector2.INF)
	assert_eq(get_tree().get_nodes_in_group("verb_souls").size(), 1, "the anchor is still there")
	assert_eq(player.health.hp, 2, "the mount took it")
	assert_lt(pal.hp, 10)

# --- a chain does not hop to what has changed sides ---

func test_a_slow_chain_does_not_hit_a_creature_that_changed_sides_before_its_hop() -> void:
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	lizard.global_position = Vector2(900, 0)
	arena.foes[0].global_position = Vector2(50, 0)
	arena.foes[1].global_position = Vector2(100, 0)
	_verb({"kind": "chain", "range": 160.0, "jump": 80.0, "hops": 2, "hop_delay": 0.3}).activate()
	arena.foes[1].team = "player"  # it changed sides before the hop reached it
	await wait_seconds(0.5)
	assert_eq(arena.foes[1].hits.size(), 0)

# --- Copy can be recast, and the borrowed move runs to its end ---

func test_the_shipped_copy_can_be_recast_without_waiting_out_its_long_cooldown() -> void:
	player.last_inspected = VerbAlly._creature("twin_wolf_black_dog")
	var a := arena.verb("mimic")
	a.activate()
	assert_false(a.ready(), "not at once")
	await wait_seconds(0.9)
	assert_true(a.ready(), "but soon, well inside the copy")
	assert_true(player.is_copying())
	a.activate()
	assert_true(player.is_unseen(), "its move, borrowed")

func test_a_copied_returning_throw_still_returns() -> void:
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	lizard.global_position = Vector2(900, 0)
	arena.foes[0].global_position = Vector2(60, 0)
	player.last_inspected = VerbAlly._creature("twin_undead_skeletal_archer")
	var a := _verb({"kind": "copy", "seconds": 5.0})
	a.activate()
	a._cooldown = 0.0
	a.activate()
	await wait_seconds(0.7)
	assert_eq(arena.foes[0].hits.size(), 2, "out and back")

# --- a summoned imp casts ---

func test_an_imp_the_caller_summons_has_its_curse() -> void:
	var caller := _enemy("caller", Vector2(300, 0))
	caller.global_position = Vector2(300, 0)
	var glyph := RoomGlyph.new()
	glyph.setup({"id": "G", "pos": Vector2(300, 16)}, {})
	add_child_autofree(glyph)
	player.global_position = Vector2(150, 0)
	await wait_seconds(1.5)
	var imps := get_tree().get_nodes_in_group("minions").filter(func(n): return n.get_meta("minion_of", null) == caller)
	assert_gt(imps.size(), 0)
	assert_not_null(imps[0]._verb, "it can cast")

func test_dousing_the_glyph_while_the_caller_winds_up_stops_the_summon() -> void:
	var glyph := RoomGlyph.new()
	glyph.setup({"id": "G", "pos": Vector2(300, 16)}, {})
	add_child_autofree(glyph)
	var caller := _enemy("caller", Vector2(300, 0))
	player.global_position = Vector2(150, 0)
	await wait_physics_frames(8)
	assert_true(caller.telegraphing(), "winding up")
	glyph.douse()
	await wait_seconds(0.6)
	assert_eq(get_tree().get_nodes_in_group("minions").size(), 0, "the glyph went out first")

# --- a possessed body is alive in the world ---

func test_a_body_that_really_died_and_is_possessed_collides_again_and_only_when_near() -> void:
	var corpse := _enemy("skeleton", Vector2(150, 0))
	corpse.health.max_hp = 4
	corpse.health.hp = 4
	corpse.receive_hit(100, "physical", Vector2.INF)
	await wait_seconds(1.6)  # the death effect plays out and it lies downed
	assert_eq(corpse.status.state, EnemyStatus.DOWNED)
	assert_eq(corpse.collision_layer, 0, "a corpse blocks nothing")
	corpse.revive(0.5)
	assert_ne(corpse.collision_layer, 0, "a living body collides again")

func test_a_rider_does_not_possess_a_corpse_on_another_floor() -> void:
	var corpse := _enemy("skeleton", Vector2(0, -100))
	corpse.status.down()
	corpse.set_physics_process(false)  # it lies where it was put
	var rider := _enemy("rider", Vector2(0, 0))
	player.global_position = Vector2(-300, 0)
	await wait_seconds(0.5)
	assert_eq(corpse.status.state, EnemyStatus.DOWNED, "100 px above is out of reach")
	assert_true(is_instance_valid(rider))

# --- turned creatures spare the packmate ---

func test_a_turned_creature_does_not_hurt_the_players_packmate() -> void:
	var pal := player.add_companion(VerbAlly._creature("gloom_wolf"), Vector2(-200, 0), {"hp": 6})
	var wolf := _enemy("gloom_wolf", Vector2(-200, 0))
	wolf.turn_for(5.0)
	await wait_seconds(1.5)
	assert_eq(pal.hp, 6)

# --- a dry lamp gives nothing ---

func test_a_lamp_drunk_dry_gives_nothing_the_second_time() -> void:
	var lamp := RoomLamp.new()
	lamp.setup({"id": "L", "pos": Vector2(20, 16)}, {})
	add_child_autofree(lamp)
	var a := _verb({"kind": "drink", "range": 60.0, "hp": 6, "mp": 4})
	player.health.hp = 5
	a.activate()
	assert_gt(player.health.hp, 5)
	var hp := player.health.hp
	a._cooldown = 0.0
	assert_false(a.ready(), "nothing left to drink")
	a.activate()
	assert_eq(player.health.hp, hp)

# --- a returning throw keeps its line ---

func test_a_returning_throw_keeps_its_line_when_the_caster_turns_round() -> void:
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	lizard.global_position = Vector2(900, 0)
	arena.foes[0].global_position = Vector2(60, 0)
	arena.foes[1].global_position = Vector2(-60, 0)  # on the other side
	_verb({"kind": "bolt", "range": 100.0, "pierce": false, "returns": true}).activate()
	player.facing = -1  # it turned to face the other way
	await wait_seconds(0.6)
	assert_eq(arena.foes[0].hits.size(), 2, "the throw came back along its own line")
	assert_eq(arena.foes[1].hits.size(), 0, "and did not find what is behind")

# --- the network points to the trail's start ---

func test_the_network_shows_the_way_to_where_the_trail_began() -> void:
	player.global_position = Vector2(200, 0)
	_verb({"kind": "trail", "seconds": 10.0}).activate()
	player.global_position = Vector2(400, 0)
	_verb({"kind": "network", "radius": 100.0, "seconds": 5.0}).activate()
	var net: VerbNetwork = get_tree().get_nodes_in_group("verb_networks")[0]
	assert_eq(net.route_point(), Vector2(200, 0))

# --- key items are not craft material ---

func test_a_key_item_is_never_spent_as_craft_material() -> void:
	while player.parts_carried() > 0:
		player.inventory.take_carried()
	player.collect_part("moonstone")
	player.collect_part("ribs")
	var a := _verb({"kind": "spin"})
	assert_false(a.ready(), "a Moonstone and one rib are not two parts to spin")
	player.collect_part("ribs")
	assert_true(a.ready())
	a.activate()
	assert_true(player.inventory.carried_parts().has("moonstone"), "the Moonstone is still carried")
	var rig := _verb({"kind": "rig", "range": 100.0})
	rig.aim = Vector2(1, 0)
	var before := player.inventory.carried_parts().size()
	rig.activate()
	assert_true(player.inventory.carried_parts().has("moonstone"))
	assert_eq(player.inventory.carried_parts().size(), before - 1, "it spent a graft, not the key")

# --- holy light and the undead that are not a species ---

func test_holy_light_that_burns_only_the_living_spares_a_ghost() -> void:
	var ghost := _enemy("ghost", Vector2(30, -20))
	ghost.health.max_hp = 1000
	ghost.health.hp = 1000
	player.global_position = Vector2(0, 0)
	_verb({"kind": "zone", "radius": 80.0, "seconds": 2.0, "slow": false, "damage": true, "damage_type": "holy", "living_only": true}).activate()
	await wait_seconds(1.3)
	assert_eq(ghost.health.hp, 1000)

# --- the editor lets a weak floor have a width and span a hole ---

func test_the_editor_takes_a_weak_floor_with_a_width() -> void:
	var r := AreaKit.room("TW1", "forest", Vector2i(40, 40))
	AreaKit.feature(r, "weak_floor", "TW1_weak", 600.0, 320.0, {"width": 60.0})
	var spec := RoomSpec.to_json(r)
	var parsed := RoomSpec.content_from_json(JSON.parse_string(JSON.stringify(spec)))
	var model := RoomEditModel.new({"TW1": r}, [])
	var errors := model.apply_content("TW1", parsed["content"])
	assert_eq(errors, [], str(errors))

# --- the second pass of the review ---

func test_a_lamp_drunk_earlier_this_life_is_dry_in_a_room_built_again() -> void:
	var rules := SkillRulesEngine.new()
	rules.setup(DefLoader.load_dir("res://data/skills"))
	add_child_autofree(rules)
	rules.start_run()
	rules.handle_event(Deeds.LAMP_DRUNK, {"id": "L"})
	var lamp := RoomLamp.new()
	lamp.ledger = rules
	lamp.setup({"id": "L", "pos": Vector2(20, 16)}, {})
	add_child_autofree(lamp)
	assert_true(lamp.is_dry(), "the ledger says it was drunk: a new node knows it")
	var a := _verb({"kind": "drink", "range": 60.0, "hp": 6, "mp": 4})
	assert_false(a.ready())

## A rider, and a downed body `above` px over it; neither moves.
func _rider_and_a_corpse(above: float) -> Array:
	var rider := _enemy("rider", Vector2(-200, 0))
	var corpse := _enemy("skeleton", Vector2(-200, -above))
	corpse.status.down()
	for e in [rider, corpse]:
		e.set_physics_process(false)
	return [rider, corpse]

func test_a_rider_ignores_a_corpse_on_another_floor_and_goes_on_with_its_own_ai() -> void:
	var pair := _rider_and_a_corpse(100.0)
	assert_null(pair[0]._possess_target())
	assert_false(pair[0]._possess_act(0.0), "no body to walk to: its own ai goes on")

func test_a_returning_throw_comes_from_the_far_end_to_a_ward_bearer() -> void:
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	lizard.global_position = Vector2(900, 0)
	var bearer := _enemy("ward_bearer", Vector2(60, 0))
	bearer.facing = -1  # it faces the caster: the outbound throw is nullified
	bearer.health.max_hp = 1000
	bearer.health.hp = 1000
	_verb({"kind": "bolt", "range": 100.0, "pierce": false, "returns": true}).activate()
	assert_eq(bearer.health.hp, 1000, "out: from the front, nullified")
	await wait_seconds(0.6)
	assert_lt(bearer.health.hp, 1000, "back: it arrives from the far side, behind the bearer")

func test_a_weak_floor_cannot_be_placed_inside_rock() -> void:
	var r := AreaKit.room("TW2", "forest", Vector2i(40, 40))
	var model := RoomEditModel.new({"TW2": r}, [])
	assert_eq(model.add_feature("TW2", "weak_floor", Vector2(8, 320)), "stuck in rock or a wall", "in the wall it is refused")

func test_a_weak_floor_is_refused_when_its_full_width_reaches_into_the_wall() -> void:
	var r := AreaKit.room("TW3", "forest", Vector2i(40, 40))
	var model := RoomEditModel.new({"TW3": r}, [])
	assert_eq(model.add_feature("TW3", "weak_floor", Vector2(44, 320)), "stuck in rock or a wall", "its 60 px span reaches x = 14, into the 20 px wall")
	assert_eq(model.add_feature("TW3", "weak_floor", Vector2(120, 320)), "", "clear of the wall it is placed")

func test_a_rider_ignores_a_corpse_it_cannot_reach_along_the_floor() -> void:
	var pair := _rider_and_a_corpse(30.0)  # inside the old 40 px band, beyond its 22 px reach straight up
	assert_null(pair[0]._possess_target())
	assert_false(pair[0]._possess_act(0.0))

func test_a_rider_still_takes_a_corpse_a_few_pixels_off_the_floor() -> void:
	var pair := _rider_and_a_corpse(10.0)
	assert_eq(pair[0]._possess_target(), pair[1])

func test_a_spear_charge_counts_a_companion_as_a_mount_only_when_it_is_beside_the_rider() -> void:
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	lizard.global_position = Vector2(70, 0)
	lizard.health.hp = 1000
	var spec := {"kind": "dash", "hit_range": 90.0, "hit_half_width": 40.0, "ride": {"mounted": 3.0, "foot": 0.4}}
	var pal := player.add_companion(VerbAlly._creature("gloom_wolf"), Vector2(-400, 0), {})  # far away
	pal.global_position = Vector2(-400, 0)
	_verb(spec).activate()
	var far := 1000 - lizard.health.hp
	lizard.health.hp = 1000
	lizard._ward_t = 0.0
	pal.global_position = player.global_position + Vector2(-20, 0)  # beside it
	var a := _verb(spec)
	a.activate()
	assert_gt(1000 - lizard.health.hp, far * 3, "beside the rider it is a mount")
