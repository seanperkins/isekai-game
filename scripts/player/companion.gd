class_name Companion
extends Node2D
## A creature bonded to the player. It floats after its owner, strikes the foes it meets (as VerbAlly does) and is hurt by the active
## enemies that touch it; at 0 HP it is lost for good. Unlike a verb's ally it is a creature with its own HP, so it lives under the
## owner's parent and not in a room: it follows through room changes. Group `companions`, deliberately not `actors`: enemies do not
## chase it, they only hurt it by touching it.

signal died(companion: Companion)

const FOLLOW_GAP := 28.0
const FOLLOW_SPEED := 170.0
const SPEED := 90.0
const CHASE_RANGE := 160.0
const STRIKE_REACH := Vector2(18.0, 30.0)
const STRIKE_SECONDS := 0.9
const HURT_REACH := Vector2(14.0, 24.0)
const HURT_SECONDS := 1.0
## Said once as bond_formed {kind: long}: a Wolf's "long bond".
const LONG_BOND_SECONDS := 120.0
const TELEPORT_DISTANCE := 320.0
## A goblin's companion strikes one harder per GROWTH_PER dealings with its type, up to GROWTH_MAX.
const GROWTH_PER := 3
const GROWTH_MAX := 3
## The frame each shipped creature rests on, when it is drawn from single sprites.
const IDLE_FRAMES := {"bat": "bat_1", "toad": "toad_idle", "lizard": "lizard_1", "spider": "spider_crawl"}

var def: CreatureDef
var caster: Node2D
var hp := 1
var _age := 0.0
var _long_said := false
var _strike_in := 0.0
var _hurt_in := 0.0
var _dead := false

func launch(p_caster: Node2D, p_def: CreatureDef, at: Vector2) -> void:
	add_to_group("companions")
	caster = p_caster
	def = p_def
	global_position = at
	hp = int(def.stats.get("max_hp", 1))
	_build_look()

## What it strikes for: its own, and a goblin's grows with the lessons of its type.
func atk() -> int:
	var base := int(def.stats.get("atk", 1))
	var lessons = caster.get("lessons") if is_instance_valid(caster) else null
	if lessons != null:
		base += mini(GROWTH_MAX, floori(float(lessons.times(def.id)) / GROWTH_PER))
	return base

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not is_instance_valid(caster):
		queue_free()
		return
	_age += delta
	if not _long_said and _age >= LONG_BOND_SECONDS:
		_long_said = true
		caster.emit_deed(Deeds.BOND_FORMED, {"kind": "long", "creature": def.id})
	_strike_in = maxf(0.0, _strike_in - delta)
	_hurt_in = maxf(0.0, _hurt_in - delta)
	_take_contact_hit()
	if _dead:
		return
	if global_position.distance_to(caster.global_position) > TELEPORT_DISTANCE:
		global_position = caster.global_position + Vector2(-FOLLOW_GAP, 0.0)
	var foe := _nearest_foe()
	if foe == null:
		_follow(delta)
		return
	var d: Vector2 = foe.global_position - global_position
	if absf(d.x) <= STRIKE_REACH.x and absf(d.y) <= STRIKE_REACH.y:
		if _strike_in <= 0.0:
			foe.receive_hit(atk(), "physical", global_position, "")
			_strike_in = STRIKE_SECONDS
	else:
		global_position = global_position.move_toward(foe.global_position, SPEED * delta)

func _follow(delta: float) -> void:
	var to: Vector2 = caster.global_position - global_position
	var d := to.length()
	if d > FOLLOW_GAP:
		global_position += to / d * minf(FOLLOW_SPEED * delta, d - FOLLOW_GAP)

## The foes of the owner's other team within reach of the chase, awake and not stunned (a stunned creature is the owner's prey to eat or bond).
func _nearest_foe() -> Node2D:
	var best: Node2D = null
	var best_d := CHASE_RANGE
	for n in get_tree().get_nodes_in_group("actors"):
		if n == caster or not n.has_method("receive_hit") or n.get("team") == caster.get("team"):
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue
		var status = n.get("status")
		if status != null and status.state != EnemyStatus.ACTIVE:
			continue
		var d: float = n.global_position.distance_to(global_position)
		if d < best_d:
			best = n
			best_d = d
	return best

## An awake enemy in contact hits it, once per HURT_SECONDS whoever it is.
func _take_contact_hit() -> void:
	if _hurt_in > 0.0:
		return
	for n in get_tree().get_nodes_in_group("actors"):
		if not (n is Enemy) or n.dormant or n.status.state != EnemyStatus.ACTIVE:
			continue
		var d: Vector2 = n.global_position - global_position
		if absf(d.x) <= HURT_REACH.x and absf(d.y) <= HURT_REACH.y:
			hp -= int(n.def.stats.get("atk", 1))
			_hurt_in = HURT_SECONDS
			if hp <= 0:
				_dead = true
				died.emit(self)
				queue_free()
			return

## Its still when it has one, else the frame it rests on, else the placeholder every creature without art stands in as.
func _build_look() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	var sheet: SpriteSheet = null
	var frame := def.sprite_frame if def.sprite_frame != "" else "idle_1"
	if def.sprite_set != "":
		sheet = SpriteSheet.load_set(def.sprite_set)
	if sheet != null and sheet.has_frame(frame):
		sprite.texture = sheet.frame_texture(frame)
		sprite.scale = Vector2.ONE * def.sprite_size
		sprite.position.y = Enemy.BODY_BOTTOM - sheet.frame_size(frame).y * def.sprite_size / 2.0
	else:
		var look := def.wears if def.wears != "" else def.id
		var tex := Art.texture(IDLE_FRAMES.get(look, look))
		if tex == null and SpriteSheet.available(look):
			var own := SpriteSheet.load_set(look)
			if own != null and not own.frame_names().is_empty():
				tex = own.frame_texture(own.frame_names()[0])
		if tex == null:
			tex = Art.texture(IDLE_FRAMES[Enemy.PLACEHOLDER_LOOK])
		sprite.texture = tex
		sprite.position.y = Enemy.BODY_BOTTOM - tex.get_height() / 2.0
	sprite.modulate = def.sprite_tint
	add_child(sprite)
