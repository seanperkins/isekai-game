class_name Player
extends CharacterBody2D
## The slime. Reads input, moves, and is the only actor that emits gameplay events.

signal died
signal inspect_report(lines: PackedStringArray)
signal not_enough_mp(skill_id: String)
## A body evolution succeeded (advance_form): the game records the form as reached.
signal form_advanced(id: String)

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
const GLIDE_FALL := 40.0
## Seconds a crawler that was hit cannot grip a surface again.
const SURFACE_LET_GO := 0.3
## A species body that is this far (px) from where its last tick left it has been moved by something else.
const TELEPORT_DISTANCE := 4.0
## The spider's sprite: how fast it settles onto a new surface (s), how long a reversal pivots (s) and how long the thread fades (s).
const SPIDER_CORNER_EASE := 0.04
const SPIDER_PIVOT_SECONDS := 0.10
const THREAD_FADE := 0.15
## The old slime frames stand in for a species with no art, in a colour of its own.
const PLACEHOLDER_TINT := {"wolf": Color(0.75, 0.75, 0.85), "goblin": Color(0.65, 0.9, 0.55), "undead": Color(0.85, 0.85, 0.75), "spider": Color(0.6, 0.45, 0.6)}
const KNOCKBACK := Vector2(160.0, -140.0)
## A shock hit locks input this long (the same lock a hit's knockback uses, so it only adds the difference).
const SHOCK_STUN := 0.3
const EAT_HEAL := 5
const BASE_STATS := {"max_hp": 30, "atk": 1, "def": 0, "spd": 100, "max_mp": 20, "mp_regen": 100}
const EAT_MP := 4
const LEVEL_UP_BONUS := {"max_hp": 2, "max_mp": 1}
## The left stick or keys below this length cast forward instead of aiming (the right stick and the mouse have their own
## deadzones: Controls.RIGHT_STICK_DEADZONE and MOUSE_DEADZONE).
const AIM_DEADZONE := 0.35
## sin(10 degrees): a pointer aim this close to an axis reads as exactly that axis, so the two "flat aim" checks
## (Hydraulic's lift, apply_impulse's flat push) keep working, and a thumb's or a hand's wobble does not tilt a dash.
const AXIS_SNAP := 0.17364817766693
## A cursor closer than this (world px) to the origin does not aim: it would jitter at every step.
const MOUSE_DEADZONE := 12.0
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
## What dealt the last blow that landed: a creature id, "spear", or the damage type. Set before `died` can fire; the goddess reads it.
var last_hit_cause := ""
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
## A verb's ward: no damage while it lasts. Apart from _invuln, which also draws the hurt flash and the evolve hold.
var _ward := 0.0
## A verb's glide (Ride): while it runs a falling body falls no faster than _glide_fall.
var _glide := 0.0
var _glide_fall := GLIDE_FALL
## The species' movement (a wolf, goblin, undead or spider body), or null for the slime, which moves by the code below. Built in
## setup() from `species`; it moves this body, so `velocity` is its velocity too.
var species_body: SpeciesBody
## How a species' sheet is found (SpeciesLook.sheet_for when unset); a test sets it to simulate missing art.
var species_sheet_loader := Callable()
## The horizontal speed an ability's push or a hit's knockback holds for `_dash` seconds on a species body.
var _dash_vx := 0.0
var _pounce_applied := false
var _last_verb := ""
## Where a species body ended its last tick: a different position at the next one means something moved it (Recall, a placement).
var _species_pos := Vector2.INF
## The spider's drawing: its sprite turns to the surface it is on, the legs follow the distance crawled, a reversal pivots, a
## corner is eased through, and a thread is drawn while it zips or hangs.
var _spider_angle := 0.0
var _spider_stride := 0.0
var _spider_sense := 1.0
var _spider_pivot := 0.0
var _spider_off := Vector2.ZERO
var _spider_prev := Vector2.ZERO
var _thread_anchor := Vector2.ZERO
var _thread_dir := Vector2.RIGHT
var _thread_alpha := 0.0
var _dash := 0.0
## The water model: whether the body centre is in a DeepWater, the submerged clock, the edges (see PlayerWater).
var _water := PlayerWater.new()
var _poison_left := 0.0
var _poison_tick := 0
var _poison_acc := 0.0
## The fraction of an HP the poison ticks so far have left over, in thousandths (Damage.MILLI). Kept across applications:
## a new spit restarts the clock but not this; a new life is a new Player.
var _poison_milli := 0
var _regen_acc := 0.0
var _abilities := {}
## One live channel at most: the held ability, its slot, how long it has been held and the MP beat timer.
const CHANNEL_BEAT := 0.5  # seconds per MP point while a channel is held
const CHANNEL_EPS := 0.0001
const CHANNEL_RELEASE := 0.3  # raw strength: a trigger dipping under its 0.5 press deadzone mid-hold keeps the channel
var _reticle: AimReticle
var _channel: Ability = null
var _channel_slot := 0
var _channel_time := 0.0
var _channel_beat := 0.0
var _sprite: Sprite2D
var spreading := false
## Set false before setup() to draw the old scaled sprite instead of the slime's own frames.
var use_sheet := true
var _sheet: SpriteSheet         # the sheet being drawn: the form's own, or the base sheet
var _base_sheet: SpriteSheet    # the plain slime's sheet, also worn (tinted, scaled) by forms without art
var _form_sheet: SpriteSheet    # the current form's own sheet, or null
var _still := ""                # the frame of that sheet drawn as the form's body ("" for a form that animates)
## The evolved body: stage and form (Form.advance is the only way they change) and the form definitions.
## Which species this body is (Form.SPECIES): set before setup(), which builds `form` for it. Only the form tree follows it so
## far; the body, the movement and the sheet are the slime's until the species are wired into the player.
var species := Form.DEFAULT_SPECIES
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
## The creature last appraised (Inspect on it), for Copy; null until one is.
var last_inspected: CreatureDef = null
## The thread the slime is swinging from, or null.
var rope: Rope = null
var rope_line := Line2D.new()
var _carrying := false

func setup(rules: SkillRulesEngine, compendium: CompendiumModel, creature_defs: Array, emit: Callable) -> void:
	form = Form.new(species)
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
	if species != Form.DEFAULT_SPECIES and MovementProfile.for_species(species) != null:
		_build_species_body()

func uses_species_body() -> bool:
	return species_body != null

## Becomes `id` (a species with a movement profile) before the run starts: the form tree, the movement and the look follow. An unknown
## id, or the species it already is, changes nothing; a Player is never turned back into a slime.
func set_species(id: String) -> void:
	if id == species or id == Form.DEFAULT_SPECIES or MovementProfile.for_species(id) == null:
		return
	species = id
	form = Form.new(species)
	_build_species_body()

func _physics_process(delta: float) -> void:
	if health == null or health.is_dead():
		return
	if _evolve_time > 0.0:
		_evolve_step(delta)
		return
	if species_body != null:
		_species_physics(delta)
		return
	var wet := _step_water(delta)
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
		if _glide > 0.0 and velocity.y > _glide_fall:
			velocity.y = _glide_fall
	if rope != null:
		_swing(dir, delta)
	if _water.in_water:
		velocity = _water.adjust(velocity, is_on_floor(), skillset.has("swim"),
			Vector2.ZERO if predation.active() else Input.get_vector("move_left", "move_right", "aim_up", "aim_down"),
			float(stats.get_stat("swim_speed")),
			sqrt(stats.get_stat("jump_height") / 100.0), _dash > 0.0, wet["entered"], delta)
	if skillset.has("wall_cling") and is_on_wall() and not is_on_floor() and velocity.y > 0.0 and not _water.in_water:
		velocity.y = minf(velocity.y, WALL_SLIDE_SPEED * stats.get_stat("slide_speed") / 100.0)
	if Input.is_action_just_pressed("jump"):
		do_jump()
	if Input.is_action_just_pressed("tackle"):
		do_tackle()
	_actions(delta)
	var fall_speed := velocity.y  # move_and_slide zeroes it on landing
	move_and_slide()
	audio_events.update(is_on_floor(), fall_speed, velocity.x, spreading, _clinging())
	if rope != null:
		_stay_on_rope()
	sensors.physics_update(is_on_wall(), is_on_floor())
	tick(delta)
	_update_visual(delta)
	_update_prompt()

## What every body does besides moving: eat, Inspect, the four active slots and a held channel.
func _actions(delta: float) -> void:
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
	_channel_step(delta)

## One physics tick of a species body: the input becomes a MoveInput, the species' verbs and the move run (water and a glide get the
## last word on the velocity), a signature burst that touches a hostile hits it, then the shared actions and the usual bookkeeping.
func _species_physics(delta: float) -> void:
	var wet := _step_water(delta)
	_dash = maxf(0.0, _dash - delta)
	var eating := predation.active()
	var i := MoveInput.new()
	i.dir = 0.0 if eating else Input.get_axis("move_left", "move_right")
	i.jump_pressed = not eating and Input.is_action_just_pressed("jump")
	i.jump_held = Input.is_action_pressed("jump")
	i.down = Input.get_action_strength("aim_down")
	i.up = Input.get_action_strength("aim_up")
	i.aim = cast_aim()
	i.signature_pressed = not eating and Input.is_action_just_pressed("tackle")
	var st := species_body.state
	st.velocity = velocity  # whatever wrote the body's velocity since last tick (a room slide, an ability) is the truth
	if rope != null and i.jump_pressed:  # as do_jump does: on the ground drop the rope and jump, in the air let go and swing on
		if is_on_floor():
			drop_rope()
		else:
			release_rope()
			st.velocity = velocity
			i.jump_pressed = false
	if _water.in_water and i.jump_pressed:  # in water a press is a bob or a surface launch, never a dry jump
		i.jump_pressed = false
		var launched = _water.jump(velocity, is_on_floor(), skillset.has("swim"), sqrt(stats.get_stat("jump_height") / 100.0), global_position)
		if launched != null:
			velocity = launched
			st.velocity = launched
			sensors.jumped("ground")
	if _species_pos != Vector2.INF and global_position.distance_to(_species_pos) > TELEPORT_DISTANCE:
		st.surface_n = Vector2.ZERO  # it was carried somewhere: a crawler is not on the surface it was on, nor hanging from a thread
		st.drop_up = 0.0
		st.zip_dir = Vector2.ZERO
	species_body.fill_input(i, func() -> bool: return _tackle_target() != null)
	species_body.think(i, delta, sqrt(stats.get_stat("jump_height") / 100.0), stats.get_stat("spd") / 100.0)
	if st.launched != "" and st.launched != "vault":  # a vault is the body hopping a step by itself, not a jump press
		sensors.jumped("wall" if st.launched == "wall" else "ground")
	facing = st.facing
	if _dash > 0.0:
		st.velocity.x = _dash_vx  # a push or a knockback holds the horizontal for its time
	if rope != null:
		velocity = st.velocity
		_swing(i.dir, delta)
		st.velocity = velocity
	species_body.move(_species_adjust.bind(wet, delta))
	if rope != null:
		_stay_on_rope()
		st.velocity = velocity
	_species_pos = global_position
	_species_combat()
	_actions(delta)
	audio_events.update(is_on_floor(), species_body.fall_speed, velocity.x, false, st.clinging)
	sensors.physics_update(is_on_wall(), is_on_floor())
	tick(delta)
	_update_visual_species(delta)
	_update_prompt()

## The last word on a species body's velocity before it moves: the water model, then a glide's cap on the fall.
func _species_adjust(v: Vector2, wet: Dictionary, delta: float) -> Vector2:
	if _water.in_water:
		v = _water.adjust(v, is_on_floor(), skillset.has("swim"),
			Vector2.ZERO if predation.active() else Input.get_vector("move_left", "move_right", "aim_up", "aim_down"),
			float(stats.get_stat("swim_speed")),
			sqrt(stats.get_stat("jump_height") / 100.0), _dash > 0.0, wet["entered"], delta)
	if _glide > 0.0 and v.y > _glide_fall:
		v.y = _glide_fall
	return v

## A pounce that has touched a hostile hits it once, as the slime's Tackle does; a burst that starts says so for the sound.
func _species_combat() -> void:
	var st := species_body.state
	if st.verb != "" and _last_verb == "":
		EventBus.world_event.emit("tackled", {})
	_last_verb = st.verb
	if st.verb == "pounce" and st.pounce_hit and not _pounce_applied:
		_pounce_applied = true
		var target = _tackle_target()
		if target != null and target.has_method("receive_tackle"):
			var from_behind: bool = target.facing == facing
			if target.receive_tackle(stats.get_stat("atk"), from_behind, global_position):
				_emit.call(Events.STUNNED_ENEMY, {"source": target.def.id})
	elif st.verb != "pounce":
		_pounce_applied = false

## Shows what Inspect or Eat would do here: "I: read" by a tablet, "Hold K to eat" by food.
func _update_prompt() -> void:
	if health.is_dead() or predation.active():
		eat_prompt.visible = false
		return
	var thing = _nearest_in_group("interactable", INTERACT_RANGE, func(_n): return true)
	if thing != null:
		eat_prompt.visible = true
		eat_prompt.text = "%s: %s" % [Controls.inspect_label(), thing.prompt()]
		return
	var target = _nearest_in_group("predatable", PREDATE_RANGE, func(n): return n.can_be_predated())
	eat_prompt.visible = target != null
	if target != null:
		eat_prompt.text = "Hold %s to eat" % Controls.eat_label()

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
	if _still != "":
		_draw_still()
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

## The species' body: its movement, and (with a sheet) its look in place of the slime's.
func _build_species_body() -> void:
	species_body = SpeciesBody.new(self, _shape, _rect)
	species_body.set_profile(MovementProfile.for_species(species))
	var look := species_body.profile.id
	var sheet: SpriteSheet = null
	if use_sheet:
		sheet = species_sheet_loader.call(look) if species_sheet_loader.is_valid() else SpeciesLook.sheet_for(look)
	if sheet == null:
		# No art for this species: not the slime's sheet under another body. The old frames stand in, tinted (see _update_visual_species).
		_sheet = null
		_base_sheet = null
		_form_sheet = null
		_animator = null
		return
	_sheet = sheet
	_base_sheet = sheet
	_form_sheet = null
	_animator = SlimeAnimator.new(SpeciesLook.clips_for(look))
	_animator.play(SpeciesLook.clip_for(look, true, 0.0, 0.0, 0.0))
	var first := _animator.frame()
	_sprite.texture = _sheet.frame_texture(first)
	_sprite.position.y = BODY_BOTTOM - _sheet.frame_size(first).y / 2.0
	if _shapes != null:
		_shapes.refresh(_sheet, first, false)

## The species' clip for what the body is doing, drawn at the sheet's own size; the facing mirrors it.
func _update_visual_species(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor:
		_land_timer = LAND_SQUASH_SECONDS
	_was_on_floor = on_floor
	_land_timer = maxf(0.0, _land_timer - delta)
	if rope != null:
		_update_rope_line()
	if _sheet == null:
		_draw_fallback_sprite()
		_sprite.modulate = PLACEHOLDER_TINT.get(species, Color.WHITE)
		return
	var st := species_body.state
	var look := species_body.profile.id
	if look == "spider":
		_draw_spider(delta)
		return
	if _still != "":
		_draw_still()
		return
	var clip := SpeciesLook.clip_for(look, on_floor, velocity.y, velocity.x, _land_timer, st.verb, VerbRunner.is_flat(st, species_body.profile), st.clinging)
	if clip == "" or not _sheet.has_frame(_animator_first_frame(clip)):
		clip = "idle"
	_animator.play(clip)
	_animator.advance(delta)
	var frame := _animator.frame()
	var glow := evolve_glow()
	var scale := body_scale() * (1.0 + EVOLVE_SWELL * glow)
	_sprite.texture = _sheet.frame_texture(frame)
	_sprite.position.y = BODY_BOTTOM - _sheet.frame_size(frame).y * scale / 2.0
	_sprite.scale = Vector2.ONE * scale
	var tint := body_tint().lerp(Color(2.2, 2.2, 2.2), glow * 0.8)
	if _invuln > INVULN_SECONDS - HURT_FLASH and not evolving():
		tint = tint.lerp(Color(1.0, 0.45, 0.45), 0.6)
	_sprite.modulate = tint
	_sprite.flip_h = (st.wall_side < 0) if clip == "wall" else facing < 0
	_shapes.refresh(_sheet, frame, _sprite.flip_h)

## A form with a still: that frame at the sheet's own size, mirrored when it faces left, swelling and glowing through the evolution
## moment, red for a moment when hurt. The hurt shape is the frame's traced one.
func _draw_still() -> void:
	var scale := _form_scale()
	var size := _sheet.frame_size(_still)
	_sprite.texture = _sheet.frame_texture(_still)
	_sprite.position.y = BODY_BOTTOM - size.y * scale / 2.0
	_sprite.scale = Vector2.ONE * scale
	_sprite.rotation = 0.0
	_sprite.modulate = _form_tint()
	_sprite.flip_h = facing < 0
	if _shapes != null:
		_shapes.refresh(_sheet, _still, _sprite.flip_h)

## The body's scale: the form's own, swelling through the evolution moment.
func _form_scale() -> float:
	return body_scale() * (1.0 + EVOLVE_SWELL * evolve_glow())

## The body's tint: the form's own, glowing through the evolution moment, red for a moment when hurt.
func _form_tint() -> Color:
	var tint := body_tint().lerp(Color(2.2, 2.2, 2.2), evolve_glow() * 0.8)
	if _invuln > INVULN_SECONDS - HURT_FLASH and not evolving():
		tint = tint.lerp(Color(1.0, 0.45, 0.45), 0.6)
	return tint

## The spider, after how spiders move: the legs follow the distance travelled (so they freeze the instant it stops), the body is
## rigid, the sprite turns to the surface and eases through a corner (the body changes surface in one tick; the sprite starts where
## it was and catches up), the head points the way it goes and a reversal pivots. The thread shows while it zips or hangs.
func _draw_spider(delta: float) -> void:
	var st := species_body.state
	var attached := st.surface_n != Vector2.ZERO
	var corner := st.surface_event == "concave" or st.surface_event == "convex"
	if corner:
		_spider_off += _spider_prev - global_position
	_spider_off = _spider_off.lerp(Vector2.ZERO, 1.0 - exp(-delta / SPIDER_CORNER_EASE))
	var zipping := st.zip_dir != Vector2.ZERO
	var dropping := st.drop_up > 0.0
	var target := SpeciesLook.surface_angle(st.surface_n) if attached else 0.0
	if dropping:
		target = PI / 2.0 if _spider_sense > 0.0 else -PI / 2.0  # head first down the thread
	if zipping:
		if absf(st.zip_dir.x) > 0.01:
			_spider_sense = signf(st.zip_dir.x)
		target = st.zip_dir.angle() if _spider_sense > 0.0 else wrapf(st.zip_dir.angle() + PI, -PI, PI)
	_spider_angle = lerp_angle(_spider_angle, target, 1.0 - exp(-delta / SPIDER_CORNER_EASE))
	if (attached and not corner) or dropping:
		_spider_stride = SpeciesLook.stride_advance(_spider_stride, st.surface_shift.length())
	var clip := "crawl_%d" % (SpeciesLook.stride_frame(_spider_stride) + 1) if (attached or dropping) and not zipping else "drop"
	if _still != "":
		clip = _still  # a form's one still stands in for every pose; the turning, the legs' timing and the thread are unchanged
	var vx := st.drop_vx if dropping else velocity.x
	var sense := st.surface_sigma if attached else (signf(vx) if absf(vx) > 20.0 else _spider_sense)
	if sense != _spider_sense:
		_spider_sense = sense
		_spider_pivot = SPIDER_PIVOT_SECONDS
	_spider_pivot = maxf(0.0, _spider_pivot - delta)
	var squeeze := 1.0 - 0.55 * sin(PI * (1.0 - _spider_pivot / SPIDER_PIVOT_SECONDS)) if _spider_pivot > 0.0 else 1.0
	var size := _sheet.frame_size(clip)
	var scale := _form_scale()
	_sprite.texture = _sheet.frame_texture(clip)
	_sprite.rotation = _spider_angle
	_sprite.flip_h = _spider_sense < 0.0  # the sprite's right is the clockwise tangent: against it, mirror
	_sprite.scale = Vector2(squeeze, 1.0) * scale
	_sprite.position = _spider_off + Vector2.UP.rotated(_spider_angle) * (size.y * scale / 2.0 - SurfaceStep.HN)
	_sprite.modulate = _form_tint()
	if _still != "" and _shapes != null:
		_shapes.refresh(_sheet, _still, _sprite.flip_h)  # a turned spider uses the body box instead (hurt_polygon)
	_spider_prev = global_position
	_update_thread(delta)

## The silk from behind the spider to its anchor while it zips or hangs, fading for a moment after.
func _update_thread(delta: float) -> void:
	if rope != null:
		return  # a rope's own line is drawn
	var st := species_body.state
	if st.zip_event == "start":
		_thread_anchor = global_position + st.zip_target
		_thread_dir = st.zip_dir
	if st.drop_event == "start":
		_thread_anchor = global_position + st.drop_target
		_thread_dir = Vector2.DOWN
	if st.zip_dir != Vector2.ZERO or st.drop_up > 0.0:
		_thread_alpha = 1.0
	else:
		_thread_alpha = maxf(0.0, _thread_alpha - delta / THREAD_FADE)
	rope_line.visible = _thread_alpha > 0.0
	rope_line.modulate.a = _thread_alpha
	rope_line.points = PackedVector2Array([global_position - _thread_dir * 8.0, _thread_anchor])

## The first frame of a clip (a clip the sheet's clip file lacks has none, and the body shows its idle).
func _animator_first_frame(clip: String) -> String:
	var frames: Array = SpeciesLook.clips_for(species_body.profile.id).get(clip, {}).get("frames", [])
	return str(frames[0]) if not frames.is_empty() else ""

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
	if species_body != null and species_body.is_crawling():
		return ShapeHit.rect_points(body_rect())  # the sprite is turned to the surface, the traced shape is not
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
	if _water.in_water:
		# a Jump in water is a bob from the floor (a swimmer's is the surface launch); it never falls through to the dry
		# branches, so a wall gives a non-swimmer nothing
		var launched = _water.jump(velocity, is_on_floor(), skillset.has("swim"), boost, global_position)
		if launched != null:
			velocity = launched
			sensors.jumped("ground")
		return
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
	end_channel()
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
	if _sheet == null or species_body != null or _still != "":
		return  # the cover is the slime's own frames; the other species eat without one until they have their own art
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
	last_inspected = c
	sensors.inspected(c.id, c.appraisal_target)
	inspect_report.emit(StatusText.creature_lines(_compendium.creature_report(c.id, _rules.level_of("appraisal"))))

func use_active(i: int) -> void:
	if not can_cast():
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
	ability.level = _rules.level_of(id)
	# Nothing held: zero, so each ability uses its own default (forward, or up-forward for Swing). Held includes the pointer.
	ability.aim = cast_aim()
	var channels := ability.can_channel()  # asked before anything is paid
	if not mana.spend(cost):
		not_enough_mp.emit(id)
		return
	if channels:
		ability.begin_channel()
		_channel = ability
		_channel_slot = i
		_channel_time = 0.0
		_channel_beat = 0.0
	else:
		ability.activate()
	last_cast = {"id": id, "aim": ability.aim_dir()}
	_emit.call(Events.SKILL_USED, {"id": id})
	for _point in cost:
		_emit.call(Events.MANA_SPENT, {})

## Steps the live channel, in this order: release, the MP beat, the cap, then the ability's own tick. Runs right after the
## four use_active checks, so the press tick is step 1.
func _channel_step(delta: float) -> void:
	if _channel == null:
		return
	if Input.get_action_raw_strength("active_%d" % (_channel_slot + 1)) < CHANNEL_RELEASE:
		end_channel(false)
		return
	_channel_time += delta
	_channel_beat += delta
	while _channel_beat >= CHANNEL_BEAT - CHANNEL_EPS:
		_channel_beat -= CHANNEL_BEAT
		if not mana.spend(1):
			end_channel(false)  # out of MP: silently
			return
		_emit.call(Events.MANA_SPENT, {})
	if _channel.max_channel > 0.0 and _channel_time >= _channel.max_channel - CHANNEL_EPS:
		end_channel(false)
		return
	if not _channel.channel_tick(delta):
		end_channel(false)

## Ends the live channel, if any. Any stop from outside the hold is hard (it also clears the ability's spray or strand at once);
## the hold running its course (release, MP, the cap, the ability's own tick) passes false.
func end_channel(hard := true) -> void:
	if _channel == null:
		return
	var c := _channel
	_channel = null
	c.end_channel(hard)

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
		rope_line.points = Vfx.sag_points(global_position, rope.anchor)

func award_xp(amount: int) -> void:
	if not health.is_dead():
		progression.add_xp(amount)

## Connected to every enemy's `downed` signal.
func on_enemy_downed(def: CreatureDef, spawn_key := "") -> void:
	if not health.is_dead():
		progression.award(spawn_key, "down", def.xp)

## Pays the price in held essence and unlocks a ready evolution. False when it is not ready or the price is not held.
func try_evolve(id: String) -> bool:
	if not _rules.evolve(id):
		return false
	EventBus.world_event.emit("evolved", {"id": id})
	return true

## The forms on offer right now (FormDefs): empty until the level cap is reached, and at the last stage.
func form_offers() -> Array:
	var out: Array = []
	if not progression.can_evolve():
		return out
	for id in FormOffers.offers(forms, form, _rules):
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

## The current form's nominal size (1.0 with none). body_scale() is 1.0 for the forms drawn from their own art, which are
## drawn larger natively; this is what the aim reticle scales by.
func form_size() -> float:
	var d := form_def()
	return d.size if d != null else 1.0

func body_scale() -> float:
	var d := form_def()
	return d.size if d != null and _form_sheet == null else 1.0

## Evolves the body into `id`: a legal next form, and (unless `force`, for tests and debugging) the level
## cap reached. Resets the level (keeping the level bonuses), raises the skill cap and re-checks
## every skill, applies the form's stats and traits, grants its skills, and changes the look. The
## collision box never changes.
func advance_form(id: String, force := false) -> bool:
	if health.is_dead() or (not force and not progression.can_evolve()):
		return false
	var from_def := form_def()
	var old_verb := from_def.verb if from_def != null else ""
	if not form.advance(id, forms):
		return false
	progression.evolve_stage()
	_rules.set_stage_cap(form.cap())
	var def: FormDef = forms[id]
	skillset.form_mods = FormEffects.modifiers(def)
	skillset.form_flags = FormEffects.flags(def)
	if old_verb != "" and def.verb != "":
		skillset.slots.replace(old_verb, def.verb)  # the new verb takes the old one's slot; the grant below finds it owned
	for g in def.grants:
		_rules.grant(g)
	_rules.recheck_levels()
	_use_form_sheet(def)
	skillset.refresh()
	_sync_max_hp()
	_begin_evolve_moment(def)
	EventBus.world_event.emit("evolved_body", {"id": id, "stage": form.stage})
	form_advanced.emit(id)
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
	end_channel()
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
	if species_body != null:
		_update_visual_species(delta)
	else:
		_update_visual(delta)

## Sets the character level a rebirth kit starts at (bonuses, no fanfare).
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
## Becomes the form `id` for a debug start (`--form=`): its species, then every form down its parent chain, each forced, and the
## evolve moment skipped. False for an id that is not a form (a species base, a typo): nothing changes.
func become_form(id: String) -> bool:
	if not forms.has(id):
		return false
	var chain: Array = []
	var current := id
	while forms.has(current):
		chain.push_front(current)
		current = str((forms[current] as FormDef).parents[0])
	set_species((forms[id] as FormDef).species)
	for f in chain:
		if not advance_form(f, true):
			return false
	_evolve_time = 0.0
	return true

func debug_grant_xp(amount: int) -> void:
	progression.add_xp(amount)

## A form's own sheet: its still (the art track's one frame per form) or, for the slime, an animated sheet of its own. A frame the
## sheet lacks, a sheet that is missing, or a species body with an animated sheet (a species' clips are its base's) keeps the base look.
func _use_form_sheet(def: FormDef) -> void:
	if _animator == null:
		return  # no sheet drawing at all (use_sheet false): there is nothing to swap
	var sheet: SpriteSheet = null
	if def.sprite_set != "" and SpriteSheet.available(def.sprite_set):
		sheet = SpriteSheet.load_set(def.sprite_set)
		if def.sprite_frame != "":
			if not sheet.has_frame(def.sprite_frame):
				sheet = null
		elif species_body != null:
			sheet = null
	if sheet != null:
		_form_sheet = sheet
		_sheet = sheet
		_still = def.sprite_frame
	else:
		_form_sheet = null
		_still = ""
		if _base_sheet != null:
			_sheet = _base_sheet

## The frame of the form's sheet drawn as its body, "" when the form animates.
func still_frame() -> String:
	return _still

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

## The left-stick-or-keys aim before snapping (the pointers, the right stick and the mouse, are deliberately excluded: see
## cast_aim(); spread and the rope reel read this). The stick is read raw from the pad that last moved:
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

## Tests set a world point here instead of moving the OS cursor.
var pointer_override := Vector2.INF

## Where the cursor points from the origin (the point skills fire from): ZERO unless the mouse was the last aimer, and the
## cursor is at least MOUSE_DEADZONE away. get_global_mouse_position() applies the camera and zoom. Controls._input owns the
## exclusion with the right stick (a pad input clears mouse_aim), so it is not re-checked here.
func mouse_direction() -> Vector2:
	if not Controls.mouse_aim:
		return Vector2.ZERO
	var cursor := get_global_mouse_position() if pointer_override == Vector2.INF else pointer_override
	var d := cursor - global_position
	return d if d.length() >= MOUSE_DEADZONE else Vector2.ZERO

## The pointer's direction (the right stick, else the mouse): free (any angle) but for the axis snap, ZERO when neither is
## engaged. The reticle and the cast both read this and nothing else.
func free_aim() -> Vector2:
	var s := Controls.right_stick()
	if s == Vector2.ZERO:
		s = mouse_direction()
	if s == Vector2.ZERO:
		return Vector2.ZERO
	var d := s.normalized()
	if absf(d.y) <= AXIS_SNAP:
		return Vector2(signf(d.x), 0.0)
	if absf(d.x) <= AXIS_SNAP:
		return Vector2(0.0, signf(d.y))
	return d

## What a skill is fired along: the pointer if one is engaged, else the left stick or keys (8-way), else ZERO ("nothing
## held": each ability uses its own default). raw_aim() is deliberately not touched, so a pointer never drives the puddle
## spread or the rope reel.
func cast_aim() -> Vector2:
	var free := free_aim()
	if free != Vector2.ZERO:
		return free
	return aim_vector() if aim_held() else Vector2.ZERO

## A press on an active slot would do something now: today's guards, plus the evolve moment (unreachable in play, since
## _physics_process returns before any cast while evolving).
func can_cast() -> bool:
	return not (health.is_dead() or predation.active() or _channel != null or evolving())

## `from` is the attacker's position for contact hits; the slime is knocked away from it.
func receive_hit(raw: int, damage_type: String, from: Vector2 = Vector2.INF, cause: String = "") -> void:
	if _invuln > 0.0 or _ward > 0.0 or _in_roll_iframes() or health.is_dead():
		return
	last_hit_cause = cause if cause != "" else damage_type  # before take_hit: a lethal hit fires `died`
	end_channel()  # a hit ends any channel, including a poison hit that carries no `from`
	var m := skillset.incoming(damage_type, health.hp, health.max_hp)
	health.take_hit(Damage.hit(raw, damage_type, stats.get_stat("def"), m["percent_off"], m["flat_off"]), damage_type)
	_invuln = INVULN_SECONDS
	if from != Vector2.INF and not health.is_dead():
		var away := 1.0 if global_position.x >= from.x else -1.0
		velocity = Vector2(away * KNOCKBACK.x, KNOCKBACK.y) * skillset.knockback_factor()
		_dash = 0.2
		_dash_vx = velocity.x
		if species_body != null:  # a crawler let go of its surface; it may not grip again straight away
			species_body.state.surface_n = Vector2.ZERO
			species_body.state.surface_lock = SURFACE_LET_GO
	if damage_type == "shock" and not health.is_dead():
		_dash = maxf(_dash, SHOCK_STUN)  # after the knockback block, which assigns 0.2

## Steps the water model and emits what it saw: the audio edges and one `submerged` per second.
func _step_water(delta: float) -> Dictionary:
	var out := _water.step(get_tree(), global_position, delta)
	if out["entered"]:
		EventBus.world_event.emit("water_entered", {"pos": global_position})
	if out["exited"]:
		EventBus.world_event.emit("water_exited", {"pos": global_position})
	for i in int(out["submerged"]):
		_emit.call(Events.SUBMERGED, {})
	return out

func receive_poison(application: int, tick_amount: int, seconds: float) -> void:
	if _invuln > 0.0 or _ward > 0.0 or _in_roll_iframes() or health.is_dead():
		return
	receive_hit(application, "poison")
	_poison_left = seconds
	_poison_tick = tick_amount
	_poison_acc = 0.0

## Turns `from_units` of the first-pass element held most into `to_units` of the one held least (Transmute). False, and nothing
## spent, when no element is held enough or all are held evenly. The gained essence is announced like any absorbed essence.
func transmute_essence(from_units: int, to_units: int) -> bool:
	var held := {}
	for e in Essences.FIRST_PASS:
		held[e] = _rules.held(e)
	var pair := Essences.transmute_pair(held, from_units)
	if pair.is_empty() or not _rules.spend_essence(pair[0], from_units):
		return false
	for i in to_units:
		_emit.call(Events.ABSORBED, {"essence": pair[1], "source": "transmute"})
	return true

## Falls no faster than `fall` px/s for `seconds`.
func glide(seconds: float, fall := GLIDE_FALL) -> void:
	_glide = maxf(_glide, seconds)
	_glide_fall = fall

## A species body inside a burst's window of invulnerability: the biped's roll and slide.
func _in_roll_iframes() -> bool:
	return species_body != null and species_body.state.invulnerable

## Untouchable for `seconds` (a longer ward already running is kept).
func ward(seconds: float) -> void:
	_ward = maxf(_ward, seconds)

func tick(delta: float) -> void:
	_invuln = maxf(0.0, _invuln - delta)
	_ward = maxf(0.0, _ward - delta)
	_glide = maxf(0.0, _glide - delta)
	if health.is_dead():
		return
	if _poison_left > 0.0:
		_poison_acc += delta
		while _poison_acc >= 1.0 - 0.0001 and _poison_left > 0.0:
			_poison_acc -= 1.0
			_poison_left -= 1.0
			var m := skillset.incoming("poison", health.hp, health.max_hp)
			_poison_milli += Damage.tick_milli(_poison_tick, m["percent_off"])
			var whole := floori(float(_poison_milli) / float(Damage.MILLI))
			_poison_milli -= whole * Damage.MILLI
			health.take_tick(whole)  # a whole HP drawn at 1 HP is spent all the same
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
	_dash_vx = velocity.x
	if species_body != null and species_body.is_crawling():  # a crawler's surface would hold it still: it leaves it
		species_body.state.surface_n = Vector2.ZERO
		species_body.state.surface_lock = SURFACE_LET_GO

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
	node.spec = SkillEffects.active_spec(d)
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
		var nd = n.get("def")
		if nd is CreatureDef and nd.untackleable:
			continue  # the jelly cannot be tackled, and must not swallow a tackle meant for a creature beyond it
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
	_still = ""
	if _base_sheet != null:
		_sheet = _base_sheet
	skillset.reset()
	_water.reset()
	drop_rope()
	end_channel()
	stats.reset_run()
	_sync_max_hp()

func _on_health_died() -> void:
	audio_events.reset()
	EventBus.world_event.emit("player_died", {})
	cancel_predate()
	drop_rope()
	end_channel()
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
	Vfx.style_strand(rope_line)  # silk, tiled along the rope
	rope_line.visible = false
	add_child(rope_line)
	_reticle = AimReticle.new()
	_reticle.bind(self)
	add_child(_reticle)
