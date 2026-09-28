class_name GlowPool
extends Node2D
## A pool of luminous water. Soak in it (Inspect) to refill HP and MP. It is not a checkpoint.

var id := ""
var _announce := Callable()

func setup(f: Dictionary, ctx: Dictionary) -> void:
	id = f.get("id", "")
	position = f["pos"]
	_announce = ctx.get("announce", Callable())
	add_to_group("interactable")

func _ready() -> void:
	if get_child_count() == 0:
		var s := Art.sprite("water_pool", 4.0)
		s.modulate = Color(0.6, 1.0, 0.9)
		add_child(s)
		add_child(Art.light(Color(0.4, 1.0, 0.9), 1.3, 1.4))

func prompt() -> String:
	return "soak"

func interact(player: Node) -> void:
	player.health.heal(player.health.max_hp)
	player.mana.restore(player.mana.max_mp)
	if _announce.is_valid():
		_announce.call(id, "Your body settles.")
