class_name WorldProgress
extends RefCounted
## What the player has found, kept across runs: visited rooms (the map), opened shortcuts, read tablets and the body
## forms reached in any life. Saves through the Profile when one is given; without one it lives in memory.

signal shortcut_opened(id: String)

## The Cave mouth's rebirth pool: always attuned, so the game always has somewhere to start.
const DEFAULT_ALTAR := "C1"
const DEFAULT_SPECIES := "slime"
## Deaths after the one that left them that remains outlast, unrecovered.
const REMAINS_DEATHS := 3
## The part that anchors the remains it lies in.
const PHYLACTERY := "phylactery_shard"

var profile  # Profile, or null
var visited: Array = []
var shortcuts: Array = []
var tablets: Array = []
## Rebirth pools the player has attuned to (the default pool is implicit).
var rebirths: Array = []
## Body forms reached in any life (the Tree tab keeps them). Every species' base is reached by definition and never stored.
var forms_reached: Array = []
## Boss creature ids the player has beaten.
var bosses: Array = []
## Where the next run starts ({"altar", "species", "kit"}), set on death and consumed by the game on reload.
## In memory only: the scene rebuilds on every death, so it cannot live on the Run node.
var pending_start := {}
## What the last life carried when it died: {"room", "pos": [x, y] (local to the room), "parts": [ids], "deaths_left"}; {} for none.
var remains := {}
var _last_altar := DEFAULT_ALTAR
var _species := DEFAULT_SPECIES

func _init(p_profile = null) -> void:
	profile = p_profile
	if profile != null:
		visited = profile.list_section("map")
		shortcuts = profile.list_section("shortcuts")
		tablets = profile.list_section("tablets")
		rebirths = profile.list_section("rebirths")
		forms_reached = profile.list_section("forms_reached")
		bosses = profile.list_section("bosses")
		remains = _read_remains(profile.dict_section("remains"))
		var choice: Dictionary = profile.dict_section("rebirth_choice")
		if typeof(choice.get("pool")) == TYPE_STRING:
			_last_altar = choice["pool"]
		if typeof(choice.get("species")) == TYPE_STRING:
			_species = choice["species"]

func visit(id: String) -> void:
	if not visited.has(id):
		visited.append(id)
		_save()

func is_visited(id: String) -> bool:
	return visited.has(id)

## A boss (a creature id) the player has beaten: it is not spawned again and its room builds without an arena. Kept in memory for the
## session whatever the disk said; every `_save` rewrites every section, so a write that failed is retried by the next one.
func defeat_boss(id: String) -> void:
	if bosses.has(id):
		return
	bosses.append(id)
	_save()

func is_defeated(id: String) -> bool:
	return bosses.has(id)

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
	return id == DEFAULT_ALTAR or rebirths.has(id)

## Written by the game when Player.form_advanced fires.
func reach_form(id: String) -> void:
	if id == "" or Form.is_base(id) or forms_reached.has(id):
		return
	forms_reached.append(id)
	_save()

func is_form_reached(id: String) -> bool:
	return Form.is_base(id) or forms_reached.has(id)

## The last life's choice. Its `pool` key holds an altar id: a key the saved `rebirth_choice` section has always used, kept so
## no save needs migrating.
func last_choice() -> Dictionary:
	return {"pool": _last_altar, "species": _species}

func set_last_choice(altar: String, species := DEFAULT_SPECIES) -> void:
	_last_altar = altar
	_species = species
	_save()

## Drops attuned ids and a last choice that no room holds any more (`pool_ids` are the pools in the room
## data): a stale save falls back to the default pool instead of crashing or starting nowhere.
func sanitize(pool_ids: Array) -> void:
	rebirths = rebirths.filter(func(id: String) -> bool: return pool_ids.has(id))
	if _last_altar != DEFAULT_ALTAR and not pool_ids.has(_last_altar):
		_last_altar = DEFAULT_ALTAR
	_save()

## A life ended carrying `parts`: they wait at `pos` (local to `room`), replacing older remains. A death with nothing to leave does
## nothing here (the game counts it with note_death_unrecovered).
func leave_remains(room: String, pos: Vector2, parts: Array) -> void:
	if room == "" or parts.is_empty():
		return
	remains = {"room": room, "pos": [pos.x, pos.y], "parts": parts.duplicate(), "deaths_left": REMAINS_DEATHS}
	_save()

## The remains, once: taking them clears them, so they never come back twice.
func take_remains() -> Dictionary:
	var out := remains
	remains = {}
	_save()
	return out

## Some of the remains were taken: what is left stays saved (nothing left clears them).
func keep_remains(parts: Array) -> void:
	if remains.is_empty():
		return
	if parts.is_empty():
		remains = {}
	else:
		remains["parts"] = parts.duplicate()
	_save()

## A death passed with the remains still out there: they go after REMAINS_DEATHS of them.
func note_death_unrecovered() -> void:
	if not remains.is_empty() and (remains["parts"] as Array).has(PHYLACTERY):
		return  # a phylactery shard in the pile anchors it: it does not wear away
	if remains.is_empty():
		return
	remains["deaths_left"] = int(remains["deaths_left"]) - 1
	if int(remains["deaths_left"]) <= 0:
		remains = {}
	_save()

## Drops parts the data no longer holds from the remains, and the whole of them when none is left or their room is gone.
func sanitize_remains(part_ids: Array, room_ids: Array) -> void:
	if remains.is_empty():
		return
	var kept: Array = remains["parts"].filter(func(id: String) -> bool: return part_ids.has(id))
	if kept.is_empty() or not room_ids.has(remains["room"]):
		remains = {}
	else:
		remains["parts"] = kept
	_save()

## The saved section if it is whole, else {}: a malformed one is dropped, not repaired.
static func _read_remains(d: Dictionary) -> Dictionary:
	if typeof(d.get("room")) != TYPE_STRING or d["room"] == "" or typeof(d.get("pos")) != TYPE_ARRAY or d["pos"].size() != 2:
		return {}
	for n in d["pos"]:
		if typeof(n) != TYPE_FLOAT and typeof(n) != TYPE_INT:
			return {}
	if typeof(d.get("parts")) != TYPE_ARRAY or d["parts"].is_empty() or d["parts"].any(func(x) -> bool: return typeof(x) != TYPE_STRING):
		return {}
	if typeof(d.get("deaths_left")) != TYPE_FLOAT and typeof(d.get("deaths_left")) != TYPE_INT:
		return {}
	if int(d["deaths_left"]) < 1:
		return {}
	return {"room": d["room"], "pos": [float(d["pos"][0]), float(d["pos"][1])], "parts": d["parts"].duplicate(),
		"deaths_left": mini(int(d["deaths_left"]), REMAINS_DEATHS)}

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
	profile.set_section("forms_reached", forms_reached.duplicate())
	profile.set_section("bosses", bosses.duplicate())
	profile.set_section("remains", remains.duplicate(true))
	profile.set_section("rebirth_choice", {"pool": _last_altar, "species": _species})
	profile.save()
