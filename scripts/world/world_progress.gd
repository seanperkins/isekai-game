class_name WorldProgress
extends RefCounted
## What the player has found, kept across runs: visited rooms (the map), opened shortcuts and
## read tablets. Saves through the Profile when one is given; without one it lives in memory.

signal shortcut_opened(id: String)

## The Cave mouth's rebirth pool: always attuned, so the game always has somewhere to start.
const DEFAULT_POOL := "C1"
const DEFAULT_SPECIES := "slime"

var profile  # Profile, or null
var visited: Array = []
var shortcuts: Array = []
var tablets: Array = []
## Rebirth pools the player has attuned to (the default pool is implicit).
var rebirths: Array = []
## Where the next run starts ({"pool", "species"}), set on death and consumed by the game on reload.
## In memory only: the scene rebuilds on every death, so it cannot live on the Run node.
var pending_start := {}
var _last_pool := DEFAULT_POOL
var _species := DEFAULT_SPECIES

func _init(p_profile = null) -> void:
	profile = p_profile
	if profile != null:
		visited = profile.list_section("map")
		shortcuts = profile.list_section("shortcuts")
		tablets = profile.list_section("tablets")
		rebirths = profile.list_section("rebirths")
		var choice: Dictionary = profile.dict_section("rebirth_choice")
		if typeof(choice.get("pool")) == TYPE_STRING:
			_last_pool = choice["pool"]
		if typeof(choice.get("species")) == TYPE_STRING:
			_species = choice["species"]

func visit(id: String) -> void:
	if not visited.has(id):
		visited.append(id)
		_save()

func is_visited(id: String) -> bool:
	return visited.has(id)

func open_shortcut(id: String) -> void:
	if shortcuts.has(id):
		return
	shortcuts.append(id)
	_save()
	shortcut_opened.emit(id)

func is_open(id: String) -> bool:
	return shortcuts.has(id)

func read_tablet(id: String) -> void:
	if not tablets.has(id):
		tablets.append(id)
		_save()

func is_read(id: String) -> bool:
	return tablets.has(id)

func attune(id: String) -> void:
	if id == "" or rebirths.has(id):
		return
	rebirths.append(id)
	_save()

func is_attuned(id: String) -> bool:
	return id == DEFAULT_POOL or rebirths.has(id)

func last_choice() -> Dictionary:
	return {"pool": _last_pool, "species": _species}

func set_last_choice(pool: String, species := DEFAULT_SPECIES) -> void:
	_last_pool = pool
	_species = species
	_save()

## Drops attuned ids and a last choice that no room holds any more (`pool_ids` are the pools in the room
## data): a stale save falls back to the default pool instead of crashing or starting nowhere.
func sanitize(pool_ids: Array) -> void:
	rebirths = rebirths.filter(func(id: String) -> bool: return pool_ids.has(id))
	if _last_pool != DEFAULT_POOL and not pool_ids.has(_last_pool):
		_last_pool = DEFAULT_POOL
	_save()

## The pending start, once: reading it clears it, so an unrelated reload never replays a kit.
func take_pending() -> Dictionary:
	var out := pending_start
	pending_start = {}
	return out

func _save() -> void:
	if profile == null:
		return
	profile.set_section("map", visited.duplicate())
	profile.set_section("shortcuts", shortcuts.duplicate())
	profile.set_section("tablets", tablets.duplicate())
	profile.set_section("rebirths", rebirths.duplicate())
	profile.set_section("rebirth_choice", {"pool": _last_pool, "species": _species})
	profile.save()
