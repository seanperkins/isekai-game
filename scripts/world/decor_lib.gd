class_name DecorLib
extends RefCounted
## The decor sprites the editor can place: id -> {anchor: "bottom" | "top", light: Color (optional)}. A bottom-anchored piece
## stands on its position, a top-anchored one hangs from it (RoomBuilder.build_decor). The 31 ids the shipped rooms use are pinned
## to the data by test_decor_lib; the other 15 rows have no shipped instance and are chosen, not pinned: each takes the anchor of
## its cave counterpart and the light of its grotto or cave counterpart (deep_bones has none: bottom, no light). A new biome's art
## needs rows here. An id is bound to a biome by its `<biome>_` prefix; no prefix means cave (tools/prefabs.gd decor_id is the
## forward mapping).

const UNKNOWN_BOX := Rect2(-12, -24, 24, 24)

const CATALOG := {
	# cave (crystal_purple has no shipped instance)
	"crystal_blue": {"anchor": "bottom", "light": Color(0.3, 0.5, 1, 1)},
	"crystal_gold": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"crystal_prism": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	"crystal_purple": {"anchor": "bottom", "light": Color(0.75, 0.5, 1, 1)},
	"crystal_rose": {"anchor": "bottom", "light": Color(1, 0.55, 0.75, 1)},
	"crystal_teal": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"flowers": {"anchor": "bottom"},
	"glow_fungus": {"anchor": "bottom", "light": Color(0.35, 0.95, 0.7, 1)},
	"lichen_hang": {"anchor": "top", "light": Color(0.35, 0.95, 0.7, 1)},
	"puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"root_hang": {"anchor": "top"},
	"rubble": {"anchor": "bottom"},
	"stalactite": {"anchor": "top"},
	"stalagmite": {"anchor": "bottom"},
	"vine": {"anchor": "top"},
	"wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	# grotto
	"grotto_crystal_gold": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},  # chosen, not pinned
	"grotto_crystal_prism": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	"grotto_crystal_rose": {"anchor": "bottom", "light": Color(1, 0.55, 0.75, 1)},
	"grotto_flowers": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"grotto_glow_fungus": {"anchor": "bottom", "light": Color(0.5, 1, 0.6, 1)},
	"grotto_lichen_hang": {"anchor": "top"},
	"grotto_puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},  # chosen, not pinned
	"grotto_root_hang": {"anchor": "top"},
	"grotto_rubble": {"anchor": "bottom"},  # chosen, not pinned
	"grotto_stalagmite": {"anchor": "bottom"},  # chosen, not pinned
	"grotto_wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},  # chosen, not pinned
	# deep (no shipped room: chosen, not pinned)
	"deep_bones": {"anchor": "bottom"},
	"deep_glow_fungus": {"anchor": "bottom", "light": Color(0.5, 1, 0.6, 1)},
	"deep_lichen_hang": {"anchor": "top"},
	"deep_puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"deep_root_hang": {"anchor": "top"},
	"deep_rubble": {"anchor": "bottom"},
	"deep_stalagmite": {"anchor": "bottom"},
	"deep_wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	# flooded (no shipped room: chosen, not pinned)
	"flooded_crystal_gold": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"flooded_crystal_prism": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
	"flooded_crystal_rose": {"anchor": "bottom", "light": Color(1, 0.55, 0.75, 1)},
	"flooded_flowers": {"anchor": "bottom", "light": Color(1, 0.85, 0.4, 1)},
	"flooded_glow_fungus": {"anchor": "bottom", "light": Color(0.5, 1, 0.6, 1)},
	"flooded_lichen_hang": {"anchor": "top"},
	"flooded_puddle_glow": {"anchor": "bottom", "light": Color(0.3, 1, 0.9, 1)},
	"flooded_root_hang": {"anchor": "top"},
	"flooded_rubble": {"anchor": "bottom"},
	"flooded_stalagmite": {"anchor": "bottom"},
	"flooded_wall_crystal": {"anchor": "bottom", "light": Color(0.95, 0.85, 1, 1)},
}

## The biome a decor id belongs to: its `<biome>_` prefix when `<biome>` is a biome with terrain art (and not cave), else cave.
static func biome_of(id: String) -> String:
	for b in TerrainArt.biomes():
		if b != "cave" and id.begins_with(b + "_"):
			return b
	return "cave"

## The catalog ids for a biome, sorted.
static func ids_for_biome(biome: String) -> Array:
	var out: Array = []
	for id in CATALOG:
		if biome_of(id) == biome:
			out.append(id)
	out.sort()
	return out

## The data a placed piece gets: `anchor: "top"` only when the catalog says so, `light` only when it has one.
static func entry(id: String, pos: Vector2) -> Dictionary:
	var row: Dictionary = CATALOG.get(id, {})
	var e := {"id": id, "pos": pos}
	if row.get("anchor", "bottom") == "top":
		e["anchor"] = "top"
	if row.has("light"):
		e["light"] = row["light"]
	return e

## The sprite's box relative to the piece's position (RoomBuilder.build_decor: a bottom-anchored sprite ends at the position, a
## top-anchored one starts there, both centred in x). `anchor` is the piece's own ("" = the catalog's, for a piece not placed yet).
## An id with no catalog row or no sprite gets a fixed fallback box on the same side, so a hand-edited unknown piece can still be
## hit, outlined and deleted.
static func texture_box(id: String, anchor := "") -> Rect2:
	if anchor == "":
		anchor = str(CATALOG.get(id, {}).get("anchor", "bottom"))
	var tex := Art.texture(id) if CATALOG.has(id) else null
	var w := UNKNOWN_BOX.size.x
	var h := UNKNOWN_BOX.size.y
	if tex != null:
		w = float(tex.get_width())
		h = float(tex.get_height())
	return Rect2(-w / 2.0, 0.0 if anchor == "top" else -h, w, h)

## The box of a piece in a room's data. The play builder reads the entry's own `anchor` (default bottom), so this does too.
static func box_of(d: Dictionary) -> Rect2:
	return texture_box(str(d.get("id", "")), str(d.get("anchor", "bottom")))
