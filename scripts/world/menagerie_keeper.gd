class_name MenagerieKeeper
extends Node2D
## The Menagerie's keeper: every creature sleeps (dormant) until the player stands within WAKE_RANGE of it, and sleeps again when
## the player leaves. It also draws each creature's name on the floor under it.

const WAKE_RANGE := 140.0
const TAG_SIZE := 8
const TAG_WIDTH := 100.0

## [{"text", "pos"}], from Menagerie.tags.
var tags: Array = []

func _init() -> void:
	name = "MenagerieKeeper"
	z_index = 4  # over the floor the names are drawn on

func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	for n in get_tree().get_nodes_in_group("actors"):
		if n is Enemy:
			var asleep: bool = n.global_position.distance_to(player.global_position) > WAKE_RANGE
			if n.dormant != asleep:
				n.dormant = asleep

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for t in tags:
		draw_string(font, t["pos"] - Vector2(TAG_WIDTH / 2.0, 0.0), t["text"], HORIZONTAL_ALIGNMENT_CENTER, TAG_WIDTH, TAG_SIZE, Color(0.9, 0.9, 0.85))
