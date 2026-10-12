extends GutTest
## Who draws held items: a twin that wears an animated goblin form and the village goblin (on the base goblin's sheet) get a held-item layer; the player gets one on an
## evolution and keeps what it was given across it; the eating cover's copy keeps the items, and the other copies of a picture (a blade kill's halves, Swap's husk,
## Mislead's decoy) leave them out. A creature that draws an armed still has none.

var _skills := {}
var _creatures := []
var _saved_clips_path := ""
var rules: SkillRulesEngine
var player: Player

func before_all() -> void:
	for d in DefLoader.load_dir("res://data/skills"):
		_skills[d.id] = d
	_creatures = DefLoader.load_dir("res://data/creatures")

func before_each() -> void:
	_saved_clips_path = Enemy.form_clips_path

func after_each() -> void:
	Enemy.form_clips_path = _saved_clips_path
	for a in ["move_right", "move_left", "jump"]:
		Input.action_release(a)
	SkillRules.reset_run()
	Announcer.queue.clear()

func _def(id: String) -> CreatureDef:
	for d in _creatures:
		if d.id == id:
			return d
	return null

func _twin(form: String) -> CreatureDef:
	for d in _creatures:
		if d.form == form and d.origin == "twin":
			return d
	return null

func _enemy(def: CreatureDef, use_sheet := true) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = use_sheet
	e.setup(def, _skills)
	add_child_autofree(e)
	e._update_visual(0.0)
	return e

func _sprite(e: Node) -> Sprite2D:
	return e.get_node("Sprite")

func _layer(e: Node) -> HeldItemLayer:
	return _sprite(e).get_node_or_null("HeldItemLayer") as HeldItemLayer

func test_a_twin_with_its_animated_form_gets_a_layer_bound_to_its_form_and_shows_the_items() -> void:
	var e := _enemy(_twin("goblin_smith"))
	var layer := _layer(e)
	assert_not_null(layer)
	assert_eq(layer.item("primary"), "hammer")
	assert_eq(layer.item("secondary"), "tongs")
	assert_true(_sprite(e).get_node("HeldItemN").visible, "drawn on the first frame")
	assert_true(_sprite(e).get_node("HeldItemF").visible)

func test_the_village_goblin_on_the_still_path_gets_a_layer_bound_to_goblin_and_a_swapped_in_axe_follows_its_frame() -> void:
	var e := _enemy(_def("village_goblin"))
	e.facing = 1
	var layer := _layer(e)
	assert_not_null(layer, "the base goblin's sheet is empty-handed, so it takes a layer")
	assert_eq(layer.item("primary"), "", "the base goblin holds nothing")
	assert_false(_sprite(e).get_node("HeldItemN").visible)
	assert_true(layer.set_item("primary", "axe"))
	e._update_visual(0.0)
	var frame := e._still_frame()
	var hand: Dictionary = e._still.hands(frame)["n"]
	assert_true(_sprite(e).get_node("HeldItemN").visible)
	assert_eq(_sprite(e).get_node("HeldItemN").position, Vector2(float(hand["x"]), float(hand["y"]) + e._still.frame_size(frame).y / 2.0))
	e.facing = -1
	e._update_visual(0.0)
	assert_almost_eq(_sprite(e).get_node("HeldItemN").position.x, -float(hand["x"]), 0.001, "it turns with the creature")
	var plain := (_sprite(e).get_node("HeldItemN").get_child(0) as Sprite2D).texture
	assert_false(plain is CanvasTexture, "the still path draws its body plain, so the item is plain too")

func test_a_downed_village_goblins_axe_is_flipped_with_its_body() -> void:
	var e := _enemy(_def("village_goblin"))
	e.facing = 1
	_layer(e).set_item("primary", "axe")
	e._update_visual(0.0)
	var up := _sprite(e).get_node("HeldItemN") as Node2D
	var up_y := up.position.y
	e.status.state = EnemyStatus.DOWNED
	e._update_visual(0.0)
	assert_true(_sprite(e).flip_v)
	assert_almost_eq(up.position.y, -up_y, 0.001)
	assert_lt(up.scale.y, 0.0)

func test_a_twin_that_draws_an_armed_still_has_no_layer() -> void:
	assert_null(_layer(_enemy(_twin("goblin_smith"), false)), "use_sheet false: the AI-drawn still, weapon and all")
	Enemy.form_clips_path = "res://data/no_such_form_clips.json"
	assert_null(_layer(_enemy(_twin("goblin_smith"))), "the animated sheet will not load: the armed still stands in")

func _spawn_player() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.species = "goblin"
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0.0, BodyConfig.BOTTOM + 10.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000.0, 20.0)
	shape.shape = rect
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	await wait_physics_frames(6)

func _evolve(id: String) -> void:
	assert_true(player.advance_form(id, true), id)
	await wait_seconds(Player.EVOLVE_SECONDS + 0.3)
	await wait_physics_frames(3)

func test_the_player_evolving_into_the_smith_gets_the_hammer_and_tongs_keeps_an_override_across_it_and_a_new_run_clears_it() -> void:
	await _spawn_player()
	assert_eq(_layer(player).item("primary"), "", "the base goblin holds nothing")
	await _evolve("goblin_tinker")
	await _evolve("goblin_smith")
	assert_eq(_layer(player).item("primary"), "hammer")
	assert_eq(_layer(player).item("secondary"), "tongs")
	assert_true(_sprite(player).get_node("HeldItemN").visible)
	_layer(player).set_item("primary", "axe")
	await _evolve("goblin_mastersmith")
	assert_eq(_layer(player).item("primary"), "axe", "a held item survives an evolution")
	assert_eq(_layer(player).item("secondary"), HeldItems.form("goblin_mastersmith")["secondary"])
	rules.start_run()
	await wait_physics_frames(3)
	assert_eq(_layer(player).item("primary"), "", "a new run clears what was swapped in and goes back to the base goblin")
	assert_eq(_layer(player).item("secondary"), "")

func test_a_form_that_draws_its_armed_still_shows_no_items_and_an_override_survives_it() -> void:
	await _spawn_player()
	await _evolve("goblin_tinker")
	await _evolve("goblin_smith")
	_layer(player).set_item("primary", "axe")
	var still_form := FormDef.new()
	still_form.id = "goblin_nonesuch"
	still_form.species = "goblin"
	player._use_form_sheet(still_form)
	await wait_physics_frames(3)
	assert_false(_sprite(player).get_node("HeldItemN").visible)
	assert_false(_sprite(player).get_node("HeldItemF").visible)
	await _evolve("goblin_mastersmith")
	assert_eq(_layer(player).item("primary"), "axe", "the override outlived the form with only a picture")
	assert_true(_sprite(player).get_node("HeldItemN").visible)

func test_a_player_that_is_not_a_goblin_has_no_layer() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.species = "wolf"
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	await wait_physics_frames(3)
	assert_null(_layer(player))

func test_the_eating_covers_copy_of_the_prey_keeps_the_items() -> void:
	var prey := _enemy(_twin("goblin_smith"))
	var cover := EatCover.new()
	add_child_autofree(cover)
	cover.begin(prey, SpriteSheet.load_set("slime"))
	assert_false(_sprite(prey).visible, "the prey's own sprite is hidden while it is eaten")
	var copy_layer := cover.prey_copy.get_node_or_null("HeldItemLayer") as HeldItemLayer
	assert_not_null(copy_layer)
	assert_eq(copy_layer.item("primary"), "hammer")
	assert_true(cover.prey_copy.get_node("HeldItemN").visible)
	assert_eq(cover.prey_copy.get_node("HeldItemN").position, _sprite(prey).get_node("HeldItemN").position)

func test_a_blade_kills_halves_leave_the_items_out() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 16)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(800, 20)
	shape.shape = box
	floor_body.add_child(shape)
	add_child_autofree(floor_body)
	var e := _enemy(_twin("goblin_smith"))
	await wait_physics_frames(2)
	e.receive_hit(9999, "physical", Vector2(-40, 0), "blade")
	var fx: Node
	for c in e.get_children():
		if c is DeathFx:
			fx = c
	assert_not_null(fx)
	assert_null(fx.find_child("HeldItem*", true, false), "the halves are cut bare textures")
	assert_false(_sprite(e).get_node("HeldItemN").is_visible_in_tree(), "the whole sprite and its items are replaced by the halves")

func test_swaps_husk_and_mislead_decoy_leave_the_items_out() -> void:
	var arena := VerbArena.new(self)
	arena.fresh()
	arena.lizard.global_position = Vector2(900.0, 0.0)
	var smith := _enemy(_twin("goblin_smith"))
	smith.global_position = Vector2(20.0, 0.0)
	var swap := arena.verb("goblin_changeling")
	assert_true(swap.activate())
	var husks := get_tree().get_nodes_in_group("verb_husks")
	assert_eq(husks.size(), 1)
	assert_eq((husks[0].get_child(0) as Sprite2D).texture, _sprite(smith).texture, "it wears the nearest creature's look")
	assert_null(husks[0].find_child("HeldItem*", true, false), "Swap's husk is a bare texture: no items")
	for h in husks:
		h.free()
	HeldItemLayer.attach(arena.player.get_node("Sprite")).set_item("primary", "axe")
	var puck := arena.verb("goblin_puck")
	assert_true(puck.activate())
	husks = get_tree().get_nodes_in_group("verb_husks")
	assert_eq(husks.size(), 1)
	assert_null(husks[0].find_child("HeldItem*", true, false), "Mislead's decoy copies the caster's texture: no items")
	arena.clean()
