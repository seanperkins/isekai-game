class_name Enemy
extends CharacterBody2D
## A creature built from its CreatureDef: stats, its own skills, and its behaviour.
## Every enemy needs line of sight to notice you and forgets you ALERT_MEMORY seconds after
## losing you; walkers turn at ledges and walls; every attack is telegraphed:
##   swoop (bats):     hover above you, flash, dive at where you were, climb back
##   charger (lizard): stop and flick, charge, then rest (hit it from behind)
##   stomper (drake):  rear, slam the ground in a zone around it (jump to dodge), then rest
##   spitter (toad):   puff up, then lob a poison glob in an arc
##   dropper (spider): hang until you pass under, then drop and walk
## Enemies never emit gameplay events (Health has no emitter). They do emit audio-only world
## events (EventBus.world_event), which nothing counts.

## Reaches 0 HP. The game awards the player XP for it (a direct signal, not an EventBus event).
signal downed(def: CreatureDef)
## The corpse's eat window ran out with nobody eating it.
signal corpse_left(def: CreatureDef)

const GRAVITY := 900.0
const BASE_SPEED := 60.0
const CHASE_RANGE := 160.0
const CONTACT_RANGE := 18.0  # centre distance, for a player with no body box (test stubs)
## The enemy's collision box, and the slack that lets two touching boxes count as in contact.
const BODY_SIZE := Vector2(16, 12)
const CONTACT_MARGIN := 2.0
const PATROL_RANGE := 48.0
const SPIT_RANGE := 90.0
const SPIT_COOLDOWN := 5.0
const SPIT_TICK := 1
const SPIT_SECONDS := 3.0
const SLOW_SECONDS := 2.0
## Seconds an enemy keeps hunting after it last saw you.
const ALERT_MEMORY := 2.0
## A pack creature that sees you alerts every other of its kind within this many px, with no line of sight needed.
const PACK_RADIUS := 240.0
## Walkers probe this far ahead and this far down for the ground before stepping on.
const LEDGE_PROBE := 10.0
const LEDGE_DEPTH := 16.0
const SPIT_WINDUP := 0.4
const CHARGE_RANGE := 120.0
const CHARGE_LEVEL := 24.0
const CHARGE_WINDUP := 0.5
const CHARGE_SECONDS := 0.6
const CHARGE_REST := 1.0
const CHARGE_MULT := 3.0
## The stone drake rears for STOMP_WINDUP and slams: a player standing on the floor within STOMP_RANGE across and STOMP_LEVEL up or
## down is hit (jump to dodge it). It rests STOMP_REST afterwards. One zone triggers the windup and decides the hit.
const STOMP_RANGE := 110.0
const STOMP_LEVEL := 40.0
const STOMP_WINDUP := 0.7
const STOMP_REST := 1.4
## Bats hover this high over you for HOVER_SECONDS (+ up to HOVER_JITTER, per bat).
const HOVER_HEIGHT := 60.0
const HOVER_SECONDS := 0.8
const HOVER_JITTER := 0.4
const WARN_SECONDS := 0.3
const DIVE_SECONDS := 0.6
const DIVE_MULT := 2.2
const CLIMB_SECONDS := 0.8
const TELEGRAPH_TINT := Color(1.0, 0.8, 0.45)
## Ground enemies do not turn while the player is this close, so jumping over one opens
## a window to hit it from behind (the lizard is only stunned from behind).
const TURN_LOCK_RANGE := 32.0
const ANIM_SECONDS := 0.25
const SPIT_POSE_SECONDS := 0.4
const BODY_BOTTOM := 6.0
const STUNNED_TINT := Color(0.6, 0.6, 0.85)
## How long a non-lethal hit flinches (the hurt frame).
const HURT_SECONDS := 0.25
const CLIPS := "res://data/enemy_clips.json"
## The clips of the twins' animated forms: {form id: {state: {frames, fps, loop}}} (tools/art/blender/goblin_tree.py writes it). A test points
## it at a fixture.
static var form_clips_path := "res://data/form_clips.json"
## An animated twin runs (plays its run clip) when it is charging or moving faster than its walking speed by this much.
const RUN_RATIO := 1.35
## A run clip is built for this many times the walk's speed (tools/art/blender: the goblin's WALK_SPEED_RUN), and a walk or a run plays at
## the creature's real speed relative to that, within these limits.
const RUN_SPEED := 1.9
const FORM_RATE_RANGE := Vector2(0.2, 4.0)
static var _form_clip_cache := {}  # path -> parsed file
## The Bog Lizardman's spear: how far, how level and how often it throws (the toad's are SPIT_*; Spear.SPEED is its speed).
const SPEAR_RANGE := 140.0
const SPEAR_LEVEL := 40.0
const SPEAR_COOLDOWN := 3.0
## The spore moth drops a puff every PUFF_INTERVAL while the player is within PUFF_RANGE, flashing PUFF_WINDUP first.
const PUFF_INTERVAL := 3.0
const PUFF_WINDUP := 0.4
const PUFF_RANGE := 320.0
## The vine snake coils when prey passes under it, lunges along a line, and retreats to its anchor.
const LUNGE_TRIGGER_X := 40.0
const LUNGE_TRIGGER_Y := 110.0
const COIL_SECONDS := 0.5
const LUNGE_SECONDS := 0.3
const LUNGE_SPEED := 300.0
const LUNGE_REACH := 80.0
const RETREAT_SPEED := 100.0

## A verb is cast at a player this close, after a telegraphed windup, then the enemy holds still for a moment. Its damage is held to
## VERB_POWER_CAP times its ATK. A dash keeps its speed for IMPULSE_SECONDS.
const VERB_RANGE := 150.0
const VERB_WINDUP := 0.35
const VERB_RECOVER := 0.3
const VERB_POWER_CAP := 2
const IMPULSE_SECONDS := 0.25
## What a creature whose art is missing wears, so it is never invisible.
const PLACEHOLDER_LOOK := "lizard"

var def: CreatureDef
var stats: Stats
var health: Health
var status := EnemyStatus.new()
var capabilities := {}
var team := "enemy"
var facing := -1
var _home_x := 0.0
var _on_ceiling := false
var _spit_damage := 0
var _spit_cd := 0.0
## The verb a twin casts (null for a creature with none, or one an enemy cannot cast) and how often it has.
## What the last blow was, for the deeds a kill earns (DeedTags): {"from_behind", "distance", "damage_type", "cause", "marked", "alert",
## "fleeing"}; empty until something hits it.
var last_blow := {}
## Set when the player appraises it: an appraised enemy counts as marked.
var appraised := false
## A goblin has picked this creature's pocket: it is tried once.
var robbed := false
## The goblin has been paid for this creature (it learned from it, downed or eaten): it pays once however it ends.
var lesson_paid := false
var _blow_from_behind := false
var verb_casts := 0
var _verb: Ability
var _verb_kind := ""
var _verb_state := ""  # "", windup or recover
var _verb_t := 0.0
var _impulse_x := 0.0
var _impulse_t := 0.0
var _ward_t := 0.0
var _slow := 0.0
## A verb's root (Bind): no AI, no contact hit, no eat, for this long. Not a stun, so it works on an enemy that cannot be stunned.
var _root := 0.0
## Set only by a thread, never by a zone or a tackle, so the webs on the sprite mean what happened to it.
var _web_slow := 0.0
var _web_hold := false
var _web: WebCover
var _sprite: Sprite2D
## "<room id>:<index>" of the room spawn that made this creature (empty for one made by hand); first-time XP is per spawn.
var spawn_key := ""
## Set false before adding to the tree to draw the old single sprites instead of the creature's own frames.
var use_sheet := true
## A dormant enemy is frozen where it spawned: no gravity, movement or AI, no contact damage, and it refuses every blow, stun,
## thread, slow and bite (a boss before its arena wakes it). The setter freezes the status and redraws the resting frame, so it is
## right whether it is set before or after the enemy enters the tree.
var dormant := false:
	set(v):
		dormant = v
		status.frozen = v
		if v:
			velocity = Vector2.ZERO
		_update_visual()
## A hunting enemy is always alert: it ignores CHASE_RANGE and line of sight (a boss in its own arena).
var hunting := false
var _sheet: SpriteSheet
var _still: SpriteSheet  # the sheet of a creature that is one still (a twin), null for the rest
var _form_sheet: SpriteSheet  # the animated sheet of a twin's form (assets/sheets/anim_<form>), null when it has none
var _form_hurt_seen := 0.0    # the last flinch timer it drew, so a fresh blow can restart the flinch
var _authored_speed := 0.0    # the walking speed its clips were built for
var _animator: SlimeAnimator
var _shapes: SlimeShapes
var _hurt_t := 0.0
var _anim_t := 0.0
var _alert := 0.0
## Which behaviour this creature has, resolved once in setup() from what its def and skills say (the precedence the
## old _act chain used): the vine snake by id, then a ceiling walker, a drifter, a flier or a swimmer (the eels are swoopers),
## an armored charger or a `charges` creature, a spitter.
enum Kind { WALKER, CHARGER, SPITTER, SWOOPER, DROPPER, DRIFTER, SNAKE }
var kind := Kind.WALKER
## The one live behaviour state, its timer and its aim. Tokens per kind: swooper idle/hover/warn/dive/climb; charger and
## snake ""/windup/charge/rest (a stomper never writes `charge`: its windup ends in the slam, then rest); spitter ""/puff; drifter ""/flash; walker and dropper never write it.
var _state := ""
var _state_t := 0.0
var _aim := Vector2.ZERO
## Why the last blow landed ("tackle", "poison", "blade", "other") and where it came from.
var _cause := ""
var _killed_from := Vector2.INF
var _rng := RandomNumberGenerator.new()
var _home_y := 0.0
var _anchor := Vector2.ZERO
var _puff_t := PUFF_INTERVAL
## The animation state _draw_sheet_frame last chose (EnemyState.pick), "" for a creature with no sheet.
var _anim_state := ""
## The water rect a swimmer lives in, resolved on the first physics frame (a spawn's position and room are not set in setup).
var _home_water: DeepWater
var _water_resolved := false

func setup(p_def: CreatureDef, skill_defs_by_id: Dictionary) -> void:
	def = p_def
	stats = Stats.new(def.stats)
	for s in def.skills:
		var sd: SkillDef = skill_defs_by_id.get(s["id"])
		if sd == null:
			continue
		var lv := int(s["level"])
		stats.set_modifiers(sd.id, SkillEffects.stat_modifiers(sd, lv))
		capabilities.merge(SkillEffects.capabilities(sd, lv), true)
		if sd.id == "poison_spit":
			_spit_damage = int(SkillEffects.value_at(sd.effects[0], lv))
	health = Health.new(stats.get_stat("max_hp"))  # no emit_event: actor boundary
	health.died.connect(_on_died)
	_verb = _build_verb(skill_defs_by_id.get(def.verb))
	_on_ceiling = capabilities.has("ceiling_walk")
	kind = _resolve_kind()
	_state = "idle" if kind == Kind.SWOOPER else ""
	add_to_group("actors")
	add_to_group("predatable")
	add_to_group("inspectable")

## The verb as an ability this enemy casts, or null when the creature has none or its kind is not one an enemy casts.
func _build_verb(sd: SkillDef) -> Ability:
	if sd == null:
		return null
	var spec := SkillEffects.active_spec(sd)
	if not VerbKinds.ENEMY_KINDS.has(spec.get("kind", "")):
		return null
	var values: Array = []
	for e in sd.effects:
		if e.get("kind", "") == "active":
			values = e.get("values", [])
	var ability: Ability = load(SkillEffects.active_scene(sd)).instantiate()
	ability.spec = spec
	ability.skill_id = sd.id
	ability.setup(self, values, 1)
	ability.power_cap = VERB_POWER_CAP * int(stats.get_stat("atk"))
	_verb_kind = spec["kind"]
	return ability

## Reseeds the enemy's own RNG (the bat's hover jitter): _ready seeds it from the instance id.
func seed_rng(n: int) -> void:
	_rng.seed = n

## The animation state the enemy is playing (the EnemyState.pick result), "" for a creature with no sheet.
func anim_state() -> String:
	return _anim_state

func _resolve_kind() -> Kind:
	if def.id == Sources.VINE_SNAKE:
		return Kind.SNAKE
	if _on_ceiling:
		return Kind.DROPPER
	if def.drifter:
		return Kind.DRIFTER
	if capabilities.has("flight") or def.swimmer:
		return Kind.SWOOPER
	if def.armored_charger or def.charges:
		return Kind.CHARGER
	if _spit_damage > 0 or def.projectile == "spear":
		return Kind.SPITTER
	return Kind.WALKER

func _ready() -> void:
	_home_x = global_position.x
	_home_y = global_position.y
	_anchor = global_position
	_rng.seed = get_instance_id()  # each bat keeps its own rhythm
	if get_child_count() == 0:
		_build_body()
	if _verb != null:
		add_child(_verb)  # after the body: a node here would make _build_body think the scene gave it one

static func cause_for(damage_type: String) -> String:
	return "poison" if damage_type == "poison" else "other"

func _untouchable() -> bool:
	return dormant or _ward_t > 0.0 or status.state == EnemyStatus.DOWNED or status.state == EnemyStatus.GONE or status.state == EnemyStatus.DYING

## `cause` names the blow for the death effect; it is stored before the hit because _on_died() takes
## no arguments.
## `ignore_def` skips the enemy's DEF (a weak-point hit).
func receive_hit(raw: int, damage_type: String, from: Vector2 = Vector2.INF, cause: String = "", ignore_def := false) -> void:
	if _untouchable():
		return
	EventBus.world_event.emit("enemy_hit", {"pos": global_position})
	_record_blow(damage_type, from, cause)
	_cause = cause if cause != "" else cause_for(damage_type)
	_killed_from = from
	health.take_hit(Damage.hit(raw, damage_type, 0 if ignore_def else stats.get_stat("def"), 0, 0), damage_type)
	if status.state != EnemyStatus.DYING:
		_hurt_t = HURT_SECONDS

func _record_blow(damage_type: String, from: Vector2, cause: String) -> void:
	last_blow = {"from_behind": _blow_from_behind, "distance": global_position.distance_to(from) if from != Vector2.INF else 0.0,
		"damage_type": damage_type, "cause": cause, "marked": has_meta("verb_marked") or appraised, "alert": is_alert(), "fleeing": _is_fleeing()}
	_blow_from_behind = false

## Moving away from the player faster than DeedTags.FLEE_SPEED.
func _is_fleeing() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	if player == null or absf(velocity.x) <= DeedTags.FLEE_SPEED:
		return false
	return signf(velocity.x) == signf(global_position.x - player.global_position.x)

## An armored front has a weak point behind it: a tackle from behind, or on an armored enemy that is already stunned, ignores
## DEF and does double. (A base slime has ATK 1, so against DEF 2 a plain hit floors at 1: a Mushroom Crab would take ten.)
## Enemies without armor are unchanged: a backstab still stuns them for the eat.
const WEAK_POINT_MULT := 2

## Returns true when the tackle stunned or downed this enemy (the player emits stunned_enemy).
func receive_tackle(atk: int, from_behind: bool, from: Vector2 = Vector2.INF) -> bool:
	if _untouchable():
		return false
	var weak := def.armored_charger and (from_behind or status.state == EnemyStatus.STUNNED)
	if weak:
		EventBus.game_event.emit(Deeds.GUARD_BROKEN, {"source": def.id})  # a tackle is the player's: the rules take it from the bus
	_blow_from_behind = from_behind
	receive_hit(atk * WEAK_POINT_MULT if weak else atk, "physical", from, "tackle", weak)
	if status.state == EnemyStatus.DYING or status.state == EnemyStatus.DOWNED:
		return true
	if not def.predatable:
		return false  # the serpent can't be stunned
	if def.armored_charger and not from_behind:
		return false  # armored front
	status.stun()
	return true

func receive_thread(tier: int) -> void:
	if _untouchable():
		return
	if tier >= 2 and def.predatable:
		status.stun()
		_web_hold = true
	else:
		slow_for(SLOW_SECONDS)
		_web_slow = SLOW_SECONDS

## The one writer for the slow: a thread (Sticky Thread, Swing Thread) and every player zone (Spore Cloud, Binding Web's
## patch, Healing Spores, Puffball) call it.
func slow_for(seconds: float) -> void:
	if dormant:
		return
	_slow = maxf(_slow, seconds)

func root_for(seconds: float) -> void:
	if _untouchable():
		return
	_root = maxf(_root, seconds)

func is_rooted() -> bool:
	return _root > 0.0

func can_be_predated() -> bool:
	return not dormant and _root <= 0.0 and def.predatable and status.predatable()

## Whether a spider can web it into a cocoon now: alive, awake and stunned, and one that can be eaten.
func can_be_cocooned() -> bool:
	return not dormant and def.predatable and status.state == EnemyStatus.STUNNED

## Whether a goblin can pick its pocket now: alive and awake (stunned will do), one that can be eaten, not tried yet, with something it could leave.
func can_be_robbed() -> bool:
	return not dormant and not robbed and def.predatable and not Drops.for_def(def).is_empty() \
		and (status.state == EnemyStatus.ACTIVE or status.state == EnemyStatus.STUNNED)

## Whether a wolf or a goblin can bond with it now: alive, awake and stunned, and it accepts a bond at all (CreatureDef.bonds).
func can_be_bonded() -> bool:
	return not dormant and not def.bonds.is_empty() and status.state == EnemyStatus.STUNNED

func set_held(v: bool) -> void:
	status.held = v

func consume() -> CreatureDef:
	status.consume()
	queue_free()
	return def

## Ends the death effect: the creature lies downed and its 5 s eat window starts.
func finish_dying() -> void:
	if status.state == EnemyStatus.DYING:
		status.down()

func _on_died() -> void:
	EventBus.world_event.emit("enemy_died", {"id": def.id, "pos": global_position})
	if def.predatable:
		status.die()  # the death effect ends in down() and starts the eat window
		_become_clippable()
		_clear_inactive()
		if kind == Kind.SWOOPER:
			_state = "idle"  # a bat killed in warn must not flash its warning while it lies downed
		_start_death_fx()
	else:
		status.consume()  # Plan 3 turns the serpent's death into victory
	downed.emit(def)

## A corpse does not block anyone: nothing collides with it any more, and it ignores the bodies that
## are here so it does not get shoved by them. It still rests on the floor.
func _become_clippable() -> void:
	collision_layer = 0
	for n in get_tree().get_nodes_in_group("actors"):
		if n != self and n is CollisionObject2D:
			add_collision_exception_with(n)

func _start_death_fx() -> void:
	var fx := DeathFx.new()
	add_child(fx)
	fx.finished.connect(finish_dying)
	fx.begin(self, _cause, _killed_from)

func _physics_process(delta: float) -> void:
	if dormant:
		velocity = Vector2.ZERO
		return
	var was_downed := status.state == EnemyStatus.DOWNED
	status.update(delta)
	_anim_t += delta
	if status.state == EnemyStatus.GONE:
		if was_downed:
			corpse_left.emit(def)
		queue_free()
		return
	_spit_cd = maxf(0.0, _spit_cd - delta)
	_slow = maxf(0.0, _slow - delta)
	_root = maxf(0.0, _root - delta)
	_ward_t = maxf(0.0, _ward_t - delta)
	_impulse_t = maxf(0.0, _impulse_t - delta)
	_web_slow = maxf(0.0, _web_slow - delta)
	var player: Node2D = get_tree().get_first_node_in_group("player")
	var active := status.state == EnemyStatus.ACTIVE and _root <= 0.0
	if def.swimmer and not _water_resolved:
		_home_water = DeepWater.at(get_tree(), global_position)
		_water_resolved = true
	if active and player != null:
		_sense(player, delta)
		if def.swimmer and _home_water == null:
			velocity = Vector2.ZERO  # no water: nothing to swim in (lint's swimmer_dry reports it)
		else:
			_act(player, delta)
	elif status.state != EnemyStatus.DYING:  # a death effect owns the body while it plays
		velocity.x = 0.0
		_clear_inactive()
	if active and _impulse_t > 0.0:
		velocity.x = _impulse_x  # a dash carries over the walk
	var stunned := status.state == EnemyStatus.STUNNED
	var no_gravity := false
	match kind:
		Kind.SWOOPER:
			no_gravity = active  # a stunned bat falls
		Kind.DRIFTER:
			no_gravity = active or stunned
			if stunned:
				velocity.y = 0.0  # a stunned moth holds its height
		Kind.SNAKE:
			no_gravity = _on_ceiling and (active or stunned)
			if no_gravity and stunned:
				velocity = Vector2.ZERO  # a stunned snake stays on its tether
		Kind.DROPPER:
			no_gravity = _on_ceiling and active  # a stunned hanging spider falls
	if not no_gravity:
		velocity.y += GRAVITY * delta
	move_and_slide()
	if def.swimmer and _home_water != null:
		_confine()
	if active and player != null and is_touching(player):
		player.receive_hit(stats.get_stat("atk"), def.contact_type, global_position, def.id)
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_update_visual(delta)

## A stun, a down or a missing player drops whatever was pending, except a bat's swoop (it resumes with its remaining
## time and its RNG stream). Never touches the timer or the aim.
func _clear_inactive() -> void:
	_verb_state = ""  # a stun or a death drops a verb that was winding up
	if kind != Kind.SWOOPER:
		_state = ""

## True when this enemy's box touches the player's. The bodies block each other, so they can only
## touch, never overlap: the margin bridges that. A player with no body box (a test stub) falls back
## to the old centre distance.
func is_touching(player: Node2D) -> bool:
	if player.has_method("hurt_polygon"):
		return ShapeHit.overlap(hurt_polygon(), player.hurt_polygon(), CONTACT_MARGIN)
	if player.has_method("body_rect"):
		var mine := Rect2(global_position - BODY_SIZE / 2.0, BODY_SIZE).grow(CONTACT_MARGIN)
		return mine.intersects(player.body_rect())
	return global_position.distance_to(player.global_position) <= CONTACT_RANGE

## Where this creature can be hit and where it hurts on contact: the current frame's traced shape
## (global points), or its box when it has no sheet.
func hurt_polygon() -> PackedVector2Array:
	if _shapes != null and _shapes.hurt_poly.polygon.size() >= 3:
		return ShapeHit.moved(_shapes.hurt_poly.polygon, _shapes.global_position)
	return ShapeHit.rect_points(Rect2(global_position - BODY_SIZE / 2.0, BODY_SIZE))

## False for a creature that is dying, downed or gone: blows and tackles do nothing to it, so a target
## selector must look past it to a living one.
## Alive and able to fight: not downed, dying or gone. A room is cleared when none is left.
func is_threat() -> bool:
	return status.state == EnemyStatus.ACTIVE or status.state == EnemyStatus.STUNNED

func can_be_hit() -> bool:
	return not _untouchable()

## The two halves a blade kill leaves as its corpse, or null (any other death leaves the whole body).
func cut_corpse() -> Node2D:
	return get_node_or_null("CutCorpse") as Node2D

func is_alert() -> bool:
	return _alert > 0.0

## "", windup, charge or rest for a charger or a snake; "" for every other kind.
func charge_state() -> String:
	return _state if kind == Kind.CHARGER or kind == Kind.SNAKE else ""

## idle, hover, warn, dive or climb for a bat; "idle" for every other kind.
func swoop_state() -> String:
	return _state if kind == Kind.SWOOPER else "idle"

## True when no rock lies between this enemy and `target`.
func can_see(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), target.global_position + Vector2(0, -4))
	var skip: Array[RID] = []
	for n in get_tree().get_nodes_in_group("actors"):
		if n is CollisionObject2D:
			skip.append(n.get_rid())
	if target is CollisionObject2D:
		skip.append(target.get_rid())
	query.exclude = skip
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _sense(player: Node2D, delta: float) -> void:
	var sees := hunting or (global_position.distance_to(player.global_position) < CHASE_RANGE and can_see(player))
	if sees and def.swimmer and _home_water != null and not _home_water.world_rect().has_point(player.global_position):
		sees = false  # an eel is stirred only by a player in its own water
	if sees:
		_alert = ALERT_MEMORY
		if def.pack:
			_share_alert()
	else:
		_alert = maxf(0.0, _alert - delta)

## The howl: wakes every other pack creature of this kind near this one. Only sight calls it, so a creature woken here never wakes
## another, and a pack does not chain across a level. `actors` also holds the player, the shortcut switch and test stubs.
func _share_alert() -> void:
	for n in get_tree().get_nodes_in_group("actors"):
		if n is Enemy and n != self and n.def.pack and n.def.id == def.id and global_position.distance_to(n.global_position) <= PACK_RADIUS:
			n._alert = ALERT_MEMORY

## Holds a swimmer inside its water rect (shrunk by its half body): the position is clamped, the clamped velocity component is
## zeroed (a stunned eel's fall does not keep growing against a rect bottom that is not floor) and facing turns inward, which
## the drifter turns on.
func _confine() -> void:
	var half := BODY_SIZE / 2.0
	var box := _home_water.world_rect()
	var lo := box.position + half
	var hi := box.end - half
	if hi.x < lo.x or hi.y < lo.y:
		global_position = box.get_center()
		return
	var p := global_position
	var c := Vector2(clampf(p.x, lo.x, hi.x), clampf(p.y, lo.y, hi.y))
	if c.x != p.x:
		velocity.x = 0.0
		facing = 1 if p.x < lo.x else -1
	if c.y != p.y:
		velocity.y = 0.0
	global_position = c

## Which sprite to draw for this creature right now. All sheets face right.
## The creature whose frames and clips this one draws: the one it `wears`, the placeholder when its own still is missing, else itself.
func _look_id() -> String:
	if def.wears != "":
		return def.wears
	if def.sprite_set != "" and _still == null:
		return PLACEHOLDER_LOOK
	return def.id

func _still_frame() -> String:
	return def.sprite_frame if def.sprite_frame != "" else "idle_1"

## The sheet of the still this creature wears, or null when it has none or the sheet or frame is missing.
func _load_still() -> SpriteSheet:
	if def.sprite_set == "":
		return null
	var sheet := SpriteSheet.load_set(def.sprite_set)
	return sheet if sheet != null and sheet.has_frame(_still_frame()) else null

func frame_name() -> String:
	var alternate := int(_anim_t / ANIM_SECONDS) % 2 == 1
	match _look_id():
		"bat":
			return "bat_2" if alternate else "bat_1"
		"toad":
			return "toad_spit" if _state == "puff" or _spit_cd > _spit_cooldown() - SPIT_POSE_SECONDS else "toad_idle"
		"lizard":
			return "lizard_2" if alternate and absf(velocity.x) > 1.0 else "lizard_1"
		"spider":
			return "spider_hang" if _on_ceiling else "spider_crawl"
	return _look_id()

func _update_visual(delta: float = 0.0) -> void:
	if _sprite == null:
		return
	if status.state != EnemyStatus.DYING:  # the death effect owns the sprite
		_draw_creature(delta)
	else:
		_sprite.rotation = 0.0  # upright for it: a still dies from the pose it stood in
	_update_web()  # after the draw, so it fits this frame

func _draw_creature(delta: float) -> void:
	if _form_sheet != null:
		_draw_form_frame(delta)
	elif _still != null:
		_draw_still()
	elif _sheet != null:
		_draw_sheet_frame(delta)
	else:
		Art.set_frame(_sprite, frame_name(), BODY_BOTTOM)
		_sprite.flip_h = facing < 0
		_sprite.flip_v = status.state == EnemyStatus.DOWNED
	if status.state == EnemyStatus.STUNNED:
		_sprite.modulate = STUNNED_TINT
	elif telegraphing() and int(_anim_t / 0.08) % 2 == 0:
		_sprite.modulate = TELEGRAPH_TINT
	else:
		_sprite.modulate = def.sprite_tint

## A still: one frame at the creature's size, turned with it. It has no frames, so it is moved: it breathes (its height squashes by
## STILL_BREATH either way every STILL_BREATH_SECONDS, its feet fixed), hops STILL_HOP px and leans STILL_LEAN radians towards where it faces
## while it walks, and holds rigid when it is stunned or down. Its hurt box stays the body's.
const STILL_BREATH_SECONDS := 1.8
const STILL_BREATH := 0.03
const STILL_HOP := 3.0
const STILL_HOP_RATE := 11.0
const STILL_LEAN := 0.06

func _draw_still() -> void:
	var frame := _still_frame()
	var size := def.sprite_size
	var frame_size := _still.frame_size(frame)
	_sprite.texture = _still.frame_texture(frame)
	_sprite.flip_h = facing < 0
	_sprite.flip_v = status.state == EnemyStatus.DOWNED
	var scale_y := size
	var hop := 0.0
	var lean := 0.0
	if status.state == EnemyStatus.ACTIVE:
		var phase := float(hash(spawn_key if spawn_key != "" else str(get_instance_id())) % 628) / 100.0  # a crowd does not breathe in step
		scale_y = size * (1.0 + sin(_anim_t * TAU / STILL_BREATH_SECONDS + phase) * STILL_BREATH)
		if absf(velocity.x) > 1.0:
			var step := sin(_anim_t * STILL_HOP_RATE)
			hop = absf(step) * STILL_HOP
			lean = (1.0 if facing >= 0 else -1.0) * STILL_LEAN * step * step
	_sprite.scale = Vector2(size, scale_y)
	_sprite.rotation = lean
	# The still turns about its feet: the sprite is centred, so its centre sits where the feet, the lean and the hop put it, and the corner the
	# lean lowers is lifted back to the floor.
	var height := frame_size.y * scale_y
	var feet_y := BODY_BOTTOM - hop - frame_size.x * size * absf(sin(lean)) / 2.0
	_sprite.position = Vector2(sin(lean) * height / 2.0, feet_y - cos(lean) * height / 2.0)

## A twin whose form has its own animated sheet: the frame of the clip its state picks (EnemyState.pick_form), at the creature's size, lit by the
## room's lights when the sheet has normals (a creature facing left gets mirrored normals), and turned with it. A clip that is a one-shot (a
## windup, a recover, a hurt) plays out before the creature goes back to walking or standing; a hit, a stun or a new verb state interrupts it.
## Its hurt box stays the body's, as a still's does.
func _draw_form_frame(delta: float) -> void:
	if _hurt_t > _form_hurt_seen:
		_animator.restart()  # a new blow starts the flinch again, even in the middle of one
	_form_hurt_seen = _hurt_t
	if not dormant:
		_animator.advance(delta * _form_rate())  # first, so a one-shot that has just finished no longer holds the creature
	var state := EnemyState.pick_form(_animator.clips, EnemyStatus.ACTIVE if dormant else status.state, "" if dormant else _verb_state,
		absf(velocity.x) > 1.0 and not dormant, _hurt_t > 0.0 and not dormant, charge_state() == "charge" or absf(velocity.x) > _walk_speed() * RUN_RATIO)
	if _animator.locked() and EnemyState.is_locomotion(state) and not dormant:
		state = _animator.state()
	_anim_state = state
	_animator.play(state)
	_show_form_frame(_animator.frame())

## The speed its walk clip was built for: the creature's own at the start (tools/art/blender sizing.speed_of), not what buffs and slows make of it now, so a
## faster creature plays its walk faster instead of cancelling it out.
func _walk_speed() -> float:
	return _authored_speed if _authored_speed > 0.0 else BASE_SPEED * stats.get_stat("spd") / 100.0

## How fast to play the clip: a walk or a run plays as fast as the creature is really going (so a planted foot stays planted when it patrols at half
## speed, is slowed, or charges), everything else at its own pace.
func _form_rate() -> float:
	var speed := absf(velocity.x)
	match _animator.state():
		"walk":
			return clampf(speed / _walk_speed(), FORM_RATE_RANGE.x, FORM_RATE_RANGE.y) if speed > 1.0 else 1.0
		"run":
			return clampf(speed / (_walk_speed() * RUN_SPEED), FORM_RATE_RANGE.x, FORM_RATE_RANGE.y) if speed > 1.0 else 1.0
	return 1.0

func _show_form_frame(frame: String) -> void:
	var size := def.sprite_size
	_form_sheet.draw_on(_sprite, frame, facing < 0)
	_sprite.flip_v = false
	_sprite.rotation = 0.0
	_sprite.scale = Vector2(size, size)
	_sprite.position = Vector2(0.0, BODY_BOTTOM - _form_sheet.frame_size(frame).y * size / 2.0)

## Whether this creature has an animated clip of that name (a twin whose form has been animated).
func has_form_clip(state: String) -> bool:
	return _form_sheet != null and _animator != null and _animator.clips.has(state)

## How long a clip plays, in seconds (0 when there is none).
func form_clip_seconds(state: String) -> float:
	if not has_form_clip(state):
		return 0.0
	var clip: Dictionary = _animator.clips[state]
	return float((clip["frames"] as Array).size()) / float(clip["fps"])

## Draw a clip at a time since it began (a one-shot holds its last frame): for an effect that plays the creature's own animation, like its death.
func draw_form_clip(state: String, time: float) -> void:
	if not has_form_clip(state):
		return
	var clip: Dictionary = _animator.clips[state]
	var frames: Array = clip["frames"]
	_show_form_frame(frames[clampi(int(time * float(clip["fps"])), 0, frames.size() - 1)])

## Strands while a thread slows it, the cocoon while a thread holds it, nothing once either ends or it is down.
func _update_web() -> void:
	var stunned := status.state == EnemyStatus.STUNNED
	if not stunned:
		_web_hold = false  # the hold ended (or a later stun is not this thread's)
	var alive := (status.state == EnemyStatus.ACTIVE or stunned) and _sprite.visible  # an eat hides the sprite and draws its own copy
	if alive and _web_hold:
		_web.show_over(_sprite, true)
	elif alive and _web_slow > 0.0:
		_web.show_over(_sprite, false)
	else:
		_web.visible = false

func _draw_sheet_frame(delta: float) -> void:
	var state := EnemyState.pick(_look_id(), status.state, charge_state(), swoop_state(), _state == "puff",
		_spit_cd > _spit_cooldown() - SPIT_POSE_SECONDS, _on_ceiling, is_on_floor(), absf(velocity.x) > 1.0, _hurt_t > 0.0)
	if dormant:  # the resting pose whatever it was doing, and it does not animate
		state = EnemyState.pick(_look_id(), EnemyStatus.ACTIVE, "", "idle", false, false, _on_ceiling, true, false, false)
	_anim_state = state
	_animator.play(state)
	if not dormant:
		_animator.advance(delta * (_sheet_rate(state) if _sheet.has_normals() else 1.0))
	var frame := _animator.frame()
	_sheet.draw_on(_sprite, frame, facing < 0)
	_sprite.position.y = BODY_BOTTOM - _sheet.frame_size(frame).y / 2.0
	_sprite.flip_v = false
	_shapes.refresh(_sheet, frame, facing < 0)

## How fast to play a rendered sheet's walk, run or charge: as fast as the creature really goes against the speed the clip was built for (a charge is built for
## CHARGE_MULT times the walk), so a planted foot does not slide when it patrols at half speed or is slowed. A drawn sheet plays at its own pace.
func _sheet_rate(state: String) -> float:
	var speed := absf(velocity.x)
	if speed <= 1.0:
		return 1.0
	match state:
		"walk", "run", "crawl":
			return clampf(speed / _walk_speed(), FORM_RATE_RANGE.x, FORM_RATE_RANGE.y)
		"charge":
			return clampf(speed / (_walk_speed() * CHARGE_MULT), FORM_RATE_RANGE.x, FORM_RATE_RANGE.y)
	return 1.0

func telegraphing() -> bool:
	if _verb_state == "windup":
		return true
	match kind:
		Kind.CHARGER, Kind.SNAKE:
			return _state == "windup"
		Kind.SWOOPER:
			return _state == "warn"
		Kind.SPITTER:
			return _state == "puff"
		Kind.DRIFTER:
			return _state == "flash"
	return false

func _throws_spear() -> bool:
	return def.projectile == "spear"

## Seconds between a throw and the next: the spear's own, else the toad's.
func _spit_cooldown() -> float:
	return SPEAR_COOLDOWN if _throws_spear() else SPIT_COOLDOWN

func _speed() -> float:
	return BASE_SPEED * stats.get_stat("spd") / 100.0 * (0.5 if _slow > 0.0 else 1.0)

func _act(player: Node2D, delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	if _verb_act(to_player, delta):
		return
	match kind:
		Kind.SNAKE:
			_snake_act(player, to_player, delta)
		Kind.DROPPER:
			if _on_ceiling:
				velocity = Vector2.ZERO
				if hunting and to_player.y > 0.0 and absf(to_player.x) >= 40.0:
					velocity.x = signf(to_player.x) * _speed()  # a hunter (a boss) creeps along its ceiling until it is over its prey
					facing = 1 if to_player.x > 0.0 else -1
				if is_alert() and absf(to_player.x) < 40.0 and to_player.y > 0.0:
					_on_ceiling = false  # drop on prey: it walks from the next tick
			else:
				_walk(to_player)
		Kind.DRIFTER:
			_drift_act(player, to_player, delta)
		Kind.SWOOPER:
			_swoop_act(player, delta)
		Kind.CHARGER:
			if not _charger_act(player, to_player, delta):
				_walk(to_player)
		Kind.SPITTER:
			if not _spitter_act(player, to_player, delta):
				_walk(to_player)
		_:
			_walk(to_player)

## The verb: alert and in range with the ability ready, wind up (telegraphed), cast at the player, hold still a moment. True while it owns the
## body. A heal waits until the enemy is under half its health.
func _verb_act(to_player: Vector2, delta: float) -> bool:
	if _verb == null:
		return false
	if _verb_state == "windup":
		velocity.x = 0.0
		_verb_t -= delta
		if _verb_t <= 0.0:
			_verb.aim = to_player.normalized()
			if _verb.activate():
				verb_casts += 1
			_verb_state = "recover"
			_verb_t = VERB_RECOVER
		return true
	if _verb_state == "recover":
		if _impulse_t <= 0.0:
			velocity.x = 0.0
		_verb_t -= delta
		if _verb_t <= 0.0:
			_verb_state = ""
		return true
	if _state != "" or not is_alert() or not _verb.ready() or to_player.length() > VERB_RANGE:
		return false
	if _verb_kind == "heal" and health.hp * 2 >= health.max_hp:
		return false
	facing = 1 if to_player.x > 0.0 else -1
	_verb_state = "windup"
	_verb_t = VERB_WINDUP
	velocity.x = 0.0
	return true

## A dash verb's push (the Ability contract): the horizontal speed holds for IMPULSE_SECONDS over the walk.
func apply_impulse(v: Vector2) -> void:
	_impulse_x = v.x
	_impulse_t = IMPULSE_SECONDS
	if v.y < 0.0 and is_on_floor():
		velocity.y = v.y

## A ward verb: the enemy refuses every blow for `seconds`.
func ward(seconds: float) -> void:
	_ward_t = seconds

## Chase while alert (holding at a ledge or wall rather than walking off it), else patrol home.
func _walk(to_player: Vector2) -> void:
	var speed := _speed()
	if def.projectile != "" and is_alert():
		velocity.x = 0.0  # a thrower holds its post, facing you
		if absf(to_player.x) > TURN_LOCK_RANGE:
			facing = 1 if to_player.x > 0.0 else -1
		return
	if is_alert() and absf(to_player.y) < 48.0:
		if absf(to_player.x) > TURN_LOCK_RANGE:
			facing = 1 if to_player.x > 0.0 else -1
		velocity.x = 0.0 if _blocked_ahead() else facing * speed
		return
	if global_position.x > _home_x + PATROL_RANGE:
		facing = -1
	elif global_position.x < _home_x - PATROL_RANGE:
		facing = 1
	if _blocked_ahead():
		facing = -facing
	velocity.x = facing * speed * 0.5

## A wall in front, or no ground a step ahead. Only meaningful on the floor.
func _blocked_ahead() -> bool:
	if not is_on_floor():
		return false
	if is_on_wall() and get_wall_normal().x * facing < 0.0:
		return true
	var ahead := global_position + Vector2(facing * LEDGE_PROBE, 0)
	var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, BODY_BOTTOM + LEDGE_DEPTH))
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

## Wind-up, charge, rest. A stomper's "charge" is a slam: the windup ends in `_slam` and the rest follows. Returns true while the
## charge sequence owns movement.
func _charger_act(player: Node2D, to_player: Vector2, delta: float) -> bool:
	match _state:
		"windup":
			velocity.x = 0.0
			_state_t -= delta
			if _state_t <= 0.0:
				if def.stomper:
					_slam(player)
					_state = "rest"
					_state_t = STOMP_REST
				else:
					_state = "charge"
					_state_t = CHARGE_SECONDS
			return true
		"charge":
			_state_t -= delta
			if _state_t <= 0.0 or _blocked_ahead():
				_state = "rest"
				_state_t = CHARGE_REST
				velocity.x = 0.0
			else:
				velocity.x = facing * _speed() * CHARGE_MULT
			return true
		"rest":
			velocity.x = 0.0
			_state_t -= delta
			if _state_t <= 0.0:
				_state = ""
			return true
	if def.stomper:
		if is_alert() and absf(to_player.x) <= STOMP_RANGE and absf(to_player.y) <= STOMP_LEVEL:
			_state = "windup"
			_state_t = STOMP_WINDUP
			velocity.x = 0.0
			return true
		return false
	var ahead := to_player.x * facing
	if is_alert() and absf(to_player.y) < CHARGE_LEVEL and ahead > TURN_LOCK_RANGE and ahead <= CHARGE_RANGE:
		_state = "windup"
		_state_t = CHARGE_WINDUP
		velocity.x = 0.0
		return true
	return false

## The drake's slam: a hit on a player standing on the floor in the stomp zone. A player with no floor query (a test stub without
## is_on_floor) is never grounded.
func _slam(player: Node2D) -> void:
	var d := player.global_position - global_position
	if absf(d.x) <= STOMP_RANGE and absf(d.y) <= STOMP_LEVEL and player.has_method("is_on_floor") and player.is_on_floor():
		player.receive_hit(stats.get_stat("atk"), "physical", global_position, def.id)

## A slow side-to-side loop about its home; drops a spore puff every PUFF_INTERVAL while the player is near.
func _drift_act(player: Node2D, to_player: Vector2, delta: float) -> void:
	if is_on_wall():
		facing = -facing if is_on_wall() and get_wall_normal().x * facing < 0.0 else facing
	if global_position.x > _home_x + PATROL_RANGE * 2.0:
		facing = -1
	elif global_position.x < _home_x - PATROL_RANGE * 2.0:
		facing = 1
	velocity.x = facing * _speed() * 0.6
	var target_y := _home_y + sin(_anim_t * 1.6) * 14.0
	velocity.y = clampf((target_y - global_position.y) * 2.0, -60.0, 60.0)
	if not def.puffs or to_player.length() > PUFF_RANGE or not can_see(player):  # no puffs through rock, and only the moths puff
		_puff_t = PUFF_INTERVAL
		_state = ""
		return
	if _state == "flash":
		_state_t -= delta
		if _state_t <= 0.0:
			var puff := SporePuff.new()
			get_parent().add_child(puff)
			puff.launch(global_position + Vector2(0.0, 12.0))  # under itself
			EventBus.world_event.emit("spore_puff", {"pos": global_position})
			_puff_t = PUFF_INTERVAL
			_state = ""
		return
	_puff_t -= delta
	if _puff_t <= PUFF_WINDUP:
		_state = "flash"
		_state_t = PUFF_WINDUP

## Tethered to its anchor: coil when prey passes under, lunge along the line to where it was, retreat, hide.
func _snake_act(player: Node2D, to_player: Vector2, delta: float) -> void:
	_state_t -= delta
	match _state:
		"windup":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_aim = (player.global_position - global_position).normalized()
				_state = "charge"
				_state_t = LUNGE_SECONDS
		"charge":
			velocity = _aim * LUNGE_SPEED
			if _state_t <= 0.0 or global_position.distance_to(_anchor) >= LUNGE_REACH:
				_state = "rest"
		"rest":
			var back := _anchor - global_position
			if back.length() <= 3.0:
				global_position = _anchor
				velocity = Vector2.ZERO
				_state = ""
			else:
				velocity = back.normalized() * RETREAT_SPEED
		_:
			velocity = Vector2.ZERO
			if global_position.distance_to(_anchor) > 3.0:
				_state = "rest"  # a stun (which clears the charge) left it off its anchor: go back before anything else
			elif is_alert() and absf(to_player.x) < LUNGE_TRIGGER_X and to_player.y > 0.0 and to_player.y <= LUNGE_TRIGGER_Y:
				_state = "windup"
				_state_t = COIL_SECONDS
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1

## Puff up, then lob a glob at where the player stands. Returns true while winding up.
func _spitter_act(player: Node2D, to_player: Vector2, delta: float) -> bool:
	if _state == "puff":
		velocity.x = 0.0
		_state_t -= delta
		if _state_t <= 0.0:
			if _throws_spear():
				var spear := Spear.new()
				get_parent().add_child(spear)
				spear.launch(global_position + Vector2(facing * 8.0, -6.0), player.global_position, stats.get_stat("atk"), 0, 0.0)
			else:
				var blob := SpitBlob.new()
				get_parent().add_child(blob)
				blob.launch(global_position + Vector2(facing * 8.0, -6.0), player.global_position, _spit_damage, SPIT_TICK, SPIT_SECONDS)
			_spit_cd = _spit_cooldown()
			_state = ""
		return true
	var reach := SPEAR_RANGE if _throws_spear() else SPIT_RANGE
	var level_ok := absf(to_player.y) <= SPEAR_LEVEL if _throws_spear() else true
	if is_alert() and _spit_cd <= 0.0 and to_player.length() < reach and level_ok:
		facing = 1 if to_player.x > 0.0 else -1
		_state = "puff"
		_state_t = SPIT_WINDUP
		velocity.x = 0.0
		return true
	return false

## Hover above you, flash, dive in a straight line at where you were, climb back up.
func _swoop_act(player: Node2D, delta: float) -> void:
	var speed := _speed()
	_state_t -= delta
	match _state:
		"idle":
			velocity = Vector2(0.0, sin(_anim_t * 3.3) * 20.0)
			if is_alert():
				_state = "hover"
				_state_t = HOVER_SECONDS + _rng.randf() * HOVER_JITTER
		"hover":
			var spot := player.global_position + Vector2(0.0, -HOVER_HEIGHT)
			velocity = (spot - global_position).limit_length(speed)
			if not is_alert():
				_state = "idle"
			elif _state_t <= 0.0:
				_state = "warn"
				_state_t = WARN_SECONDS
		"warn":
			velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = "dive"
				_state_t = DIVE_SECONDS
				_aim = (player.global_position - global_position).normalized()
		"dive":
			velocity = _aim * speed * DIVE_MULT
			if _state_t <= 0.0 or is_on_floor() or is_on_wall():
				_state = "climb"
				_state_t = CLIMB_SECONDS
		"climb":
			velocity = Vector2(-_aim.x * speed * 0.5, -speed * 0.8)
			if _state_t <= 0.0:
				_state = "hover" if is_alert() else "idle"
				_state_t = HOVER_SECONDS + _rng.randf() * HOVER_JITTER
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1

func _build_body() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = BODY_SIZE
	shape.shape = rect
	add_child(shape)
	if def != null:
		_still = _load_still()
		_sprite = Art.sprite(frame_name(), BODY_BOTTOM)
		add_child(_sprite)
		_web = WebCover.new()
		add_child(_web)  # after the sprite, so it draws over it
		_load_sheet()
		_load_form()
		_update_visual()

## A twin's animated form, when its sheet (assets/sheets/anim_<form>) and its clips exist; otherwise the still stays.
func _load_form() -> void:
	if not use_sheet or def.form == "":
		return
	var set_name := "anim_" + def.form
	if not SpriteSheet.available(set_name) or not FileAccess.file_exists(form_clips_path):
		return
	if not _form_clip_cache.has(form_clips_path):
		_form_clip_cache[form_clips_path] = SlimeAnimator.load_clips(form_clips_path)
	var all: Dictionary = _form_clip_cache[form_clips_path]
	if not all.has(def.form):
		return
	_form_sheet = SpriteSheet.load_set(set_name)
	if _form_sheet == null:
		return
	_animator = SlimeAnimator.new(all[def.form])
	_animator.play("idle")
	_authored_speed = BASE_SPEED * float(def.stats.get("spd", 100)) / 100.0

## The creature's own frames, when its sheet and clips exist; otherwise the old single sprites stay.
func _load_sheet() -> void:
	var look := _look_id()
	if _still != null or not use_sheet or not SpriteSheet.available(look):
		return
	var clips := SlimeAnimator.load_clips(CLIPS)
	if not clips.has(look):
		return
	_sheet = SpriteSheet.load_set(look)
	if _sheet == null:
		return
	_animator = SlimeAnimator.new(clips[look])
	_authored_speed = BASE_SPEED * float(def.stats.get("spd", 100)) / 100.0  # a rendered sheet's walk was built for this, whatever buffs and slows make of it
	for first in ["idle", "fly", "swim", "drift", "hide"]:  # the clip a creature starts on: its resting loop
		if _animator.clips.has(first):
			_animator.play(first)
			break
	_shapes = SlimeShapes.new()
	_shapes.position = Vector2(0.0, BODY_BOTTOM)
	add_child(_shapes)
