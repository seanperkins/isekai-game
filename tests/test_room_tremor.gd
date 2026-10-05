extends GutTest
## Plan: boss arenas, Task 6. A room with `tremor` shakes the screen, drops dust and rumbles every 5 to 9 s, harder the higher the value;
## the sound has a near and a far cue. (The node is RoomTremor: `Tremor` is already the skill.)

var events: Array = []
var shakes: Array = []

func _on_event(n: String, t: Dictionary) -> void:
	if n == "boss_tremor":
		events.append(t)

func before_each() -> void:
	events = []
	shakes = []
	EventBus.world_event.connect(_on_event)

func after_each() -> void:
	if EventBus.world_event.is_connected(_on_event):
		EventBus.world_event.disconnect(_on_event)

func _def(tremor: float) -> RoomDef:
	var r := RoomDef.new()
	r.id = "T1"
	r.area = "plain"
	r.tremor = tremor
	return r

func _node(tremor: float, ctx := {}, seed := 7) -> RoomTremor:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var t := RoomTremor.new()
	t.setup(_def(tremor), ctx, rng)
	add_child_autofree(t)
	return t

func _ctx() -> Dictionary:
	return {"shake": func(amount: float, seconds: float) -> void: shakes.append([amount, seconds])}

func test_it_fires_on_the_seeded_schedule_with_gaps_of_5_to_9_s() -> void:
	var ref := RandomNumberGenerator.new()
	ref.seed = 7
	var t := _node(0.3, _ctx())
	var fired_at: Array = []
	var clock := 0.0
	while clock < 40.0:
		var before := events.size()
		t._physics_process(0.1)
		clock += 0.1
		if events.size() > before:
			fired_at.append(clock)
	assert_gte(fired_at.size(), 4)
	var expected := 0.0
	var last := 0.0
	for k in fired_at.size():
		expected += ref.randf_range(RoomTremor.MIN_GAP, RoomTremor.MAX_GAP)
		assert_almost_eq(fired_at[k], expected, 0.11, "rumble %d on the seeded schedule" % k)
		assert_between(fired_at[k] - last, RoomTremor.MIN_GAP - 0.11, RoomTremor.MAX_GAP + 0.11)
		last = fired_at[k]

func test_the_shake_and_the_event_scale_with_the_value() -> void:
	for strength in [0.3, 0.6]:
		events = []
		shakes = []
		var t := _node(strength, _ctx())
		for _k in 100:
			t._physics_process(0.1)
		assert_gt(events.size(), 0)
		assert_eq(events[0]["strength"], strength)
		assert_eq(events[0]["near"], strength >= 0.5, "near at 0.6, far at 0.3")
		assert_almost_eq(shakes[0][0], strength * RoomTremor.SHAKE_PER_STRENGTH, 0.001)
		t.free()

func test_a_tremor_with_no_shake_callable_still_emits() -> void:
	var t := _node(0.6)
	for _k in 100:
		t._physics_process(0.1)
	assert_gt(events.size(), 0)

func test_each_rumble_drops_dust_that_fades() -> void:
	var t := _node(0.6, _ctx())
	for _k in 100:
		t._physics_process(0.1)
		if events.size() > 0:
			break
	assert_gt(get_tree().get_nodes_in_group(RoomTremor.DUST_GROUP).size(), 0, "dust in the air")
	await wait_seconds(RoomTremor.DUST_SECONDS + 0.5)
	assert_eq(get_tree().get_nodes_in_group(RoomTremor.DUST_GROUP).size(), 0, "and settled")

func test_a_room_with_no_tremor_has_none_and_the_editor_preview_has_none() -> void:
	var still := RoomBuilder.build_room(_def(0.0), {"shake": Callable(self, "_ignore")})
	add_child_autofree(still)
	assert_eq(still.get_children().filter(func(n: Node) -> bool: return n is RoomTremor).size(), 0)
	var shaking := RoomBuilder.build_room(_def(0.6), {"shake": Callable(self, "_ignore")})
	add_child_autofree(shaking)
	assert_eq(shaking.get_children().filter(func(n: Node) -> bool: return n is RoomTremor).size(), 1)
	var preview := RoomBuilder.build_room(_def(0.6), {"progress": null})
	add_child_autofree(preview)
	assert_eq(preview.get_children().filter(func(n: Node) -> bool: return n is RoomTremor).size(), 0, "the editor's preview passes no shake: it stays quiet")

func _ignore(_a: float, _b: float) -> void:
	pass

func test_the_sound_has_a_near_and_a_far_cue_and_the_taratect_dies_like_a_boss() -> void:
	var catalog := CueCatalog.load_file("res://data/audio/cues.json")
	var near: Dictionary = catalog.route("boss_tremor", {"near": true})
	var far: Dictionary = catalog.route("boss_tremor", {"near": false})
	assert_ne(near.get("cue", ""), "")
	assert_ne(far.get("cue", ""), "")
	assert_ne(near["cue"], far["cue"], "two cues of different strength")
	assert_lt(float(catalog.cues[far["cue"]]["volume_db"]), float(catalog.cues[near["cue"]]["volume_db"]), "the far one is quieter")
	assert_eq(catalog.route("enemy_died", {"id": "taratect"}), {"cue": "enemy_death_boss"})
