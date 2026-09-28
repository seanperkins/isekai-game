extends Node2D
## The vertical slice: builds the test room, spawns actors and the HUD, starts a run.
## Death resets the run and reloads the scene (the full death screen is Plan 3).

var player: Player
var hud: Hud

func _ready() -> void:
	Controls.ensure_actions()
	var layout: Dictionary = RoomLayout.TEST_ROOM
	RoomBuilder.build(self, layout)
	var skills_by_id := {}
	for d in SkillRules.skill_defs:
		skills_by_id[d.id] = d
	var creatures := {}
	for c in SkillRules.creature_defs:
		creatures[c.id] = c
	player = Player.new()
	player.setup(SkillRules, Compendium.model, SkillRules.creature_defs, _emit_game_event)
	player.position = layout["player"]
	add_child(player)
	player.add_child(Camera2D.new())
	for spawn in layout["spawns"]:
		var def: CreatureDef = creatures[spawn["id"]]
		var node: Node2D
		if def.id == Sources.WATER_POOL:
			node = WaterPool.new()
			node.setup(def)
		else:
			node = Enemy.new()
			node.setup(def, skills_by_id)
		node.position = spawn["pos"]
		add_child(node)
	player.skillset.slot_replaced.connect(Announcer.queue.push_slot_replaced)
	hud = Hud.new()
	add_child(hud)
	hud.bind(player, SkillRules, Compendium.model, Announcer.queue)
	player.died.connect(_on_player_died)
	SkillRules.start_run()

func _emit_game_event(event_name: String, tags: Dictionary) -> void:
	EventBus.game_event.emit(event_name, tags)

func _on_player_died() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()
	get_tree().reload_current_scene.call_deferred()
