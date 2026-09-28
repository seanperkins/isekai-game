extends Node2D
## The vertical slice: builds the test room, spawns actors and the HUD, starts a run.
## Death resets the run and reloads the scene (the full death screen is Plan 3).

const ROOM_SIZE := Vector2(1600, 360)
const AMBIENT := Color(0.6, 0.6, 0.78)  # dim cave; lights bring colour back
const BACKDROP_TINT := Color(0.22, 0.21, 0.34)  # far cave wall, pushed back
const BACKDROP := Color(0.06, 0.06, 0.12)

var player: Player
var hud: Hud
var skill_screen: SkillScreen

func _ready() -> void:
	Controls.ensure_actions()
	var layout: Dictionary = RoomLayout.TEST_ROOM
	_build_backdrop()
	RoomBuilder.build(self, layout)
	RoomBuilder.build_decor(self, layout)
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
	var cam := Camera2D.new()
	cam.name = "Camera"
	cam.zoom = Vector2(1, 1)  # the 640x360 internal resolution is scaled to the window
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(ROOM_SIZE.x)
	cam.limit_bottom = int(ROOM_SIZE.y)
	player.add_child(cam)
	for spawn in layout["spawns"]:
		var def: CreatureDef = creatures[spawn["id"]]
		var node: Node2D
		if def.id == Sources.WATER_POOL:
			node = WaterPool.new()
			node.setup(def)
		else:
			node = Enemy.new()
			node.setup(def, skills_by_id)
			node.downed.connect(player.on_enemy_downed)
		node.position = spawn["pos"]
		add_child(node)
	player.skillset.slot_replaced.connect(Announcer.queue.push_slot_replaced)
	hud = Hud.new()
	add_child(hud)
	hud.bind(player, SkillRules, Compendium.model, Announcer.queue)
	skill_screen = SkillScreen.new()
	add_child(skill_screen)
	skill_screen.bind(player, SkillRules, Compendium.model, SkillRules.skill_defs)
	skill_screen.visibility_changed.connect(func() -> void: hud.visible = not skill_screen.visible)
	player.died.connect(_on_player_died)
	SkillRules.start_run()

func _emit_game_event(event_name: String, tags: Dictionary) -> void:
	EventBus.game_event.emit(event_name, tags)

func _on_player_died() -> void:
	SkillRules.reset_run()
	Announcer.queue.clear()
	get_tree().reload_current_scene.call_deferred()

func _build_backdrop() -> void:
	var back := ColorRect.new()
	back.color = BACKDROP
	back.position = Vector2(-40, -40)
	back.size = ROOM_SIZE + Vector2(80, 80)
	back.z_index = -10
	add_child(back)
	var wall := TextureRect.new()
	wall.texture = Art.texture("wall")
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_TILE
	wall.position = back.position
	wall.size = back.size
	wall.modulate = BACKDROP_TINT
	wall.z_index = -9
	add_child(wall)
	var ambient := CanvasModulate.new()
	ambient.color = AMBIENT
	add_child(ambient)
