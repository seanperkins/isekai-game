extends GutTest
## A bonded creature: it follows its owner, strikes the foes it meets, is hurt by the ones that touch it, and is lost for good at 0 HP.

class Owner extends Node2D:
	var team := "player"
	var lessons := Lessons.new()
	var deeds: Array = []
	func emit_deed(event_name: String, tags := {}) -> void:
		deeds.append([event_name, tags])
	func _physics_process(_delta: float) -> void:
		pass  # a real owner is a processing node; set_physics_process(false) is how a room change freezes it

class Foe extends Node2D:
	var team := "enemy"
	var hittable := true
	var hits: Array = []
	func receive_hit(raw: int, damage_type: String, _from: Vector2 = Vector2.INF, _cause: String = "") -> void:
		hits.append([raw, damage_type])
	func can_be_hit() -> bool:
		return hittable

var skills_by_id := {}
var creatures := {}

func before_all() -> void:
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c

func _owner(at := Vector2.ZERO) -> Owner:
	var o := Owner.new()
	o.position = at
	add_child_autofree(o)
	return o

func _def(hp := 5, atk := 2) -> CreatureDef:
	var d := TestDefs.creature("t_pal")
	d.stats = {"max_hp": hp, "atk": atk, "def": 0, "spd": 100}
	return d

func _companion(owner: Owner, def: CreatureDef, at := Vector2.ZERO) -> Companion:
	var c := Companion.new()
	add_child_autofree(c)
	c.launch(owner, def, at)
	return c

func _foe(at: Vector2) -> Foe:
	var f := Foe.new()
	f.position = at
	add_child_autofree(f)
	f.add_to_group("actors")
	return f

func _enemy(atk := 2, at := Vector2.ZERO) -> Enemy:
	var d := TestDefs.creature("t_foe")
	d.stats = {"max_hp": 9, "atk": atk, "def": 0, "spd": 100}
	var e := Enemy.new()
	e.setup(d, skills_by_id)
	e.position = at
	add_child_autofree(e)
	return e

# --- following ---

func test_it_follows_its_owner_and_stops_at_the_gap() -> void:
	var o := _owner(Vector2(200, 0))
	var c := _companion(o, _def(), Vector2.ZERO)
	c._physics_process(0.1)
	assert_gt(c.global_position.x, 0.0)
	for i in 100:
		c._physics_process(0.1)
	assert_almost_eq(c.global_position.distance_to(o.global_position), Companion.FOLLOW_GAP, 1.0)

func test_it_does_not_crowd_an_owner_it_is_already_beside() -> void:
	var o := _owner()
	var c := _companion(o, _def(), Vector2(10, 0))
	c._physics_process(0.1)
	assert_eq(c.global_position, Vector2(10, 0))

func test_it_snaps_to_an_owner_who_is_far_away() -> void:
	var o := _owner(Vector2(2000, 0))
	var c := _companion(o, _def(), Vector2.ZERO)
	c._physics_process(0.016)
	assert_lt(c.global_position.distance_to(o.global_position), Companion.TELEPORT_DISTANCE)
	assert_lte(c.global_position.distance_to(o.global_position), Companion.FOLLOW_GAP + 1.0)

func test_it_is_gone_when_its_owner_is() -> void:
	var o := _owner()
	var c := _companion(o, _def())
	o.free()
	await wait_physics_frames(2)
	assert_false(is_instance_valid(c))

# --- striking ---

func test_it_strikes_a_foe_in_reach_once_per_strike_time() -> void:
	var o := _owner()
	var c := _companion(o, _def(5, 3), Vector2(100, 0))
	var f := _foe(Vector2(100, 0))
	c._physics_process(0.016)
	assert_eq(f.hits, [[3, "physical"]])
	c._physics_process(0.016)
	assert_eq(f.hits.size(), 1, "it has to wait")
	c._physics_process(Companion.STRIKE_SECONDS)
	assert_eq(f.hits.size(), 2)

func test_it_closes_in_on_a_foe_before_it_strikes() -> void:
	var o := _owner(Vector2(100, 0))
	var c := _companion(o, _def(), Vector2(100, 0))
	var f := _foe(Vector2(100 + Companion.STRIKE_REACH.x * 3.0, 0))
	c._physics_process(0.016)
	assert_eq(f.hits.size(), 0, "too far to strike yet")
	for i in 20:
		c._physics_process(0.1)
	assert_gt(f.hits.size(), 0)

func test_it_goes_for_the_nearest_foe_in_chase_range() -> void:
	var o := _owner(Vector2(100, 0))
	var c := _companion(o, _def(), Vector2(100, 0))
	var near := _foe(Vector2(160, 0))
	var far := _foe(Vector2(100 + Companion.CHASE_RANGE + 50.0, 0))
	for i in 30:
		c._physics_process(0.1)
	assert_gt(near.hits.size(), 0)
	assert_eq(far.hits.size(), 0)

func test_it_ignores_its_own_team_and_foes_that_cannot_be_hit() -> void:
	var o := _owner()
	var c := _companion(o, _def(), Vector2(100, 0))
	var friend := _foe(Vector2(100, 0))
	friend.team = "player"
	var ghost := _foe(Vector2(100, 0))
	ghost.hittable = false
	c._physics_process(0.016)
	assert_eq(friend.hits.size(), 0)
	assert_eq(ghost.hits.size(), 0)

func test_it_does_not_go_for_a_terrain_switch_or_anything_that_is_not_an_enemy() -> void:
	var o := _owner()
	var c := _companion(o, _def(), Vector2(100, 0))
	var switch := _foe(Vector2(100, 0))
	switch.team = "terrain"
	c._physics_process(0.016)
	assert_eq(switch.hits.size(), 0)

func test_it_spares_a_stunned_creature_the_player_means_to_eat_or_bond() -> void:
	var o := _owner()
	var c := _companion(o, _def(), Vector2(100, 0))
	var e := _enemy(2, Vector2(100, 0))
	e.status.stun(10.0)
	var hp := e.health.hp
	c._physics_process(0.016)
	assert_eq(e.health.hp, hp)

func test_its_strike_grows_by_one_per_three_dealings_up_to_three() -> void:
	var o := _owner()
	var d := _def(5, 2)
	var c := _companion(o, d)
	assert_eq(c.atk(), 2)
	var pal := TestDefs.creature("t_pal", {"essences": {"earth": 1}})
	for i in 3:
		o.lessons.learn(pal)
	assert_eq(c.atk(), 3)
	for i in 3:
		o.lessons.learn(pal)
	assert_eq(c.atk(), 4)
	for i in 30:
		o.lessons.learn(pal)
	assert_eq(c.atk(), 5, "three is the most it can grow")

# --- being hurt ---

func test_an_active_enemy_in_contact_hurts_it_once_a_second() -> void:
	var o := _owner()
	var c := _companion(o, _def(10, 1), Vector2(50, 0))
	_enemy(3, Vector2(50, 0))
	c._physics_process(0.016)
	assert_eq(c.hp, 7)
	c._physics_process(0.016)
	assert_eq(c.hp, 7, "once a second")
	c._physics_process(Companion.HURT_SECONDS)
	assert_eq(c.hp, 4)

func test_a_rooted_enemy_does_not_hurt_it() -> void:
	var o := _owner()
	var c := _companion(o, _def(10, 1), Vector2(50, 0))
	var e := _enemy(3, Vector2(50, 0))
	e.root_for(5.0)
	assert_true(e.is_rooted())
	c._physics_process(0.016)
	assert_eq(c.hp, 10, "a rooted enemy's contact attack is off")

func test_it_does_nothing_while_its_owner_is_frozen() -> void:
	var o := _owner(Vector2(300, 0))
	var c := _companion(o, _def(10, 2), Vector2(50, 0))
	var foe := _foe(Vector2(50, 0))
	_enemy(3, Vector2(50, 0))
	o.set_physics_process(false)  # a room change freezes the player: nothing around it plays
	c._physics_process(Companion.HURT_SECONDS * 2.0)
	assert_eq(c.hp, 10)
	assert_eq(foe.hits.size(), 0)
	assert_eq(c.global_position, Vector2(50, 0))
	o.set_physics_process(true)
	c._physics_process(0.016)
	assert_lt(c.hp, 10, "and it carries on when the owner does")

func test_a_stunned_enemy_does_not_hurt_it() -> void:
	var o := _owner()
	var c := _companion(o, _def(10, 1), Vector2(50, 0))
	var e := _enemy(3, Vector2(50, 0))
	e.status.stun(10.0)
	c._physics_process(0.016)
	assert_eq(c.hp, 10)

func test_an_enemy_out_of_reach_does_not_hurt_it() -> void:
	var o := _owner()
	var c := _companion(o, _def(10, 1), Vector2(50, 0))
	_enemy(3, Vector2(50 + 60, 0))
	c._physics_process(0.016)
	assert_eq(c.hp, 10)

func test_at_zero_hp_it_says_it_died_once_and_is_gone() -> void:
	var o := _owner()
	var c := _companion(o, _def(2, 1), Vector2(50, 0))
	_enemy(5, Vector2(50, 0))
	watch_signals(c)
	c._physics_process(0.016)
	c._physics_process(Companion.HURT_SECONDS)
	assert_signal_emit_count(c, "died", 1)
	assert_true(c.is_queued_for_deletion())

# --- the long bond ---

func test_a_bond_that_lasts_says_so_once() -> void:
	var o := _owner()
	var c := _companion(o, _def())
	c._physics_process(Companion.LONG_BOND_SECONDS - 1.0)
	assert_eq(o.deeds, [])
	c._physics_process(2.0)
	assert_eq(o.deeds, [[Deeds.BOND_FORMED, {"kind": "long", "creature": "t_pal"}]])
	c._physics_process(Companion.LONG_BOND_SECONDS)
	assert_eq(o.deeds.size(), 1)

# --- how it looks ---

func test_a_twin_wears_its_forms_still() -> void:
	var c := _companion(_owner(), creatures["twin_wolf_fenrir"])
	var sprite: Sprite2D = c.get_node("Sprite")
	var want := SpriteSheet.load_set("forms_wolf").frame_texture("fenrir") as AtlasTexture
	assert_eq((sprite.texture as AtlasTexture).region, want.region)
	assert_eq(sprite.scale, Vector2.ONE * creatures["twin_wolf_fenrir"].sprite_size)

func test_it_is_drawn_in_its_tint() -> void:
	var d := _def()
	d.sprite_tint = Color(0.4, 0.5, 0.9)
	var c := _companion(_owner(), d)
	assert_eq((c.get_node("Sprite") as Sprite2D).modulate, Color(0.4, 0.5, 0.9))

func test_a_shipped_creature_shows_its_frame() -> void:
	var c := _companion(_owner(), creatures["bat"])
	assert_not_null((c.get_node("Sprite") as Sprite2D).texture)

func test_a_creature_with_no_art_still_shows_something() -> void:
	var c := _companion(_owner(), _def())
	assert_not_null((c.get_node("Sprite") as Sprite2D).texture)
