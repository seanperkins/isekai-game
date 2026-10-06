extends GutTest
## The rest of the packs' mechanics: a horn that rallies, holy light that heals allies and burns only the living, a curse on everything in the room, a hidden soul
## that cheats a death once, a blink away from what is in front, a phylactery that keeps the remains.

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
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 20)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(0, 26)
	add_child_autofree(ground)

func after_each() -> void:
	for n in get_tree().get_nodes_in_group("verb_allies"):
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

func _creature(id: String) -> CreatureDef:
	return DefLoader.load_dir("res://data/creatures").filter(func(d): return d.id == id)[0]

# --- a horn rallies ---

func test_a_horn_makes_the_allies_strike_faster_and_harder() -> void:
	player.global_position = Vector2(-300, 0)
	lizard.global_position = Vector2(-270, 0)
	_verb({"kind": "summon", "count": 1, "seconds": 20.0}).activate()
	var ally: VerbAlly = get_tree().get_nodes_in_group("verb_allies")[0]
	ally.global_position = lizard.global_position + Vector2(-8, 0)
	await wait_seconds(1.7)
	var plain := 1000 - lizard.health.hp
	lizard.health.hp = 1000
	_verb({"kind": "burst", "range": 10.0, "rally": {"seconds": 5.0, "power": 3}, "cooldown": 0.0}).activate()
	await wait_seconds(1.7)
	assert_gte(1000 - lizard.health.hp, plain * 2, "rallied: faster and harder (%d against %d)" % [1000 - lizard.health.hp, plain])

func test_a_horn_rallies_the_packmate_too() -> void:
	var pal := player.add_companion(_creature("gloom_wolf"), player.global_position, {})
	_verb({"kind": "burst", "range": 10.0, "rally": {"seconds": 5.0, "power": 3}}).activate()
	assert_gt(pal._rally_t, 0.0)

# --- holy light ---

func test_a_ring_of_light_heals_the_summons_and_burns_only_the_living() -> void:
	player.global_position = Vector2(-300, 0)
	var skeleton := Enemy.new()
	skeleton.setup(_creature("skeleton"), {})
	skeleton.position = Vector2(-280, 0)
	add_child_autofree(skeleton)
	skeleton.health.max_hp = 1000
	skeleton.health.hp = 1000
	lizard.global_position = Vector2(-320, 0)
	_verb({"kind": "summon", "count": 1, "seconds": 20.0, "mortal": true, "hp": 4}).activate()
	var ally: VerbAlly = get_tree().get_nodes_in_group("verb_allies")[0]
	ally.hp = 1
	ally._strike_in = 100.0  # it does not fight: only the light is tested
	ally.global_position = Vector2(-300, 0)
	player.health.hp = 10
	_verb({"kind": "zone", "radius": 80.0, "seconds": 2.0, "slow": false, "heals": 2, "damage": true, "damage_type": "holy", "living_only": true, "ally_heals": true}).activate()
	await wait_seconds(1.3)
	assert_lt(lizard.health.hp, 1000, "the living burn")
	assert_eq(skeleton.health.hp, 1000, "the undead do not")
	assert_gt(ally.hp, 1, "the summon is mended")
	assert_gt(player.health.hp, 10, "and so is the caster")

func test_a_body_with_no_drain_and_weak_dark_powers_does_neither() -> void:
	player.skillset.capabilities["trait_no_drain"] = 1
	player.skillset.capabilities["trait_dark_weak"] = 1
	player.health.hp = 5
	_verb({"kind": "burst", "range": 80.0, "half_width": 40.0, "damage_type": "dark", "drain": 1.0}).activate()
	assert_eq(player.health.hp, 5, "you absolve, you do not drain")
	player.skillset.capabilities.erase("trait_dark_weak")
	var strong := 1000 - lizard.health.hp
	lizard.health.hp = 1000
	player.skillset.capabilities["trait_dark_weak"] = 1
	_verb({"kind": "burst", "range": 80.0, "half_width": 40.0, "damage_type": "dark", "cooldown": 0.0}).activate()
	assert_lt(1000 - lizard.health.hp, strong + 1, "dark hits no harder when weak")

# --- a decree ---

func test_a_decree_curses_everything_in_the_room_and_the_curse_wears_off() -> void:
	var far := Enemy.new()
	far.setup(lizard.def, {})
	far.position = Vector2(700, 0)
	add_child_autofree(far)
	_verb({"kind": "ring", "radius": 10.0, "curse": {"seconds": 0.5, "mult": 2.0, "range": 900.0}}).activate()
	assert_true(far.is_cursed(), "even what is far off")
	assert_true(lizard.is_cursed())
	var hp := lizard.health.hp
	lizard.receive_hit(10, "physical")
	var cursed := hp - lizard.health.hp
	await wait_seconds(0.8)
	assert_false(lizard.is_cursed())
	lizard._hurt_t = 0.0
	hp = lizard.health.hp
	lizard.receive_hit(10, "physical")
	assert_gt(cursed, hp - lizard.health.hp, "the curse made it harder")

# --- a hidden soul ---

func test_a_death_within_reach_of_the_anchor_is_cheated_once_per_life() -> void:
	player.global_position = Vector2(-300, 0)
	_verb({"kind": "soul", "range": 240.0, "hp": 6}).activate()
	assert_eq(get_tree().get_nodes_in_group("verb_souls").size(), 1)
	player.global_position = Vector2(-200, 0)
	player._invuln = 0.0
	player.receive_hit(999, "physical", Vector2.INF)
	assert_false(player.health.is_dead(), "it rose")
	assert_eq(player.health.hp, player.health.max_hp)
	assert_lt(absf(player.global_position.x - (-300.0)), 3.0, "at the anchor")
	assert_eq(get_tree().get_nodes_in_group("verb_souls").size(), 0, "the anchor is spent")
	_verb({"kind": "soul", "range": 240.0, "hp": 6, "cooldown": 0.0}).activate()
	player._invuln = 0.0
	player.receive_hit(999, "physical", Vector2.INF)
	assert_true(player.health.is_dead(), "once per life: the second time it does not")

func test_a_death_out_of_reach_is_not_cheated() -> void:
	player.global_position = Vector2(-300, 0)
	_verb({"kind": "soul", "range": 100.0}).activate()
	player.global_position = Vector2(200, 0)
	player._invuln = 0.0
	player.receive_hit(999, "physical", Vector2.INF)
	assert_true(player.health.is_dead())

func test_an_enemy_that_stays_at_the_anchor_destroys_it() -> void:
	player.global_position = Vector2(-300, 0)
	_verb({"kind": "soul", "range": 240.0, "hp": 1}).activate()
	lizard.global_position = Vector2(-300, 0)
	await wait_seconds(0.5)
	assert_eq(get_tree().get_nodes_in_group("verb_souls").size(), 0, "the anchor can be destroyed")

# --- a blink away ---

func test_a_blink_away_steps_back_from_what_is_in_front() -> void:
	player.global_position = Vector2(0, 0)
	lizard.global_position = Vector2(900, 0)
	_verb({"kind": "burst", "range": 10.0, "blink": {"distance": 70.0, "away": true}}).activate()
	assert_almost_eq(player.global_position.x, -70.0, 1.0)

# --- remains that a phylactery keeps ---

func test_remains_with_a_phylactery_shard_do_not_wear_away() -> void:
	var w := WorldProgress.new()
	w.leave_remains("C1", Vector2(10, 10), ["claw"])
	for i in 3:
		w.note_death_unrecovered()
	assert_true(w.remains.is_empty(), "ordinary remains go after three deaths")
	w.leave_remains("C1", Vector2(10, 10), ["claw", "phylactery_shard"])
	for i in 5:
		w.note_death_unrecovered()
	assert_false(w.remains.is_empty(), "a phylactery anchors them")

func test_the_new_keys_validate() -> void:
	for spec in [{"kind": "soul", "range": 200, "hp": 4}, {"kind": "burst", "rally": {"seconds": 5, "power": 2}}, {"kind": "ring", "curse": {"seconds": 8, "mult": 1.5, "range": 900}},
			{"kind": "chain", "blink": {"distance": 60, "away": true}}, {"kind": "summon", "focus": {"part": "focus", "count": 1, "power_mult": 1.3}},
			{"kind": "zone", "living_only": true, "ally_heals": true}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
