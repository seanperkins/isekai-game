class_name Player
extends CharacterBody2D
## The slime. Reads input, moves, and is the only actor that emits gameplay events.

signal died
signal inspect_report(lines: PackedStringArray)
signal not_enough_mp(skill_id: String)

const SPEED := 140.0
const JUMP_VELOCITY := -330.0
const WALL_JUMP_PUSH := 180.0
const GRAVITY := 900.0
const WALL_SLIDE_SPEED := 90.0
const TACKLE_RANGE := 36.0
const TACKLE_REACH_Y := 28.0
## A tackle reaches a creature whose drawn body is within this gap of the slime's (the dash covers about
## 39 px). Measured on the traced shapes, since contact is: from body centres it fell short of a creature
## that was already biting.
const TACKLE_GAP := 16.0
const TACKLE_SPEED := 260.0
const TACKLE_SECONDS := 0.15
const PREDATE_RANGE := 32.0
## A hold breaks if the target ends up farther than this (eating leaves you rooted and vulnerable).
const PREDATE_BREAK_RANGE := 40.0
const INSPECT_RANGE := 96.0
## Glow Pools, tablets and other interactables answer Inspect within this range, before creatures.
const INTERACT_RANGE := 24.0
const INVULN_SECONDS := 1.0
const KNOCKBACK := Vector2(160.0, -140.0)
const EAT_HEAL := 5
const BASE_STATS := {"max_hp": 30, "atk": 1, "def": 0, "spd": 100, "max_mp": 20, "mp_regen": 100}
const EAT_MP := 4
const LEVEL_UP_BONUS := {"max_hp": 2, "max_mp": 1}
## Stick/keys below this length cast forward instead of aiming.
const AIM_DEADZONE := 0.35
const MAX_MP_PER_THREE_EATS := 2
const LAND_SQUASH_SECONDS := 0.12
const MAX_SWING_SPEED := 520.0
## After letting go of a rope, air speed eases toward walking speed at this rate (px/s^2)
## instead of snapping to it, so the swing's momentum carries you.
const CARRY_DRAG := 240.0
const BODY_BOTTOM := BodyConfig.BOTTOM  # collision box bottom, where the body stands
## Hold down (aim snapped straight down) on the floor and the slime flattens into a puddle.
## SPREAD_STICK_Y is a stick magnitude (0 to 1), not a time.
const SPREAD_STICK_Y := 0.6
const SPREAD_SPEED := 0.5
const HURT_FLASH := 0.25
const EVOLVE_SECONDS := 1.2
const EVOLVE_SWELL := 0.35

var team := "player"
var facing := 1
var stats: Stats
var health: Health
var mana: Mana
var progression := Progression.new()
var skillset: PlayerSkillSet
var sensors := PlayerSensors.new()
var audio_events := PlayerAudioEvents.new()
var predation := PredationHold.new()

var _rules: SkillRulesEngine
var _compendium: CompendiumModel
var _creatures := {}
var _emit: Callable
var _invuln := 0.0
var _dash := 0.0
var _poison_left := 0.0
var _poison_tick := 0
var _poison_acc := 0.0
var _regen_acc := 0.0
var _abilities := {}
var _sprite: Sprite2D
var spreading := false
## Set false before setup() to draw the old scaled sprite instead of the slime's own frames.
var use_sheet := true
var _sheet: SpriteSheet         # the sheet being drawn: the form's own, or the base sheet
var _base_sheet: SpriteSheet    # the plain slime's sheet, also worn (tinted, scaled) by forms without art
var _form_sheet: SpriteSheet    # the current form's own sheet, or null
## The evolved body: stage and form (Form.advance is the only way they change) and the form definitions.
var form := Form.new()
var forms := {}
## Seconds left of the evolution moment: a short lock and shield while the body changes.
var _evolve_time := 0.0
var _kit_starting := false
var _animator: SlimeAnimator
var _shapes: SlimeShapes
var _shape: CollisionShape2D
var _cover: EatCover
var _rect: RectangleShape2D
var _tackle_time := 0.0
var _land_timer := 0.0
var _was_on_floor := true
var eat_prompt := Label.new()
var _creatures_eaten := 0
## The most recent cast, for the input debug overlay: {"id", "aim"}.
var last_cast := {}
## The thread the slime is swinging from, or null.
var rope: Rope = null
var rope_line := Line2D.new()
var _carrying := false

func setup(rules: SkillRulesEngine, compendium: CompendiumModel, creature_defs: Array, emit: Callable) -> void:
	_rules = rules
	_compendium = compendium
	_emit = emit
	for c in creature_defs:
		_creatures[c.id] = c
	stats = Stats.new(BASE_STATS)
	health = Health.new(BASE_STATS["max_hp"])
	health.emit_event = emit
	health.died.connect(_on_health_died)
	mana = Mana.new(BASE_STATS["max_mp"])
	progression.leveled_up.connect(_on_leveled_up)
	sensors.emit_event = emit
	skillset = PlayerSkillSet.new(rules, stats)
	rules.skill_unlocked.connect(_on_skill_unlocked)
	rules.skill_leveled.connect(_on_skill_leveled)
	rules.run_started.connect(_on_run_started)
	forms = FormLoader.load_all()
	add_to_group("player")
	add_to_group("actors")
	if get_child_count() == 0:
		_build_body()

func _physics_process(delta: float) -> void:
	if health == null or health.is_dead():
		return
	if _evolve_time > 0.0:
		_evolve_step(delta)
		return
	var dir := Input.get_axis("move_left", "move_right")
	if predation.active():
		dir = 0.0
	set_spread(wants_spread(is_on_floor(), aim_vector(), raw_aim().y, spreading))
	_tackle_time = maxf(0.0, _tackle_time - delta)
	if dir != 0.0:
		facing = 1 if dir > 0.0 else -1
	if _dash > 0.0:
		_dash -= delta
	elif _carrying and not is_on_floor():
		velocity.x = move_toward(velocity.x, dir * _walk_speed(), CARRY_DRAG * delta)
	elif rope == null or is_on_floor():  # on the ground a roped slime walks normally
		_carrying = false
		velocity.x = dir * _walk_speed()
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	if rope != null:
		_swing(dir, delta)
	if skillset.has("wall_cling") and is_on_wall() and not is_on_floor() and velocity.y > 0.0:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED * stats.get_stat("slide_speed") / 100.0)
	if Input.is_action_just_pressed("jump"):
		do_jump()
	if Input.is_action_just_pressed("tackle"):
		do_tackle()
	# A freed prey (its room was left mid-eat) makes predation.active() false on its own, so end the
	# cover here or the slime stays hidden and the cover node is orphaned.
	if _cover != null and not predation.active():
		cancel_predate()
	if Input.is_action_pressed("predate"):
		if predation.active():
			process_predate(delta)
		else:
			begin_predate()
	elif predation.active():
		cancel_predate()
	if Input.is_action_just_pressed("inspect"):
		do_inspect()
	if Input.is_action_just_pressed("active_1"):
		use_active(0)
	if Input.is_action_just_pressed("active_2"):
		use_active(1)
	if Input.is_action_just_pressed("active_3"):
		use_active(2)
	if Input.is_action_just_pressed("active_4"):
		use_active(3)
	var fall_speed := velocity.y  # move_and_slide zeroes it on landing
	move_and_slide()
	audio_events.update(is_on_floor(), fall_speed, velocity.x, spreading, _clinging())
	if rope != null:
		_stay_on_rope()
	sensors.physics_update(is_on_wall(), is_on_floor())
	tick(delta)
	_update_visual(delta)
	_update_prompt()

## Shows what Inspect or Eat would do here: "I: read" by a tablet, "Hold K to eat" by food.
func _update_prompt() -> void:
	if health.is_dead() or predation.active():
		eat_prompt.visible = false
		return
	var thing = _nearest_in_group("interactable", INTERACT_RANGE, func(_n): return true)
	if thing != null:
		eat_prompt.visible = true
		eat_prompt.text = "%s: %s" % ["Y" if Controls.using_joypad else "I", thing.prompt()]
		return
	var target = _nearest_in_group("predatable", PREDATE_RANGE, func(n): return n.can_be_predated())
	eat_prompt.visible = target != null
	if target != null:
		eat_prompt.text = "Hold %s to eat" % ("B" if Controls.using_joypad else "K")

func _update_visual(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = LAND_SQUASH_SECONDS
	_was_on_floor = on_floor
	_land_timer = maxf(0.0, _land_timer - delta)
	_update_rope_line()
	if _sheet == null:
		_draw_fallback_sprite()
		return
	var state := SlimeState.pick(predation.active(), _invuln > INVULN_SECONDS - HURT_FLASH and not evolving(), rope != null,
		_clinging(), _tackle_time > 0.0, spreading, on_floor, velocity.y, _land_timer, velocity.x)
	_animator.play(state)
	_animator.advance(delta)
	var frame := _animator.frame()
	var left := _faces_left(state, get_wall_normal() if is_on_wall() else Vector2.ZERO)
	var glow := evolve_glow()
	var body_scale := body_scale() * (1.0 + EVOLVE_SWELL * glow)
	_sprite.texture = _sheet.frame_texture(frame)
	_sprite.position.y = BODY_BOTTOM - _sheet.frame_size(frame).y * body_scale / 2.0
	_sprite.scale = Vector2.ONE * body_scale
	_sprite.modulate = body_tint().lerp(Color(2.2, 2.2, 2.2), glow * 0.8)
	_sprite.flip_h = left
	_shapes.refresh(_sheet, frame, left)

## The old frames at the body's scale, for when the sheet is missing.
func _draw_fallback_sprite() -> void:
	var name := "slime_eat" if predation.active() else ("slime_jump" if not is_on_floor() \
		else ("slime_land" if _land_timer > 0.0 else "slime_idle"))
	Art.set_frame(_sprite, name, BODY_BOTTOM)
	_sprite.flip_h = facing < 0
	_sprite.scale = Vector2(BodyConfig.SCALE, BodyConfig.SCALE)
	if _sprite.texture != null:
		_sprite.position.y = BODY_BOTTOM - _sprite.texture.get_height() * BodyConfig.SCALE / 2.0

## Spread starts on the floor with the aim snapped straight down and the stick (or keys) held at
## least SPREAD_STICK_Y; once spread, it holds while `raw_y` stays at or above SPREAD_STICK_Y.
static func wants_spread(on_floor: bool, snapped: Vector2, raw_y: float, was_spread: bool) -> bool:
	if not on_floor:
		return false
	if was_spread:
		return raw_y >= SPREAD_STICK_Y
	return snapped == Vector2.DOWN and raw_y >= SPREAD_STICK_Y

func _walk_speed() -> float:
	return SPEED * stats.get_stat("spd") / 100.0 * (SPREAD_SPEED if spreading else 1.0)

## Flattens or stands the slime. The collision box keeps its bottom on the floor, and standing
## needs room above.
func set_spread(value: bool) -> void:
	if value == spreading:
		return
	if not value and not _can_stand():
		return
	spreading = value
	EventBus.world_event.emit("spread", {"on": value})
	var size := BodyConfig.spread_size() if value else BodyConfig.size()
	_rect.size = size
	_shape.position.y = BODY_BOTTOM - size.y / 2.0

## True when nothing solid sits within the extra height a standing slime needs.
func _can_stand() -> bool:
	var rise := BodyConfig.size().y - BodyConfig.spread_size().y
	return not test_move(global_transform, Vector2(0.0, -rise))

## Whether the body is drawn mirrored. The wall grip is drawn on the wall's side, from the wall
## normal (a wall on the left has a normal pointing right); every other state follows `facing`.
func _faces_left(state: String, wall_normal: Vector2) -> bool:
	if state == "wall":
		return wall_normal.x > 0.0
	return facing < 0

func _clinging() -> bool:
	return skillset.has("wall_cling") and is_on_wall() and not is_on_floor() and velocity.y > 0.0

## The body's collision box in world space (it shrinks when spread). Enemies use it for contact.
func body_rect() -> Rect2:
	return Rect2(global_position + _shape.position - _rect.size / 2.0, _rect.size)

## Where the slime can be hit: the current frame's traced shape (global points), or the body box
## when the sheet is missing.
func hurt_polygon() -> PackedVector2Array:
	if _shapes != null and _shapes.hurt_poly.polygon.size() >= 3:
		return ShapeHit.moved(_shapes.hurt_poly.polygon, _shapes.global_position, body_scale())
	return ShapeHit.rect_points(body_rect())

func do_jump() -> void:
	if health.is_dead() or predation.active():
		return
	if spreading:
		if not _can_stand():
			return
		set_spread(false)
	if rope != null and is_on_floor():
		drop_rope()  # then a normal ground jump
	elif rope != null:
		release_rope()
		return
	var boost := sqrt(stats.get_stat("jump_height") / 100.0)
	if is_on_floor():
		velocity.y = JUMP_VELOCITY * boost
		sensors.jumped("ground")
	elif skillset.has("wall_cling") and is_on_wall():
		velocity.y = JUMP_VELOCITY * boost
		velocity.x = get_wall_normal().x * WALL_JUMP_PUSH
		_dash = 0.15
		sensors.jumped("wall")

func do_tackle() -> void:
	if health.is_dead() or predation.active() or _dash > 0.0:
		return
	velocity.x = facing * TACKLE_SPEED
	_dash = TACKLE_SECONDS
	_tackle_time = TACKLE_SECONDS
	EventBus.world_event.emit("tackled", {})
	var target = _tackle_target()
	if target == null or not target.has_method("receive_tackle"):
		return
	var from_behind: bool = target.facing == facing
	if target.receive_tackle(stats.get_stat("atk"), from_behind, global_position):
		_emit.call(Events.STUNNED_ENEMY, {"source": target.def.id})

func begin_predate() -> void:
	if health.is_dead():
		return
	var target = _nearest_in_group("predatable", PREDATE_RANGE, func(n): return n.can_be_predated())
	if target == null:
		return
	target.set_held(true)
	drop_rope()
	predation.start(target, stats.get_stat("predation_time"))
	_start_cover(target)
	EventBus.world_event.emit("eat_started", {"pos": target.global_position})

func process_predate(delta: float) -> void:
	var t = predation.target
	if health.is_dead() or not is_instance_valid(t) or not t.can_be_predated() \
			or global_position.distance_to(t.global_position) > PREDATE_BREAK_RANGE:
		cancel_predate()
		return
	if _cover != null:
		_cover.tick(delta, predation.progress())
	if predation.update(delta):
		_complete_predation(t)

func cancel_predate() -> void:
	var t = predation.target
	if is_instance_valid(t):
		t.set_held(false)
	predation.cancel()
	_end_cover()

func _start_cover(target: Node2D) -> void:
	if _sheet == null:
		return
	_end_cover()
	_cover = EatCover.new()
	get_parent().add_child(_cover)
	_cover.begin(target, _sheet, target.global_position.x < global_position.x)
	_cover.set_look(body_tint(), body_scale())
	_sprite.visible = false

func _end_cover() -> void:
	if _cover != null and is_instance_valid(_cover):
		_cover.finish()
	_cover = null
	_sprite.visible = true

func do_inspect() -> void:
	if health.is_dead():
		return
	var thing = _nearest_in_group("interactable", INTERACT_RANGE, func(_n): return true)
	if thing != null:
		thing.interact(self)
		return
	var target = _nearest_in_group("inspectable", INSPECT_RANGE, func(_n): return true)
	if target == null:
		sensors.inspected("self", true)
		inspect_report.emit(StatusText.self_lines(stats, health, _rules, _compendium, _rules.level_of("appraisal")))
		return
	var c: CreatureDef = target.def
	sensors.inspected(c.id, c.appraisal_target)
	inspect_report.emit(StatusText.creature_lines(_compendium.creature_report(c.id, _rules.level_of("appraisal"))))

func use_active(i: int) -> void:
	if health.is_dead() or predation.active():
		return
	var id := skillset.slots.use(i)
	if id == "":
		return
	var ability := _ability(id)
	if ability == null:
		return
	if not ability.ready():
		return  # on cooldown: costs nothing
	var cost := FormEffects.mp_cost(skillset.capabilities, id, _rules.get_def(id).mp_cost)
	if not mana.spend(cost):
		not_enough_mp.emit(id)
		return
	ability.level = _rules.level_of(id)
	# Nothing held: zero, so each ability uses its own default (forward, or up-forward for Swing).
	ability.aim = aim_vector() if aim_held() else Vector2.ZERO
	ability.activate()
	last_cast = {"id": id, "aim": ability.aim_dir()}
	_emit.call(Events.SKILL_USED, {"id": id})
	for _point in cost:
		_emit.call(Events.MANA_SPENT, {})

## Called by a thread that stuck to terrain. Attaching again re-aims the rope.
func attach_rope(anchor: Vector2, max_length: float, reel_speed: float, boost: float) -> void:
	if health.is_dead():
		return
	rope = Rope.new(anchor, global_position, max_length, reel_speed, boost)
	_dash = 0.0
	_carrying = false
	_update_rope_line()

## Jump off the rope, keeping the swing's momentum times the thread's boost.
func release_rope() -> void:
	if rope == null:
		return
	velocity = rope.release_velocity(velocity)
	drop_rope()
	_carrying = true

func drop_rope() -> void:
	rope = null
	_update_rope_line()

## Reel with up/down; in the air, pump with left/right and never move outward past the rope.
## On the ground the slime walks and the rope pays out (see _stay_on_rope).
func _swing(dir: float, delta: float) -> void:
	var reel_axis := raw_aim().y
	if absf(reel_axis) >= AIM_DEADZONE:
		rope.reel(signf(reel_axis), delta)
	if is_on_floor():
		return
	velocity = rope.pump(global_position, velocity, dir, delta)
	velocity = velocity.limit_length(MAX_SWING_SPEED)
	velocity = rope.constrain_velocity(global_position, velocity)

## After moving, slide back onto the rope (colliding, so the pull never goes through walls).
## On the ground the rope pays out instead, until it runs out.
func _stay_on_rope() -> void:
	if is_on_floor():
		rope.pay_out(global_position)
		var slack := rope.correction(global_position)
		if slack.x != 0.0:  # out of rope: held back sideways, never lifted
			move_and_collide(Vector2(slack.x, 0.0))
			velocity.x = 0.0
		return
	var fix := rope.correction(global_position)
	if fix != Vector2.ZERO:
		move_and_collide(fix)
	velocity = rope.constrain_velocity(global_position, velocity)

func _update_rope_line() -> void:
	rope_line.visible = rope != null
	if rope != null:
		rope_line.points = PackedVector2Array([global_position, rope.anchor])

func award_xp(amount: int) -> void:
	if not health.is_dead():
		progression.add_xp(amount)

## Connected to every enemy's `downed` signal.
func on_enemy_downed(def: CreatureDef, spawn_key := "") -> void:
	if not health.is_dead():
		progression.award(spawn_key, "down", def.xp)

## Spends EP to unlock a ready evolution. False when not ready or not enough EP.
func try_evolve(id: String) -> bool:
	if not _rules.is_evolution_ready(id) or progression.ep < _rules.evolution_cost(id):
		return false
	var cost := _rules.evolution_cost(id)
	if not _rules.evolve(id):
		return false
	progression.spend_ep(cost)
	EventBus.world_event.emit("evolved", {"id": id})
	return true

## The forms on offer right now (FormDefs): empty until the level cap is reached, and at the last stage.
func form_offers() -> Array:
	var out: Array = []
	if not progression.can_evolve():
		return out
	for id in FormOffers.offers(forms, form, FormOffers.absorbed_units(_rules, progression.seeded), FormOffers.default_supply(forms)):
		out.append(forms[id])
	return out

## The form's definition, or null for the base slime.
func form_def() -> FormDef:
	return forms.get(form.form_id)

## The sheet the body is drawn from: the form's own art, or the base slime's.
func body_sheet() -> SpriteSheet:
	return _form_sheet if _form_sheet != null else _base_sheet

## A form without art of its own wears the base sheet tinted and scaled; one with art is drawn as it is.
func body_tint() -> Color:
	var d := form_def()
	return d.tint if d != null and _form_sheet == null else Color.WHITE

func body_scale() -> float:
	var d := form_def()
	return d.size if d != null and _form_sheet == null else 1.0

## Evolves the body into `id`: a legal next form, and (unless `force`, for tests and debugging) the level
## cap reached. Resets the level (keeping EP and the level bonuses), raises the skill cap and re-checks
## every skill, applies the form's stats and traits, grants its skills, and changes the look. The
## collision box never changes.
func advance_form(id: String, force := false) -> bool:
	if health.is_dead() or (not force and not progression.can_evolve()):
		return false
	if not form.advance(id, forms):
		return false
	progression.evolve_stage()
	_rules.set_stage_cap(form.cap())
	var def: FormDef = forms[id]
	skillset.form_mods = FormEffects.modifiers(def)
	skillset.form_flags = FormEffects.flags(def)
	for g in def.grants:
		_rules.grant(g)
	_rules.recheck_levels()
	_use_form_sheet(def)
	skillset.refresh()
	_sync_max_hp()
	_begin_evolve_moment(def)
	EventBus.world_event.emit("evolved_body", {"id": id, "stage": form.stage})
	return true

func evolving() -> bool:
	return _evolve_time > 0.0

## 1 at the start of the evolution moment, easing to 0: drives the glow and the swell.
func evolve_glow() -> float:
	var k := clampf(_evolve_time / EVOLVE_SECONDS, 0.0, 1.0)
	return k * k

## The lock and shield while the body changes: no walking or acting, no damage, no eat or rope in progress.
func _begin_evolve_moment(def: FormDef) -> void:
	_evolve_time = EVOLVE_SECONDS
	_invuln = maxf(_invuln, EVOLVE_SECONDS)
	cancel_predate()
	drop_rope()
	var fx := EvolutionFx.new()
	fx.tint = def.tint
	add_child(fx)

func _evolve_step(delta: float) -> void:
	_evolve_time = maxf(0.0, _evolve_time - delta)
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	tick(delta)
	_update_visual(delta)

## Sets the character level a rebirth kit starts at (bonuses, no EP, no fanfare).
func start_at_level(level: int) -> void:
	_kit_starting = true
	progression.start_at(level)
	_kit_starting = false
	_sync_max_hp()

## Health and mana to their maximums (a new life is not wounded; raising a maximum never raised the current value).
func fill_vitals() -> void:
	health.heal(health.max_hp)
	mana.restore(mana.max_mp)

## Grants XP directly (tests, and the --evolve launch shortcut).
func debug_grant_xp(amount: int) -> void:
	progression.add_xp(amount)

func _use_form_sheet(def: FormDef) -> void:
	if _animator == null:
		return  # no sheet drawing at all (use_sheet false): there is nothing to swap
	if def.sprite_set != "" and SpriteSheet.available(def.sprite_set):
		_form_sheet = SpriteSheet.load_set(def.sprite_set)
		_sheet = _form_sheet
	else:
		_form_sheet = null
		if _base_sheet != null:
			_sheet = _base_sheet

func _on_leveled_up(level: int) -> void:
	if not _kit_starting:  # a rebirth kit's starting level makes no fanfare
		EventBus.world_event.emit("leveled_up", {"level": level})
	for stat in LEVEL_UP_BONUS:
		stats.add_level_bonus(stat, LEVEL_UP_BONUS[stat])
	_sync_max_hp()

## The held direction snapped to 8 ways, or forward (facing) when nothing is held.
static func resolve_aim(raw: Vector2, p_facing: int) -> Vector2:
	if raw.length() < AIM_DEADZONE:
		return Vector2(p_facing, 0)
	var snapped := snappedf(raw.angle(), PI / 4.0)
	var dir := Vector2.from_angle(snapped)
	return Vector2(snappedf(dir.x, 0.0001), snappedf(dir.y, 0.0001)).normalized()

## The held direction before snapping. The stick is read raw from the pad that last moved:
## Input.get_vector() applies the action deadzone first (so a light tilt read as "no aim"),
## and it merges every device (so a stale second pad could cancel the stick out).
func raw_aim() -> Vector2:
	if Controls.last_stick.length() >= AIM_DEADZONE:
		return Controls.last_stick
	return Input.get_vector("move_left", "move_right", "aim_up", "aim_down", 0.0)

func aim_held() -> bool:
	return raw_aim().length() >= AIM_DEADZONE

func aim_vector() -> Vector2:
	return resolve_aim(raw_aim(), facing)

## `from` is the attacker's position for contact hits; the slime is knocked away from it.
func receive_hit(raw: int, damage_type: String, from: Vector2 = Vector2.INF, _cause: String = "") -> void:
	if _invuln > 0.0 or health.is_dead():
		return
	var m := skillset.incoming(damage_type, health.hp, health.max_hp)
	health.take_hit(Damage.direct_hit(raw, m["percent_off"], m["flat_off"] + stats.get_stat("def")), damage_type)
	_invuln = INVULN_SECONDS
	if from != Vector2.INF and not health.is_dead():
		var away := 1.0 if global_position.x >= from.x else -1.0
		velocity = Vector2(away * KNOCKBACK.x, KNOCKBACK.y)
		_dash = 0.2

func receive_poison(application: int, tick_amount: int, seconds: float) -> void:
	if _invuln > 0.0 or health.is_dead():
		return
	receive_hit(application, "poison")
	_poison_left = seconds
	_poison_tick = tick_amount
	_poison_acc = 0.0

func tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	if health.is_dead():
		return
	if _poison_left > 0.0:
		_poison_acc += delta
		while _poison_acc >= 1.0 - 0.0001 and _poison_left > 0.0:
			_poison_acc -= 1.0
			_poison_left -= 1.0
			var m := skillset.incoming("poison", health.hp, health.max_hp)
			health.take_tick(Damage.tick(_poison_tick, m["percent_off"]))
	mana.regen(delta, stats.get_stat("mp_regen"))
	var interval := stats.get_stat("regen_interval")
	if interval > 0:
		_regen_acc += delta
		if _regen_acc >= interval:
			_regen_acc -= interval
			health.heal(1)
	else:
		_regen_acc = 0.0

## Sets horizontal speed, and vertical speed too when the impulse has a vertical part, so an
## upward cast works mid-fall instead of cancelling against the fall speed.
func apply_impulse(v: Vector2) -> void:
	velocity = Vector2(v.x, v.y if not is_zero_approx(v.y) else velocity.y)
	_dash = 0.25

func _complete_predation(t) -> void:
	_end_cover()
	predation.cancel()
	var c: CreatureDef = t.consume()
	var kind := "terrain" if c.id == Sources.WATER_POOL else "creature"
	_emit.call(Events.PREDATED, {"source": c.id, "kind": kind})
	for ess in Essences.ALL:  # canonical order, independent of how the .tres stored the keys
		for i in int(c.essences.get(ess, 0)):
			_emit.call(Events.ABSORBED, {"essence": ess, "source": c.id})
	stats.apply_eat(c)
	_sync_max_hp()
	health.heal(EAT_HEAL + FormEffects.eat_heal(skillset.capabilities) + skillset.heal_on(Events.PREDATED, {"source": c.id, "kind": kind}))
	if kind == "creature":
		if not health.is_dead():
			progression.award(t.spawn_key if "spawn_key" in t else "", "eat", c.xp)
		mana.restore(EAT_MP)
		_creatures_eaten += 1
		if _creatures_eaten % 3 == 0:
			stats.add_eat_bonus(StatKeys.MAX_MP, MAX_MP_PER_THREE_EATS)
			_sync_max_hp()

func _ability(id: String) -> Ability:
	if _abilities.has(id):
		return _abilities[id]
	var d := _rules.get_def(id)
	if d == null:
		return null
	var path := SkillEffects.active_scene(d)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var node = load(path).instantiate()
	if not (node is Ability):
		node.free()
		return null
	node.setup(self, SkillEffects.active_values(d), _rules.level_of(id))
	add_child(node)
	_abilities[id] = node
	return node

## The nearest other-team actor in front whose drawn body is within TACKLE_GAP of the slime's (a target
## with no shape, like a shortcut switch, is measured centre to centre against TACKLE_RANGE).
func _tackle_target():
	var mine := hurt_polygon()
	var best = null
	var best_dx := INF
	for n in get_tree().get_nodes_in_group("actors"):
		if n == self or n.get("team") == team:
			continue
		var dx: float = (n.global_position.x - global_position.x) * facing
		if dx < -4.0 or absf(n.global_position.y - global_position.y) > TACKLE_REACH_Y:
			continue
		if n.has_method("can_be_hit") and not n.can_be_hit():
			continue  # a corpse must not swallow the tackle meant for the creature beyond it
		if n.has_method("hurt_polygon"):
			if _gap_in_front(mine, n.hurt_polygon()) > TACKLE_GAP:
				continue
		elif dx > TACKLE_RANGE:
			continue
		if dx < best_dx:
			best = n
			best_dx = dx
	return best

## Horizontal gap, in the facing direction, between the front of `mine` and the near edge of `theirs`
## (negative when they overlap).
func _gap_in_front(mine: PackedVector2Array, theirs: PackedVector2Array) -> float:
	var my_front := -INF
	var their_near := INF
	for p in mine:
		my_front = maxf(my_front, p.x * facing)
	for p in theirs:
		their_near = minf(their_near, p.x * facing)
	return their_near - my_front

func _nearest_in_front(range_px: float):
	var best = null
	var best_dx := INF
	for n in get_tree().get_nodes_in_group("actors"):
		if n == self or n.get("team") == team:
			continue
		var dx: float = (n.global_position.x - global_position.x) * facing
		if dx < -4.0 or dx > range_px or absf(n.global_position.y - global_position.y) > TACKLE_REACH_Y:
			continue
		if dx < best_dx:
			best = n
			best_dx = dx
	return best

func _nearest_in_group(group: String, range_px: float, accept: Callable):
	var best = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		if n == self or not is_instance_valid(n):
			continue
		var d := global_position.distance_to(n.global_position)
		if d <= range_px and d < best_d and accept.call(n):
			best = n
			best_d = d
	return best

## Re-reads max HP and MP from the stats (after a kit or a form changed them).
func refresh_stats() -> void:
	_sync_max_hp()

func _sync_max_hp() -> void:
	health.set_max_hp(stats.get_stat("max_hp"))
	mana.set_max_mp(stats.get_stat("max_mp"))

func _on_skill_unlocked(id: String) -> void:
	skillset.on_skill_unlocked(id)
	_sync_max_hp()

func _on_skill_leveled(_id: String, _level: int) -> void:
	skillset.refresh()
	_sync_max_hp()

func _on_run_started() -> void:
	progression = Progression.new()  # levels are per run
	progression.leveled_up.connect(_on_leveled_up)
	form.reset()
	_form_sheet = null
	if _base_sheet != null:
		_sheet = _base_sheet
	skillset.reset()
	drop_rope()
	stats.reset_run()
	_sync_max_hp()

func _on_health_died() -> void:
	audio_events.reset()
	EventBus.world_event.emit("player_died", {})
	cancel_predate()
	drop_rope()
	died.emit()

func _build_body() -> void:
	_shape = CollisionShape2D.new()
	_rect = RectangleShape2D.new()
	_rect.size = BodyConfig.size()
	_shape.shape = _rect
	add_child(_shape)
	_sprite = Art.sprite("slime_idle", BODY_BOTTOM)
	add_child(_sprite)
	if use_sheet and SpriteSheet.available("slime"):
		_sheet = SpriteSheet.load_set("slime")
		_base_sheet = _sheet
		_animator = SlimeAnimator.new(SlimeAnimator.load_clips())
		_animator.play("idle")
		var first := _animator.frame()
		_sprite.texture = _sheet.frame_texture(first)
		_sprite.position.y = BODY_BOTTOM - _sheet.frame_size(first).y / 2.0
		_shapes = SlimeShapes.new()
		_shapes.position = Vector2(0.0, BODY_BOTTOM)
		add_child(_shapes)
		_shapes.refresh(_sheet, first, false)
	add_child(Art.light(Color(0.4, 0.75, 1.0), 0.8, 1.2))  # the slime's soft inner glow
	eat_prompt.visible = false
	eat_prompt.add_theme_font_size_override("font_size", 8)
	eat_prompt.position = Vector2(-24, -22)
	eat_prompt.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	eat_prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.15))
	eat_prompt.add_theme_constant_override("outline_size", 4)
	add_child(eat_prompt)
	rope_line.top_level = true  # drawn in world space, from the slime to the anchor
	rope_line.width = 1.0
	rope_line.default_color = ThreadAbility.THREAD_COLOR
	rope_line.visible = false
	add_child(rope_line)
