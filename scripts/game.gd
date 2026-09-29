extends Node2D
## The game: the World (rooms), the player, the HUD, the skill screen and the Run.
## Death shows the Run's card, then resets the run and reloads the scene.

const ROOMS_DIR := "res://data/rooms"
const AMBIENT := Color(0.6, 0.6, 0.78)  # dim cave; lights bring colour back (fallback for areas without art)

var player: Player
var hud: Hud
var skill_screen: SkillScreen
var world: World
var run: Run
var ambient: CanvasModulate
var _skills_by_id := {}
var _creatures := {}

## Each biome sets its own ambient light: the bright Cave, a darker deep, and so on.
func _on_room_entered(id: String) -> void:
	var target: Color = TerrainArt.ambient(world.rooms[id].area, AMBIENT)
	var tw := create_tween()
	tw.tween_property(ambient, "color", target, 0.6)

func _ready() -> void:
	Controls.ensure_actions()
	ambient = CanvasModulate.new()
	ambient.color = AMBIENT
	add_child(ambient)
	for d in SkillRules.skill_defs:
		_skills_by_id[d.id] = d
	for c in SkillRules.creature_defs:
		_creatures[c.id] = c
	player = Player.new()
	player.setup(SkillRules, Compendium.model, SkillRules.creature_defs, _emit_game_event)
	world = World.new()
	add_child(world)
	var rooms := World.load_rooms(ROOMS_DIR)
	for e in WorldValidator.validate(rooms):
		push_error(e)
	world.setup(rooms, player, {"spawn": _spawn, "progress": Compendium.progress,
		"compendium": Compendium.model, "announce": Announcer.queue.push_unlock})
	world.room_entered.connect(_on_room_entered)
	world.enter_start()
	_on_room_entered(world.current_id)
	player.skillset.slot_replaced.connect(Announcer.queue.push_slot_replaced)
	hud = Hud.new()
	add_child(hud)
	hud.bind(player, SkillRules, Compendium.model, Announcer.queue)
	skill_screen = SkillScreen.new()
	add_child(skill_screen)
	skill_screen.bind(player, SkillRules, Compendium.model, SkillRules.skill_defs)
	skill_screen.bind_world(world, Compendium.progress)
	skill_screen.visibility_changed.connect(func() -> void: hud.visible = not skill_screen.visible)
	run = Run.new()
	add_child(run)
	run.bind(player, world)
	run.restart_requested.connect(_restart)
	SkillRules.start_run()

## A fresh creature (or water pool) for a room, wired to XP and the Bestiary.
func _spawn(id: String, pos: Vector2) -> Node2D:
	var def: CreatureDef = _creatures.get(id)
	if def == null:
		push_error("room spawn: unknown creature '%s'" % id)
		return null
	var node: Node2D
	if def.id == Sources.WATER_POOL:
		node = WaterPool.new()
		node.setup(def)
	else:
		node = Enemy.new()
		node.setup(def, _skills_by_id)
		node.downed.connect(player.on_enemy_downed)
		node.downed.connect(func(d: CreatureDef) -> void: Compendium.model.on_creature_defeated(d.id))
	node.position = pos
	return node

func _emit_game_event(event_name: String, tags: Dictionary) -> void:
	EventBus.game_event.emit(event_name, tags)

func _restart() -> void:
	_prepare_restart()
	get_tree().reload_current_scene.call_deferred()

## Everything a fresh run needs before the scene reloads. A pause never carries over.
func _prepare_restart() -> void:
	get_tree().paused = false
	SkillRules.reset_run()
	Announcer.queue.clear()
