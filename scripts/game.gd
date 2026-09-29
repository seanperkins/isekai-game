class_name Game
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

## Each biome sets its own ambient light and sound: the bright Cave, a darker deep, and so on.
func _on_room_entered(id: String) -> void:
	var area: String = world.rooms[id].area
	var target: Color = TerrainArt.ambient(area, AMBIENT)
	var tw := create_tween()
	tw.tween_property(ambient, "color", target, 0.6)
	Audio.set_biome(area)

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
	for e in WorldValidator.validate(rooms, _creatures.keys()):
		push_error(e)
	world.setup(rooms, player, {"spawn": _spawn, "progress": Compendium.progress,
		"compendium": Compendium.model, "announce": Announcer.queue.push_unlock})
	world.room_entered.connect(_on_room_entered)
	var pools := RebirthChoice.pools(rooms)
	Compendium.progress.sanitize(pools.map(func(p: Dictionary) -> String: return p["id"]))
	var start := Game.resolve_start(pools, Compendium.progress.take_pending(), Compendium.progress.is_attuned)
	if start["default"]:
		world.enter_start()
	else:
		world.enter_at(start["room"], start["pos"])
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
	run.bind(player, world, Compendium.progress, pools)
	run.restart_requested.connect(_restart)
	begin_life(start)
	if Game.wants_evolve(OS.get_cmdline_user_args()):
		player.debug_grant_xp(Progression.stage_total(1))  # reach the first evolution without a grind

## Starts a life: the run's state is cleared, then the pool's kit is given. The kit comes second because
## start_run() clears everything a kit would set.
func begin_life(start: Dictionary) -> void:
	SkillRules.start_run()
	if not start["kit"].is_empty():
		RebirthKit.apply(player, SkillRules, Compendium.model, start["kit"])

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
		node.downed.connect(func(d: CreatureDef) -> void: player.on_enemy_downed(d, node.spawn_key))
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

## `-- --evolve` on the command line starts the run at the first body evolution.
static func wants_evolve(args: Array) -> bool:
	return args.has("--evolve")

## Where the next life starts: the default (the start room, no kit) unless `pending` names an attuned pool
## the room data still holds, in which case its room, its spot (standing on it) and its kit.
static func resolve_start(pools: Array, pending: Dictionary, attuned: Callable) -> Dictionary:
	var default := {"default": true, "kit": {}}
	var id = pending.get("pool", "")
	if typeof(id) != TYPE_STRING or id == "" or id == WorldProgress.DEFAULT_POOL:
		return default
	for p in pools:
		if p["id"] == id and attuned.call(id):
			return {"default": false, "room": p["room"], "pos": p["pos"] + Vector2(0.0, -BodyConfig.BOTTOM),
				"kit": p["kit"], "pool": id}
	return default
