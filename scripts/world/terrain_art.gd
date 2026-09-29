class_name TerrainArt
extends RefCounted
## Terrain, back-wall and parallax textures for one biome, built by tools/art/terrain_build.py:
## res://assets/tiles/<biome>/ and res://assets/backgrounds/<biome>/. A biome without art returns
## null everywhere, so its rooms keep the old flat look. (Art.texture() only reads
## res://assets/sprites/, where decor lives.)

const TILE := "res://assets/tiles/%s/%s.png"
const LAYER := "res://assets/backgrounds/%s/%s.png"
const META := "res://assets/tiles/%s/meta.json"

static var _meta := {}

## The CanvasModulate colour for a biome. A bright ambient lets a prismatic cave read as alive;
## the lights still add colour on top. Areas without an entry use `fallback`.
const AMBIENT := {
	"cave": Color(0.86, 0.84, 0.96),
	"deep": Color(0.6, 0.6, 0.78),
	"grotto": Color(0.88, 0.84, 0.94),
	"flooded": Color(0.84, 0.92, 0.98),
}

## A tile or edge piece, or null when this biome has none.
static func tile(biome: String, piece: String) -> Texture2D:
	var path := TILE % [biome, piece]
	return load(path) if ResourceLoader.exists(path) else null

## A parallax layer, or null.
static func layer(biome: String, piece: String) -> Texture2D:
	var path := LAYER % [biome, piece]
	return load(path) if ResourceLoader.exists(path) else null

## How much a biome's backdrop layers are dimmed on top of the per-layer tints. A biome whose platforms
## share the backdrop's hue (teal on teal) needs a darker backdrop so the platforms stay clearly visible.
const BACKDROP_DIM := {
	"cave": 1.0,
	"deep": 1.0,
	"grotto": 0.85,
	"flooded": 0.68,
}

## The flat colour behind a biome's back-wall tile in the simple two-layer look: dark, so the platforms read,
## and tinted toward the biome so each one feels different.
const BACKGROUND := {
	"cave": Color(0.10, 0.08, 0.19),
	"deep": Color(0.06, 0.06, 0.12),
	"grotto": Color(0.06, 0.13, 0.12),
	"flooded": Color(0.04, 0.10, 0.17),
}

static func background_color(biome: String) -> Color:
	return BACKGROUND.get(biome, Color(0.06, 0.06, 0.12))

static func backdrop_dim(biome: String) -> float:
	return BACKDROP_DIM.get(biome, 1.0)

static func ambient(biome: String, fallback: Color) -> Color:
	return AMBIENT.get(biome, fallback)

## True when the biome's terrain block exists (its stone fill).
static func has_biome(biome: String) -> bool:
	return ResourceLoader.exists(TILE % [biome, "fill_a"])

## Per-piece facts from terrain_build.py: "surface" is the row (or column, for side faces) of the
## piece that lines up with the collision edge; "size" is its pixel size.
static func meta(biome: String, piece: String) -> Dictionary:
	if not _meta.has(biome):
		var path := META % biome
		_meta[biome] = load(path).data if ResourceLoader.exists(path) else {}
	return _meta[biome].get(piece, {})
