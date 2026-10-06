extends GutTest
## The world verbs that are a key on a kind already there: a whirlpool that pulls loose parts, a dissolve that corrodes, a glide that carries and needs a kill, a
## permanent bridge that needs anchors, a flame trail that burns the pack, a venom web that spreads, a miasma that spreads on death.

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

func after_each() -> void:
	for g in ["verb_bridges", "verb_fields", "player_webs", "player_clouds"]:
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

func _ground(x0: float, x1: float) -> StaticBody2D:
	var g := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, 20)
	shape.shape = rect
	g.add_child(shape)
	g.position = Vector2((x0 + x1) / 2.0, 26)
	add_child_autofree(g)
	return g

class Dissolvable extends Node2D:
	var dissolved := 0
	func dissolve() -> void:
		dissolved += 1

# --- a whirlpool pulls loose parts too ---

func test_a_whirlpool_draws_loose_parts_toward_its_centre() -> void:
	var pickup := PartPickup.new()
	pickup.setup(load("res://data/parts/claw.tres"), Vector2(60, 0))
	add_child_autofree(pickup)
	pickup.delay = 100.0  # it lies there: it cannot be collected, only moved
	player.global_position = Vector2(0, 0)
	_verb({"kind": "pull", "radius": 120.0, "seconds": 2.0, "strength": 90.0, "ahead": 0.0, "pickups": true}).activate()
	var d0 := pickup.global_position.distance_to(Vector2.ZERO)
	await wait_seconds(0.6)
	assert_lt(pickup.global_position.distance_to(Vector2.ZERO), d0, "the loose part was drawn in")

# --- a dissolve that corrodes ---

func test_a_dissolve_that_eats_something_corrodes_a_carried_part() -> void:
	var gate := Dissolvable.new()
	add_child_autofree(gate)
	gate.add_to_group("dissolvable")
	gate.global_position = Vector2(30, 0)
	var carried := player.parts_carried()
	_verb({"kind": "dissolve", "range": 60.0, "half_width": 40.0, "corrode": 1}).activate()
	assert_eq(gate.dissolved, 1)
	assert_eq(player.parts_carried(), carried - 1, "your own parts corrode")

func test_a_dissolve_that_eats_nothing_corrodes_nothing() -> void:
	var carried := player.parts_carried()
	lizard.global_position = Vector2(900, 0)
	for f in arena.foes:
		f.global_position = Vector2(900, 0)
	_verb({"kind": "dissolve", "range": 10.0, "half_width": 10.0, "corrode": 1}).activate()
	assert_eq(player.parts_carried(), carried)

# --- a glide that carries ---

func test_a_glide_with_a_drift_carries_the_body_sideways() -> void:
	player.global_position = Vector2(0, -100)
	_verb({"kind": "glide", "seconds": 1.0, "fall": 30.0, "drift": 100.0}).activate()
	var x0 := player.global_position.x
	await wait_seconds(0.5)
	assert_gt(player.global_position.x, x0 + 30.0, "the cloud carried it")

func test_a_glide_that_needs_a_kill_is_not_ready_without_one() -> void:
	var a := _verb({"kind": "glide", "seconds": 1.0, "needs_kill": 8.0})
	assert_false(a.ready(), "glide only after a kill")
	player.note_defeat(lizard)
	assert_true(a.ready())

# --- a bridge that stays and needs anchors ---

func test_a_permanent_bridge_needs_both_ends_anchored() -> void:
	_ground(-300, 100)
	player.global_position = Vector2(60, 0)
	await wait_physics_frames(3)
	var spec := {"kind": "bridge", "length": 200.0, "permanent": true, "anchors": true}
	_verb(spec).activate()
	assert_eq(get_tree().get_nodes_in_group("verb_bridges").size(), 0, "no ground on the far side: nothing anchors it")
	_ground(250, 700)
	await wait_physics_frames(2)
	_verb(dict_merge(spec, {"cooldown": 0.0})).activate()
	assert_eq(get_tree().get_nodes_in_group("verb_bridges").size(), 1, "anchored at both ends")
	await wait_seconds(0.5)
	assert_eq(get_tree().get_nodes_in_group("verb_bridges").size(), 1, "and it stays")

func dict_merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out

# --- a flame trail that burns the pack ---

func test_a_flame_trail_burns_the_enemies_in_it_and_the_packmate_too() -> void:
	_ground(-300, 700)
	var pal := player.add_companion(VerbAlly._creature("gloom_wolf"), Vector2(40, 0), {"hp": 6})
	player.global_position = Vector2(0, 0)
	lizard.global_position = Vector2(48, 0)
	lizard.health.hp = 1000
	_verb({"kind": "dash", "speed": 0.0, "hit_range": 10.0, "damage_type": "fire", "trail": {"seconds": 3.0, "count": 3, "gap": 24.0}}).activate()
	pal.global_position = Vector2(24, 0)
	await wait_seconds(1.3)
	assert_lt(lizard.health.hp, 1000, "the flames burn the enemy")
	assert_true(not is_instance_valid(pal) or pal.hp < 6, "and fire hurts your own packmate")

# --- a venom web that spreads through the webs ---

func test_a_venom_web_poisons_the_other_webs_near_it() -> void:
	_verb({"kind": "zone", "radius": 40.0, "seconds": 20.0, "slow": true, "web": true}).activate()
	var plain: SporeCloudArea = get_tree().get_nodes_in_group("player_webs")[0]
	assert_eq(plain.damage, 0, "a plain web only slows")
	player.global_position = Vector2(100, 0)
	_verb({"kind": "zone", "radius": 40.0, "seconds": 20.0, "slow": true, "web": true, "damage": true, "damage_type": "poison", "spreads": true, "cooldown": 0.0}).activate()
	assert_gt(plain.damage, 0, "the poison spread to the first web")
	assert_eq(plain.damage_type, "poison")

# --- a miasma that spreads when you die ---

func test_a_body_with_a_miasma_leaves_a_cloud_when_it_dies() -> void:
	player.skillset.capabilities["trait_miasma_death"] = 1
	player._invuln = 0.0
	player.global_position = Vector2(-100, 0)
	var before := get_tree().get_nodes_in_group("player_clouds").size()
	player.receive_hit(999, "physical", Vector2.INF)
	assert_true(player.health.is_dead())
	assert_gt(get_tree().get_nodes_in_group("player_clouds").size(), before, "a cloud where it fell")

func test_the_new_keys_validate() -> void:
	for spec in [{"kind": "pull", "pickups": true}, {"kind": "dissolve", "corrode": 1}, {"kind": "glide", "drift": 80, "needs_kill": 8}, {"kind": "bridge", "permanent": true, "anchors": true},
			{"kind": "dash", "trail": {"seconds": 3, "count": 3, "gap": 20}}, {"kind": "zone", "web": true, "spreads": true}]:
		assert_eq(Array(VerbKinds.validate(spec)), [], str(spec))
