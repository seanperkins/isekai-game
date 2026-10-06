extends GutTest
## Projectile variants: a throw that returns, a count with a cursed seventh, a shot paid for in HP, arrows that home on one mark, three barks and a lunge,
## a verb that alternates, a shot dyed with blood, rubble thrown from the room.

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
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("loose"):
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

func _hits() -> int:
	var n := 0
	for f in arena.foes:
		n += f.hits.size()
	return n

# --- a throw that returns ---

func test_a_returning_throw_hits_again_on_the_way_back() -> void:
	_verb({"kind": "bolt", "range": 100.0, "pierce": false, "returns": true}).activate()
	assert_eq(arena.foes[0].hits.size(), 1)
	await wait_seconds(0.6)
	assert_eq(arena.foes[0].hits.size(), 2, "it came back through the same foe")

func test_a_throw_that_does_not_return_hits_once() -> void:
	_verb({"kind": "bolt", "range": 100.0, "pierce": false}).activate()
	await wait_seconds(0.6)
	assert_eq(arena.foes[0].hits.size(), 1)

func test_a_bow_arm_stretches_the_reach() -> void:
	arena.foes[2].global_position = Vector2(200, 0)  # 200 away: beyond a range of 160
	arena.foes[0].global_position = Vector2(900, 0)
	arena.foes[1].global_position = Vector2(900, 0)
	arena.lizard.global_position = Vector2(900, 0)
	var spec := {"kind": "bolt", "range": 160.0, "pierce": false, "reach_with": {"part": "bow_arm", "mult": 1.5}}
	_verb(spec).activate()
	assert_eq(arena.foes[2].hits.size(), 0, "out of reach")
	player.collect_part("bow_arm")
	var a := _verb(spec)
	a.activate()
	assert_eq(arena.foes[2].hits.size(), 1, "with the arm, in reach")

# --- six sure shots and a cursed seventh ---

func test_the_seventh_shot_is_cursed_hits_harder_and_costs_hp() -> void:
	var a := _verb({"kind": "bolt", "range": 100.0, "pierce": false, "cursed": {"every": 7, "mult": 3.0, "hp": 4}})
	player.health.hp = 20
	var sixth := 0
	for i in 6:
		a._cooldown = 0.0
		arena.foes[0].hits.clear()
		a.activate()
		sixth = int(arena.foes[0].hits[0][0])
	assert_eq(player.health.hp, 20, "six sure shots cost nothing")
	a._cooldown = 0.0
	arena.foes[0].hits.clear()
	a.activate()
	assert_gte(int(arena.foes[0].hits[0][0]), sixth * 3, "the seventh is cursed")
	assert_eq(player.health.hp, 16, "and costs HP")
	a._cooldown = 0.0
	arena.foes[0].hits.clear()
	a.activate()
	assert_eq(player.health.hp, 16, "then the count begins again")

# --- a life-arrow ---

func test_a_life_arrow_spends_all_but_one_hp_and_hits_for_what_was_spent() -> void:
	var spec := {"kind": "bolt", "range": 400.0, "pierce": true, "spend_hp": true, "hp_scale": 2.0}
	player.health.hp = 11
	_verb(spec).activate()
	assert_eq(player.health.hp, 1, "leaves you at 1 HP")
	var big := int(arena.foes[0].hits[0][0])
	assert_gte(big, 20, "ten HP at two each")
	var a := _verb(spec)
	assert_false(a.ready(), "at 1 HP there is nothing to spend")

# --- arrows that home ---

func test_the_first_cast_marks_one_prey_and_the_next_arrows_home_on_it_from_afar() -> void:
	lizard.global_position = Vector2(200, 0)
	var a := _verb({"kind": "hunt", "range": 260.0})
	a.activate()
	assert_true(lizard.has_meta("verb_hunted"), "marked")
	assert_eq(lizard.health.hp, 1000)
	lizard.global_position = Vector2(500, 0)  # it ran off, beyond the mark's own reach
	a._cooldown = 0.0
	player.facing = -1
	a.activate()
	assert_lt(lizard.health.hp, 1000, "the arrow found it, from farther than the mark reaches, and not in the way it faced")

func test_a_new_mark_takes_the_place_of_the_old_one() -> void:
	var other := Enemy.new()
	other.setup(lizard.def, {})
	other.position = Vector2(90, 40)
	add_child_autofree(other)
	lizard.global_position = Vector2(30, 0)
	var a := _verb({"kind": "hunt", "range": 260.0})
	a.activate()
	assert_true(lizard.has_meta("verb_hunted"))
	lizard.global_position = Vector2(900, 0)
	a._cooldown = 0.0
	a.activate()
	assert_false(lizard.has_meta("verb_hunted"), "one mark at a time")
	assert_true(other.has_meta("verb_hunted"), "the new prey")

# --- three barks ---

func test_two_barks_warn_and_the_third_is_a_lunge_that_cannot_be_dodged() -> void:
	lizard.global_position = Vector2(200, 0)
	var a := _verb({"kind": "bark", "range": 240.0, "still": 0.2, "lunge": 3.0})
	a.activate()
	assert_true(player.is_held_still(), "stand still to bark")
	assert_eq(lizard.health.hp, 1000)
	assert_true(lizard.is_alert(), "a warning")
	a._cooldown = 0.0
	a.activate()
	assert_eq(lizard.health.hp, 1000, "two warnings, no blow")
	a._cooldown = 0.0
	a.activate()
	assert_lt(lizard.health.hp, 1000, "then the lunge lands, from range")
	assert_lt(player.global_position.distance_to(lizard.global_position), 60.0, "beside it")

func test_the_count_of_barks_begins_again_after_the_lunge() -> void:
	lizard.global_position = Vector2(200, 0)
	var a := _verb({"kind": "bark", "range": 240.0, "lunge": 3.0})
	for i in 3:
		a._cooldown = 0.0
		a.activate()
	player.global_position = Vector2.ZERO
	lizard.health.hp = 1000
	a._cooldown = 0.0
	a.activate()
	assert_eq(lizard.health.hp, 1000, "the first bark again is only a bark")

# --- a verb that alternates ---

func test_a_verb_that_alternates_uses_its_other_form_every_second_cast() -> void:
	var a := _verb({"kind": "bolt", "range": 100.0, "pierce": false, "alt": {"range": 20.0}})
	a.activate()
	assert_eq(arena.foes[0].hits.size(), 1, "the first reaches 100")
	a._cooldown = 0.0
	a.activate()
	assert_eq(arena.foes[0].hits.size(), 1, "the second reaches only 20: it missed")
	a._cooldown = 0.0
	a.activate()
	assert_eq(arena.foes[0].hits.size(), 2, "the third is the first again")

# --- a shot dyed with blood ---

func test_a_dyed_shot_spends_a_blood_essence_and_is_not_ready_without_one() -> void:
	var spec := {"kind": "bolt", "range": 100.0, "pierce": false, "spend_essence": {"blood": 1}}
	var a := _verb(spec)
	assert_false(a.ready(), "needs blood to dye it")
	arena.rules.handle_event(Events.ABSORBED, {"essence": "blood", "source": "test"})
	assert_true(a.ready())
	a.activate()
	assert_eq(arena.rules.held("blood"), 0, "spent")
	assert_eq(arena.foes[0].hits.size(), 1)

# --- rubble ---

func test_a_thrown_rubble_needs_loose_objects_and_uses_one_up() -> void:
	var spec := {"kind": "bolt", "range": 200.0, "pierce": false, "loose": true}
	var a := _verb(spec)
	assert_false(a.ready(), "needs loose objects")
	var rock := Rubble.new()
	add_child_autofree(rock)
	rock.global_position = Vector2(20, 0)
	assert_true(a.ready())
	a.activate()
	assert_eq(arena.foes[0].hits.size(), 1)
	assert_eq(get_tree().get_nodes_in_group("loose").size(), 0, "the rock is spent")

func test_a_broken_barrier_leaves_rubble() -> void:
	var barrier := RoomBarrier.new()
	barrier.setup({"id": "b", "pos": Vector2(0, 100), "w": 24.0, "h": 60.0}, {})
	add_child_autofree(barrier)
	await wait_physics_frames(2)
	barrier.dissolve()
	await wait_physics_frames(2)
	assert_gt(get_tree().get_nodes_in_group("loose").size(), 0, "rubble where the wall was")

func test_the_new_keys_validate() -> void:
	for spec in [{"kind": "bolt", "returns": true, "cursed": {"every": 7, "mult": 3, "hp": 4}, "spend_hp": true, "hp_scale": 1.5, "loose": true,
			"reach_with": {"part": "bow_arm", "mult": 1.5}, "spend_essence": {"blood": 1}}, {"kind": "hunt", "range": 200}, {"kind": "bark", "range": 200, "lunge": 3, "still": 0.5},
			{"kind": "bolt", "alt": {"range": 20}}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
