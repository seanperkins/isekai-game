class_name Menagerie
extends RefCounted
## One long room with every creature in it, for looking at them: shipped creatures, then the support monsters, then the twins by
## species and stage. It is played like an editor Play (in-memory progress, nothing saved), started with `-- --room=menagerie`.

const ROOM_ID := "MENAGERIE"
const NAME := "menagerie"
## The water pool is terrain, not a creature.
const EXCLUDED := ["water_pool"]
const SPACING := 56.0
const FIRST_X := 160.0
const START := Vector2(60, 308)
const DROP_Y := 300.0  # a spawn drops from here onto the floor
const HANG_Y := 26.0  # a ceiling walker hangs just under the ceiling
const SWIM_WIDTH := 64.0
const SWIM_DEPTH := 40.0
const TAG_ROWS := [334.0, 348.0]  # two rows of name tags in the floor band, so neighbours' names do not collide

## The creatures in the order the room shows them (the water pool left out).
static func order(creatures: Array) -> Array:
	var by_id := {}
	for c in creatures:
		by_id[c.id] = c
	var out: Array = []
	for id in Sources.SHIPPED:
		if by_id.has(id) and not EXCLUDED.has(id):
			out.append(by_id[id])
	for id in MenagerieIds.SUPPORT:
		if by_id.has(id):
			out.append(by_id[id])
	var twins: Array = []
	for id in MenagerieIds.TWINS:
		if by_id.has(id):
			twins.append(by_id[id])
	var index := {}
	for i in twins.size():
		index[twins[i].id] = i
	twins.sort_custom(func(a: CreatureDef, b: CreatureDef) -> bool:
		var sa := Form.SPECIES.find(a.species)
		var sb := Form.SPECIES.find(b.species)
		if sa != sb:
			return sa < sb
		if a.stage != b.stage:
			return a.stage < b.stage
		return index[a.id] < index[b.id])
	return out + twins

static func _hangs(c: CreatureDef) -> bool:
	return c.skills.any(func(s: Dictionary) -> bool: return s.get("id", "") == "ceiling_walk")

static func spawn_x(i: int) -> float:
	return FIRST_X + float(i) * SPACING

## The room and where Play puts the player: the shape of Game.play_request.
static func request(creatures: Array) -> Dictionary:
	var shown := order(creatures)
	var room := RoomDef.new()
	room.id = ROOM_ID
	room.area = "cave"  # borrows the cave's light and music
	room.cell = Vector2i.ZERO
	var width := spawn_x(shown.size() - 1) + SPACING + RoomDef.WALL
	room.size = Vector2i(int(ceil(width / RoomDef.SCREEN.x)), 1)
	room.start = START
	var floor_y := room.pixel_size().y - RoomDef.FLOOR
	for i in shown.size():
		var c: CreatureDef = shown[i]
		var x := spawn_x(i)
		var y := HANG_Y if _hangs(c) else DROP_Y
		if c.swimmer:  # a swimmer lives in a pool of its own, with a small ledge over it to climb out on (clear of its neighbours)
			var pool := Rect2(x - SWIM_WIDTH / 2.0, floor_y - SWIM_DEPTH, SWIM_WIDTH, SWIM_DEPTH)
			room.water.append(pool)
			room.solids.append(Rect2(x - 8.0, pool.position.y - 4.0, 16.0, 8.0))
			y = pool.position.y + SWIM_DEPTH / 2.0
		room.spawns.append({"id": c.id, "pos": Vector2(x, y)})
	return {"rooms": {ROOM_ID: room}, "room": ROOM_ID, "pos": START}

## The name tags the keeper draws on the floor under each creature: [{"text", "pos"}].
static func tags(creatures: Array) -> Array:
	var out: Array = []
	var shown := order(creatures)
	for i in shown.size():
		out.append({"text": shown[i].display_name, "pos": Vector2(spawn_x(i), TAG_ROWS[i % TAG_ROWS.size()])})
	return out
