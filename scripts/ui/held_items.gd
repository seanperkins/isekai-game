class_name HeldItems
extends RefCounted
## data/held_items.json (tools/art/blender/held.py writes it): the things a goblin's hands can hold, each a sprite set of its own with a grip, and for every goblin form
## what it holds by default in its primary and secondary hand, which arm the primary hand is, and how much its items are scaled. The held-item layer (held_item_layer.gd) draws them.

const DEFAULT_PATH := "res://data/held_items.json"
## Where the table is read from; a test points it at a table of its own.
static var path := DEFAULT_PATH
static var _table := {}
static var _read_from := ""

static func _data() -> Dictionary:
	if _read_from != path:
		_table = {"items": {}, "forms": {}}
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				_table = parsed
		_read_from = path
	return _table

## {"set", "frame", "grip": Vector2 (bottom-centre pixels of the item's picture), "ppu", "two_handed": bool}, or {} for an id the table does not have.
static func item(id: String) -> Dictionary:
	var items: Dictionary = _data().get("items", {})
	if not items.has(id):
		return {}
	var entry: Dictionary = items[id]
	var grip: Array = entry["grip"]
	return {"set": str(entry["set"]), "frame": str(entry.get("frame", "item")), "grip": Vector2(float(grip[0]), float(grip[1])), "ppu": float(entry.get("ppu", 30.0)), "two_handed": bool(entry.get("two_handed", false))}

## {"scale": float, "handed": "n"|"f" (the arm the primary hand is), "primary": item id or "", "secondary": ...} for a form id (goblin_smith); "" is the base goblin, which holds
## nothing. An unknown form scales by 1, is near-handed and holds nothing.
static func form(id: String) -> Dictionary:
	var forms: Dictionary = _data().get("forms", {})
	var key := "goblin" if id == "" else id
	if not forms.has(key):
		return {"scale": 1.0, "handed": "n", "primary": "", "secondary": ""}
	var entry: Dictionary = forms[key]
	return {"scale": float(entry.get("scale", 1.0)), "handed": str(entry.get("handed", "n")), "primary": str(entry.get("primary", "")), "secondary": str(entry.get("secondary", ""))}
