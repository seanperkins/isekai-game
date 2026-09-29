extends ThreadAbility
## Short thread: slows then holds an enemy, or swings from terrain up to 120 px away. Held on an enemy it keeps re-applying
## (a tether, 3 s at most); terrain first and nothing in reach stay the one-shot.

var _target: Node2D = null
var _strand: Line2D

func _init() -> void:
	rope_range = 120.0
	reel_speed = 60.0
	release_boost = 1.0
	max_channel = 3.0

func _ready() -> void:
	_strand = Line2D.new()
	_strand.top_level = true  # drawn in world space, like Player.rope_line
	Vfx.style_strand(_strand)
	_strand.visible = false
	add_child(_strand)

func can_channel() -> bool:
	return _first_contact()["target"] != null

func begin_channel() -> void:
	_target = _first_contact()["target"]
	_perform()  # the tier at once and the 0.35 s flash: exactly a tap
	_strand.visible = true

func channel_tick(_delta: float) -> bool:
	if _target == null or not is_instance_valid(_target):
		return false  # a non-predatable enemy is freed a tick after it dies
	if _target.has_method("can_be_hit") and not _target.can_be_hit():
		return false  # downed, dying or gone
	var from := actor.global_position
	if from.distance_to(_target.global_position) > rope_range + 20.0 or terrain_hit(from, _target.global_position) != null:
		return false
	_target.receive_thread(value())  # idempotent: the stun timer resets, the slow is a max
	return true

func end_channel(hard := false) -> void:
	_strand.visible = false
	_target = null
	super.end_channel(hard)

## The strand is redrawn after the physics step (like Player.rope_line), so it does not trail the slime by a tick. The base
## _process advances the cooldown, so this override must call it.
func _process(delta: float) -> void:
	super._process(delta)
	if _strand.visible and _target != null and is_instance_valid(_target):
		_strand.points = Vfx.sag_points(actor.global_position, _target.global_position)
