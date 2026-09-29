class_name RebirthPool
extends Node2D
## A place to be reborn. Attune to it (Inspect) and it is unlocked for every future run; the death card
## then lets you choose it. A pale violet-white glow and a slow ring of motes keep it from being mistaken
## for a Glow Pool (which only rests). The Cave mouth's pool is always attuned.

const GLOW := Color(0.85, 0.8, 1.0)
const MOTES := 8
const RING_RADIUS := 14.0

var id := ""
var area := ""
var kit := {}
var _progress
var _announce := Callable()
var _spin := 0.0

func setup(f: Dictionary, ctx: Dictionary) -> void:
	id = f.get("id", "")
	area = f.get("area", "")
	kit = f.get("kit", {})
	position = f["pos"]
	_progress = ctx.get("progress")
	_announce = ctx.get("announce", Callable())
	add_to_group("interactable")

func glow_color() -> Color:
	return GLOW

func is_attuned() -> bool:
	return _progress != null and _progress.is_attuned(id)

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
	return "attuned" if is_attuned() else "attune"

func interact(_player: Node) -> void:
	if is_attuned():
		if _progress != null:
			_progress.attune(id)  # the default pool is implicit; this records it harmlessly
		return
	if _progress != null:
		_progress.attune(id)
	EventBus.world_event.emit("pool_attuned", {"pos": global_position})
	if _announce.is_valid():
		_announce.call(id, "Your body will remember this place.")
