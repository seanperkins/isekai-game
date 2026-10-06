class_name VerbFlood
extends Node2D
## A flood (Flood): real deep water over the low ground round the caster, for a while. Whatever cannot swim in it is slowed, the caster too unless it has the swim
## skill; when its time is up it drains away. Group `verb_floods`.

const SLOW_SECONDS := 0.3

var caster: Node2D
var rect := Rect2()
var _left := 0.0
var _water: DeepWater

func launch(p_caster: Node2D, p_rect: Rect2, seconds: float) -> void:
	add_to_group("verb_floods")
	caster = p_caster
	rect = p_rect
	_left = seconds
	global_position = Vector2.ZERO
	_water = DeepWater.make(rect)
	add_child(_water)

func _physics_process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0 or not is_instance_valid(caster):
		if is_instance_valid(_water):
			_water.remove_from_group("deep_water")  # at once: queue_free waits for the end of the frame
		queue_free()
		return
	for n in get_tree().get_nodes_in_group("actors"):
		if n is Enemy and not n.def.swimmer and rect.has_point(n.global_position):
			n.slow_for(SLOW_SECONDS)
	var swims: bool = caster.get("skillset") != null and caster.skillset.has("swim")
	if not swims and caster.has_method("slow_for") and rect.has_point(caster.global_position):
		caster.slow_for(SLOW_SECONDS)  # it slows you too unless you swim
