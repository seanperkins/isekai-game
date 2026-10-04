class_name Altar
extends Node2D
## An altar: a place to be reborn and to spend what you have gathered. Attune to it (Inspect) and it is unlocked for every future
## run; the goddess's menu then offers it as a place to start. Interacting opens the altar menu (attune, bank essence, buy this
## altar's perk); with no menu (an editor Play) it just attunes. A pale violet-white glow and a slow ring of motes keep it from
## being mistaken for a Glow Pool (which only rests). The Cave mouth's altar is always attuned.

const GLOW := Color(0.85, 0.8, 1.0)
const MOTES := 8
const RING_RADIUS := 14.0

var id := ""
var area := ""
## The id of the perk this altar sells ("" for none yet).
var perk := ""
var _feature := {}
var _progress
var _announce := Callable()
var _menu := Callable()
var _spin := 0.0

func setup(f: Dictionary, ctx: Dictionary) -> void:
	id = f.get("id", "")
	area = f.get("area", "")
	perk = str(f.get("perk", ""))
	_feature = f
	position = f["pos"]
	_progress = ctx.get("progress")
	_announce = ctx.get("announce", Callable())
	_menu = ctx.get("altar_menu", Callable())
	add_to_group("interactable")

func glow_color() -> Color:
	return GLOW

func is_attuned() -> bool:
	return _progress != null and _progress.is_attuned(id)

## "Cave mouth", "Grotto altar": the menu's title.
func title() -> String:
	return RebirthChoice.altar_name(_feature)

func _ready() -> void:
	if get_child_count() == 0:
		var s := Art.sprite("water_pool", 4.0)
		s.modulate = GLOW
		add_child(s)
		add_child(Art.light(GLOW, 0.8, 1.5))

func _process(delta: float) -> void:
	_spin += delta * 0.8
	queue_redraw()

func _draw() -> void:
	for i in MOTES:
		var a := _spin + TAU * float(i) / MOTES
		draw_circle(Vector2(cos(a), sin(a) * 0.45) * RING_RADIUS + Vector2(0, -6), 1.2, Color(GLOW.r, GLOW.g, GLOW.b, 0.9))

func prompt() -> String:
	return "altar" if is_attuned() else "attune"

func interact(_player: Node) -> void:
	if _menu.is_valid():
		_menu.call(self)  # the menu's attune row does the attuning
		return
	if is_attuned():
		if _progress != null:
			_progress.attune(id)  # the default altar is implicit; this records it harmlessly
		return
	if _progress != null:
		_progress.attune(id)
	announce_attuned()

## The audio cue and the line that follow attuning (the menu calls this when its attune row is taken).
func announce_attuned() -> void:
	EventBus.world_event.emit("pool_attuned", {"pos": global_position})
	if _announce.is_valid():
		_announce.call(id, "Your body will remember this place.")
