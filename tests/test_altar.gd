extends GutTest
## The altar in the world: built from room data, interactable, attuned by the player (directly, or through the menu).

func _feature(id := "G1", perk := "") -> Dictionary:
	return {"kind": "altar", "id": id, "area": "grotto", "perk": perk, "pos": Vector2(60, 320)}

func _ctx(progress: WorldProgress, announced: Array, extra := {}) -> Dictionary:
	var ctx := {"progress": progress, "announce": func(id: String, text: String) -> void: announced.append([id, text])}
	ctx.merge(extra)
	return ctx

func _altar(f: Dictionary, ctx: Dictionary) -> Altar:
	var altar := Altar.new()
	altar.setup(f, ctx)
	add_child_autofree(altar)
	return altar

func _player() -> Node:
	var n := Node.new()
	add_child_autofree(n)
	return n

func test_it_builds_from_data_and_is_interactable() -> void:
	var altar := _altar(_feature("G1", "stats"), _ctx(WorldProgress.new(), []))
	assert_true(altar.is_in_group("interactable"))
	assert_eq(altar.position, Vector2(60, 320))
	assert_eq([altar.id, altar.area, altar.perk], ["G1", "grotto", "stats"])
	assert_eq(altar.title(), "Grotto altar")

func test_a_missing_perk_reads_as_none() -> void:
	var f := _feature()
	f.erase("perk")
	assert_eq(_altar(f, _ctx(WorldProgress.new(), [])).perk, "")

func test_without_a_menu_interacting_attunes_and_says_so_once() -> void:
	var progress := WorldProgress.new()
	var said: Array = []
	var events: Array = []
	var on_event := func(name: String, _tags: Dictionary) -> void: events.append(name)
	EventBus.world_event.connect(on_event)
	var altar := _altar(_feature(), _ctx(progress, said))
	assert_false(progress.is_attuned("G1"))
	altar.interact(_player())
	EventBus.world_event.disconnect(on_event)
	assert_true(progress.is_attuned("G1"))
	assert_eq(said, [["G1", "Your body will remember this place."]])
	assert_eq(events.filter(func(n: String) -> bool: return n == "pool_attuned").size(), 1, "the audio cue fires once")
	altar.interact(_player())
	assert_eq(said.size(), 1, "a second visit announces nothing new")
	assert_eq(progress.rebirths, ["G1"])

func test_with_a_menu_interacting_opens_it_and_does_not_attune() -> void:
	var progress := WorldProgress.new()
	var opened: Array = []
	var altar := _altar(_feature(), _ctx(progress, [], {"altar_menu": func(a: Altar) -> void: opened.append(a)}))
	altar.interact(_player())
	assert_eq(opened, [altar])
	assert_false(progress.is_attuned("G1"), "the menu's attune row does that")

func test_announce_attuned_says_it_and_emits_the_cue() -> void:
	var said: Array = []
	var altar := _altar(_feature(), _ctx(WorldProgress.new(), said))
	altar.announce_attuned()
	assert_eq(said, [["G1", "Your body will remember this place."]])

func test_the_prompt_follows_attunement() -> void:
	var progress := WorldProgress.new()
	var altar := _altar(_feature(), _ctx(progress, []))
	assert_eq(altar.prompt(), "attune")
	progress.attune("G1")
	assert_eq(altar.prompt(), "altar")
	assert_eq(_altar(_feature("C1"), _ctx(progress, [])).prompt(), "altar", "the Cave mouth is attuned from the start")

func test_the_altar_glows_pale_violet_not_the_glow_pools_teal() -> void:
	var altar := _altar(_feature(), _ctx(WorldProgress.new(), []))
	assert_gt(altar.glow_color().b, altar.glow_color().g, "violet-white, not teal")
	assert_gt(altar.glow_color().r, 0.6)
