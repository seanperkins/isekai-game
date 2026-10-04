class_name Game
extends Node2D
## The game: the World (rooms), the player, the HUD, the skill screen and the Run.
## Death shows the Run's card, then resets the run and reloads the scene.

const ROOMS_DIR := "res://data/rooms"
const AMBIENT := Color(0.6, 0.6, 0.78)  # dim cave; lights bring colour back (fallback for areas without art)
const EDITOR_SCENE := "res://scenes/room_editor.tscn"

## Set by the room editor before it changes to main.tscn, consumed and cleared by _ready:
## {"rooms": Dictionary, "room": String, "pos": Vector2 (the player's origin, room-local), optional "kit": Dictionary (a rebirth
## kit granted at the start, never touching the Compendium), optional "open_shortcuts": bool (every shortcut starts open)}.
## Statics, not scene state, so both scenes reach them.
static var play_request := {}
## What the editor gets back when Play ends: {"model": RoomEditModel, "room": String, "view": Dictionary, "play_options":
## {"movement": bool, "shortcuts": bool}}. Consumed by the editor's _ready.
static var editor_resume = null

var player: Player
var hud: Hud
var skill_screen: SkillScreen
var world: World
var run: Run
## The goddess's scene and menu. Null goddess in an editor Play: a death returns to the editor at once.
var goddess: Goddess
var goddess_menu: GoddessMenu
## The in-world altar menu (null in an editor Play, where an altar just attunes).
var altar_menu: AltarMenu
var ambient: CanvasModulate
var _skills_by_id := {}
var _creatures := {}
var _editor_play := false

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
	var request := Game.play_request
	Game.play_request = {}
	_editor_play = not request.is_empty()
	var rooms: Dictionary = request["rooms"] if _editor_play else World.load_rooms(ROOMS_DIR)
	# The editor's Play runs on a fresh in-memory progress, so nothing it visits or opens reaches the real profile.
	var progress = WorldProgress.new() if _editor_play else Compendium.progress
	if _editor_play and bool(request.get("open_shortcuts", false)):
		# before the world builds its first room, so the entry room has neither the gate nor the switch
		for id in rooms:
			for e in (rooms[id] as RoomDef).exits:
				if e.has("shortcut"):
					progress.open_shortcut(str(e["shortcut"]))
	if not _editor_play:
		for e in WorldValidator.validate(rooms, _creatures.keys()):
			push_error(e)
	var world_ctx := {"spawn": _spawn, "progress": progress, "compendium": Compendium.model, "announce": Announcer.queue.push_unlock}
	if not _editor_play:
		world_ctx["altar_menu"] = _open_altar_menu  # the menu is built once the goddess exists, after the world
	world.setup(rooms, player, world_ctx)
	world.room_entered.connect(_on_room_entered)
	var altars := RebirthChoice.altars(rooms)
	progress.sanitize(altars.map(func(p: Dictionary) -> String: return p["id"]))
	var start := {"default": false, "room": request["room"], "pos": request["pos"], "kit": request.get("kit", {})} if _editor_play \
		else Game.resolve_start(altars, progress.take_pending(), progress.is_attuned)
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
	skill_screen.bind_world(world, progress)
	# The run's progress, so an editor Play's evolutions stay in its own in-memory progress.
	player.form_advanced.connect(progress.reach_form)
	skill_screen.visibility_changed.connect(func() -> void: hud.visible = not skill_screen.visible)
	run = Run.new()
	add_child(run)
	# Bound without progress in an editor Play: a death emits restart_requested at once and never opens the goddess's menu.
	goddess = null if _editor_play else Goddess.load_default(Compendium.soul, Compendium.model, SkillRules.skill_defs)
	run.bind(player, world, null if _editor_play else Compendium.progress, altars, goddess)
	run.restart_requested.connect(_restart)
	goddess_menu = GoddessMenu.new()  # connected after the run is bound: a listener means the run waits for her choice
	add_child(goddess_menu)
	run.goddess_needed.connect(goddess_menu.open)
	goddess_menu.confirmed.connect(run.accept)
	if goddess != null:
		altar_menu = AltarMenu.new()  # after the skill screen, so it sees input first
		add_child(altar_menu)
		altar_menu.bind(goddess, SkillRules, Compendium.progress, player)
	if not _editor_play:
		Compendium.soul.session_points = Game.soul_points_arg(OS.get_cmdline_user_args())  # set, not added: a reload refills it
	begin_life(start)
	if Game.wants_evolve(OS.get_cmdline_user_args()):
		player.debug_grant_xp(Progression.stage_total(1))  # reach the first evolution without a grind
	if _editor_play:
		var back := EditorReturn.new()
		back.game = self
		add_child(back)

## What an altar calls to open its menu: the world is built before the menu, so it is looked up when used.
func _open_altar_menu(altar: Altar) -> void:
	if altar_menu != null:
		altar_menu.open_for(altar)

## Starts a life: the run's state is cleared, then the bought kit is given, then the perks. The kit comes second because
## start_run() clears everything a kit would set, and the perks last so the stats they raise are filled.
func begin_life(start: Dictionary) -> void:
	SkillRules.start_run()
	if not start["kit"].is_empty():
		# an editor Play passes no compendium: the kit grant must not raise slots in the (persistent) profile
		RebirthKit.apply(player, SkillRules, null if _editor_play else Compendium.model, start["kit"])
	if goddess != null:
		SoulPerks.apply(player, Compendium.soul, goddess.perks)

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
	if _editor_play:
		return_to_editor()
		return
	_prepare_restart()
	get_tree().reload_current_scene.call_deferred()

## The end of an editor Play: the same clean-up as a restart, then back to the editor scene (the model waits in editor_resume).
func return_to_editor() -> void:
	_prepare_restart()
	Audio.reset()
	get_tree().change_scene_to_file.call_deferred(EDITOR_SCENE)

## Everything a fresh run needs before the scene reloads. A pause never carries over.
func _prepare_restart() -> void:
	get_tree().paused = false
	SkillRules.reset_run()
	Announcer.queue.clear()

## `-- --evolve` on the command line starts the run at the first body evolution.
static func wants_evolve(args: Array) -> bool:
	return args.has("--evolve")

## Where the next life starts: the default (the start room) unless `pending` names an attuned pool the room data still holds,
## in which case its room and spot (standing on it). The kit and the species are what the goddess's menu gave, from `pending`
## (never the pool's own kit); a malformed kit or species falls back to `{}` and "slime", and a kit survives a place that is gone.
static func resolve_start(altars: Array, pending: Dictionary, attuned: Callable) -> Dictionary:
	var kit = pending.get("kit", {})
	if typeof(kit) != TYPE_DICTIONARY:
		kit = {}
	var species = pending.get("species", WorldProgress.DEFAULT_SPECIES)
	if typeof(species) != TYPE_STRING:
		species = WorldProgress.DEFAULT_SPECIES
	var default := {"default": true, "kit": kit, "species": species}
	var id = pending.get("altar", "")
	if typeof(id) != TYPE_STRING or id == "" or id == WorldProgress.DEFAULT_ALTAR:
		return default
	for p in altars:
		if p["id"] == id and attuned.call(id):
			return {"default": false, "room": p["room"], "pos": p["pos"] + Vector2(0.0, -BodyConfig.BOTTOM),
				"kit": kit, "altar": id, "species": species}
	return default

## `-- --soul=N` on the command line grants N soul points to spend this session: 0 to 9999, anything else reads 0.
static func soul_points_arg(args: Array) -> int:
	for arg in args:
		var text := str(arg)
		if text.begins_with("--soul="):
			var value := text.trim_prefix("--soul=")
			return clampi(int(value), 0, 9999) if value.is_valid_int() else 0
	return 0
