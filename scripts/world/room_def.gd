class_name RoomDef
extends Resource
## One room of the world. Content lives in res://data/rooms/ and is edited with tools/edit_rooms.sh (see docs/rooms.md).
## Positions are local pixels. The room sits at `cell` on a shared grid of screens, so every
## room has a fixed world rect and neighbours line up exactly.

const SCREEN := Vector2(640, 360)
const WALL := 20.0   # generated side walls and ceiling
const FLOOR := 40.0  # generated floor
const NO_START := Vector2(-1, -1)

@export var id := ""
@export var area := ""
@export var cell := Vector2i.ZERO
@export var size := Vector2i.ONE  # in screens
## Where a new run places the player (local px). Only the starting room has one.
@export var start := NO_START
## Interior solids (Rect2, local px). Boundary walls and the floor are generated.
@export var solids: Array = []
## Thin solids (Rect2, each also in `solids`) that stay rock from every side, on purpose. Every other thin
## platform is one-way: you jump up through it and stand on it. See RoomBuilder.is_one_way.
@export var hard_ledges: Array = []
@export var decor: Array = []
## Scenery behind the play plane: [{"piece", "pos", "factor", optional "flip"}] (see SetDressing).
@export var dressing: Array = []
## [{"id": creature id, "pos": Vector2}]
@export var spawns: Array = []
## [{"edge", "from", "to", "room", optional "gate", optional "shortcut"}]
@export var exits: Array = []
## [{"kind": "glow_pool"|"altar"|"tablet"|"switch", "id", "pos", ...}]; a `pos` is the feature's base, the top of the surface it stands on
@export var features: Array = []
## Deep water (Rect2, local px): swim physics, the swimmers' homes, drawn by RoomBuilder as DeepWater. At least 32x32, inside the
## room, never overlapping or touching another. Shallow water is decor.
@export var water: Array = []

func pixel_size() -> Vector2:
	return Vector2(size) * SCREEN

func world_rect() -> Rect2:
	return Rect2(Vector2(cell) * SCREEN, pixel_size())

func is_start() -> bool:
	return start != NO_START
