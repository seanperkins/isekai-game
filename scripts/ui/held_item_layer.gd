class_name HeldItemLayer
extends Node
## The two things a goblin holds, drawn on its hands. A goblin's sheet is drawn empty-handed and says, for every frame, where each hand is and how far it is turned
## (`hands`, see SpriteSheet.hands); this puts the item in each hand: its grip on the hand, turned with it, in front of the body for the near hand and behind it for the
## far one. Items belong to roles, not arms: the primary hand is the arm the form says (`handed`: the near one for most goblins, the far one for the paladin), the secondary
## is the other, and a two-handed item fills the primary hand and leaves the secondary empty. It is a plain Node on the body's Sprite2D that owns two Node2D pivots (HeldItemN and HeldItemF) on that same sprite: a plain Node between two canvas items cuts
## the transform chain, so the pivots are the sprite's own children and ride its place, scale and tint. `SpriteSheet.draw_on` calls `follow_on` after every frame it draws.

const NAME := "HeldItemLayer"
const SIDES := ["n", "f"]   # the arms: what the pivots and the sheet's hands are keyed by
const ROLES := ["primary", "secondary"]   # what items are keyed by
## The far hand's item is drawn this much darker, here and nowhere else: the item art is rendered as the near hand's, never shaded for a side.
const FAR_DIM := 0.8

static var _item_sheets := {}   # sheet directory + set name -> SpriteSheet, or null for one that will not load (warned about once)

var _form := "goblin"
var _handed := "n"                 # the arm the primary hand is
var _bound := {"primary": "", "secondary": ""}   # what the form holds by default
var _overrides := {}               # role -> an item id, or "" for a hand held empty on purpose
var _suspended := false
var _last := {}                    # the arguments of the last follow, so a change of item shows at once and a copy can draw the same frame
var _pivots := {}
var _arts := {}

## The sprite's layer, made on first use.
static func attach(sprite: Sprite2D) -> HeldItemLayer:
	var layer := sprite.get_node_or_null(NAME) as HeldItemLayer
	if layer == null:
		layer = HeldItemLayer.new()
		layer.name = NAME
		sprite.add_child(layer)
		layer._make_pivots(sprite)
	return layer

## Draw the items for the frame `sprite` was just given; nothing for a sprite with no layer. `lit` says whether the body was drawn lit (with its normal map).
static func follow_on(sprite: Sprite2D, sheet: SpriteSheet, frame: String, mirrored: bool, lit: bool) -> void:
	var layer := sprite.get_node_or_null(NAME) as HeldItemLayer
	if layer != null:
		layer.follow(sheet, frame, mirrored, lit)

## Hide the sprite's items but keep what was set in them (a form that draws its armed still); the next `bind` shows them again.
static func suspend_on(sprite: Sprite2D) -> void:
	var layer := sprite.get_node_or_null(NAME) as HeldItemLayer
	if layer != null:
		layer._suspended = true
		layer._refresh()

func _make_pivots(sprite: Sprite2D) -> void:
	for side in SIDES:
		var pivot := Node2D.new()
		pivot.name = "HeldItem" + str(side).to_upper()
		pivot.show_behind_parent = side == "f"
		pivot.visible = false
		sprite.add_child(pivot)
		var art := Sprite2D.new()
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if side == "f":
			art.modulate = Color(FAR_DIM, FAR_DIM, FAR_DIM)
		pivot.add_child(art)
		_pivots[side] = pivot
		_arts[side] = art

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for pivot in _pivots.values():
			if is_instance_valid(pivot):
				pivot.queue_free()

## Hold what a form holds by default in the hands that have no item set on them, and show the items. "" is the base goblin.
func bind(form_id: String) -> void:
	_form = "goblin" if form_id == "" else form_id
	_suspended = false
	var entry := HeldItems.form(_form)
	_handed = str(entry["handed"])
	for role in ROLES:
		_bound[role] = entry[role]
	_refresh()

## Put an item in a role's hand ("" empties it); false, and the hand as it was, for a role or an id the table does not have, for a two-handed item in the secondary hand, and
## for anything in the secondary hand while the primary holds a two-handed item. It stays through a `bind` until `clear_overrides`, in its role: it moves to the other arm
## when the next form is handed the other way.
func set_item(role: String, id: String) -> bool:
	if not ROLES.has(role) or (id != "" and HeldItems.item(id).is_empty()):
		return false
	if role == "secondary" and (_primary_is_two_handed() or (id != "" and bool(HeldItems.item(id)["two_handed"]))):
		return false
	_overrides[role] = id
	_refresh()
	return true

func clear_overrides() -> void:
	_overrides.clear()
	_refresh()

## What a role holds; the secondary hand holds nothing while the primary has a two-handed item (what was stored there comes back when the primary changes).
func item(role: String) -> String:
	if not ROLES.has(role) or (role == "secondary" and _primary_is_two_handed()):
		return ""
	return str(_overrides[role]) if _overrides.has(role) else str(_bound[role])

## The arm ("n" or "f") a role's hand is.
func hand_of(role: String) -> String:
	if role == "primary":
		return _handed
	return "f" if _handed == "n" else "n"

func _primary_is_two_handed() -> bool:
	var id := str(_overrides["primary"]) if _overrides.has("primary") else str(_bound["primary"])
	return id != "" and bool(HeldItems.item(id).get("two_handed", false))

## A layer on `other` holding the same things, drawing the frame this one drew last: a picture copy (the eating cover's prey) keeps its items.
func copy_onto(other: Sprite2D) -> HeldItemLayer:
	var copy := HeldItemLayer.attach(other)
	copy._form = _form
	copy._handed = _handed
	copy._bound = _bound.duplicate()
	copy._overrides = _overrides.duplicate()
	copy._suspended = _suspended
	if not _last.is_empty():
		copy.follow(_last["sheet"], _last["frame"], _last["mirrored"], _last["lit"])
	return copy

func _refresh() -> void:
	if _last.is_empty():
		for pivot in _pivots.values():
			pivot.visible = false
	else:
		follow(_last["sheet"], _last["frame"], _last["mirrored"], _last["lit"])

## Place each hand's item on the hand the sheet gives for `frame`. The sprite is centred on its picture but hands are in the hit shapes' space (origin at the bottom
## centre), so a hand is moved down by half the frame's height. Facing left negates x, the grip's x and the turn; a sprite flipped upside down (a downed creature) flips
## each pivot about the body's centre. A frame with no hands, or a hand with no item, shows nothing.
func follow(sheet: SpriteSheet, frame: String, mirrored: bool, lit: bool) -> void:
	_last = {"sheet": sheet, "frame": frame, "mirrored": mirrored, "lit": lit}
	var known := sheet.has_frame(frame)
	var hands: Dictionary = sheet.hands(frame) if known else {}
	var half_height := sheet.frame_size(frame).y / 2.0 if known else 0.0
	var body := get_parent() as Sprite2D
	var m := -1.0 if mirrored else 1.0
	var v := -1.0 if body != null and body.flip_v else 1.0
	var k := float(HeldItems.form(_form)["scale"])
	for side in SIDES:
		var pivot: Node2D = _pivots[side]
		var id := item("primary" if side == _handed else "secondary")
		var item_sheet := _item_sheet(id) if id != "" else null
		if _suspended or item_sheet == null or not hands.has(side):
			pivot.visible = false
			continue
		var hand: Dictionary = hands[side]
		var info := HeldItems.item(id)
		var grip: Vector2 = info["grip"]
		var item_frame: String = info["frame"]
		pivot.visible = true
		pivot.position = Vector2(m * float(hand["x"]), v * (float(hand["y"]) + half_height))
		pivot.rotation = deg_to_rad(float(hand["a"])) * m * v
		pivot.scale = Vector2(k, k * v)
		var art: Sprite2D = _arts[side]
		if lit and item_sheet.has_normals():
			art.texture = item_sheet.lit_texture(item_frame, mirrored)
			art.flip_h = false
		else:
			art.texture = item_sheet.frame_texture(item_frame)
			art.flip_h = mirrored
		art.offset = -Vector2(m * grip.x, grip.y + item_sheet.frame_size(item_frame).y / 2.0)   # the grip, not the picture's centre, sits on the pivot

static func _item_sheet(id: String) -> SpriteSheet:
	var info := HeldItems.item(id)
	if info.is_empty():
		return null
	var key := SpriteSheet.dir + str(info["set"])
	if not _item_sheets.has(key):
		var sheet := SpriteSheet.load_set(str(info["set"]))
		if sheet == null:
			push_warning("HeldItemLayer: the sprite set of item %s (%s) will not load" % [id, info["set"]])
		_item_sheets[key] = sheet
	return _item_sheets[key]
