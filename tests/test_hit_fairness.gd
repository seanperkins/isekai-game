extends GutTest
## Guards for hit fairness, the class of bug where art or shape changes quietly make the game harsher:
## hit shapes that balloon past the drawn pixels, contact that starts before anything visibly touches
## (or misses when things visibly overlap), a hit shape that lurches between animation frames, a
## creature that can bite you from where you cannot tackle it, and damage that lands faster than
## the invulnerability window allows.
##
## The rule these pin: a hit happens where the drawn pixels meet.

const SETS := ["slime", "bat", "toad", "lizard", "spider"]
const CREATURES := ["bat", "toad", "lizard", "spider"]
## A shape may cover this much more area than the pixels it outlines: per frame, and averaged per set.
const MAX_FRAME_INFLATION := 1.4
const MAX_SET_INFLATION := 1.15
## Consecutive frames of one clip may change the hit shape's area by at most this factor.
const MAX_FRAME_JUMP := 1.8
## Contact may start when drawn pixels are this close. A fixed number on purpose: deriving it from
## Enemy.CONTACT_MARGIN would let a bigger margin pass its own test.
const NEAR_PX := 3.5

var rules: SkillRulesEngine
var player: Player
var creatures := {}
var skills := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d

func before_each() -> void:
	rules = autofree(SkillRulesEngine.new())
	rules.setup(DefLoader.load_dir("res://data/skills"))
	player = Player.new()
	player.setup(rules, CompendiumModel.new([], []), [], func(n: String, t: Dictionary) -> void: rules.handle_event(n, t))
	add_child_autofree(player)
	rules.start_run()
	var body := StaticBody2D.new()
	body.position = Vector2(0, BodyConfig.BOTTOM + 10)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(800, 20)
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)

func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return absf(a) * 0.5

func _opaque(sheet: SpriteSheet, image: Image, frame: String) -> int:
	var r := (sheet.frame_texture(frame) as AtlasTexture).region
	var n := 0
	for y in int(r.size.y):
		for x in int(r.size.x):
			if image.get_pixel(int(r.position.x) + x, int(r.position.y) + y).a >= 0.5:
				n += 1
	return n

# --- the shapes hug the pixels ---

func test_no_hit_shape_balloons_past_its_drawn_pixels() -> void:
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		var image := sheet.texture.get_image()
		var total_shape := 0.0
		var total_pixels := 0.0
		for n in sheet.frame_names():
			var pixels := _opaque(sheet, image, n)
			var shape := _area(sheet.hurt(n))
			total_shape += shape
			total_pixels += pixels
			assert_lte(shape, pixels * MAX_FRAME_INFLATION, "%s/%s: the hit shape is %.2fx its pixels" % [set_name, n, shape / pixels])
		assert_lte(total_shape, total_pixels * MAX_SET_INFLATION, "%s: shapes are %.2fx the pixels overall" % [set_name, total_shape / total_pixels])

func test_no_hit_shape_lurches_between_consecutive_frames_of_a_clip() -> void:
	var clip_files := {"slime": "res://data/slime_clips.json"}
	for set_name in CREATURES:
		clip_files[set_name] = ""
	var enemy_clips := SlimeAnimator.load_clips(Enemy.CLIPS)
	for set_name in SETS:
		var sheet := SpriteSheet.load_set(set_name)
		var clips: Dictionary = SlimeAnimator.load_clips("res://data/slime_clips.json") if set_name == "slime" else enemy_clips[set_name]
		for clip_name in clips:
			var frames: Array = clips[clip_name]["frames"]
			var pairs: Array = []
			for i in frames.size() - 1:
				pairs.append([frames[i], frames[i + 1]])
			if clips[clip_name]["loop"] and frames.size() > 1:
				pairs.append([frames[-1], frames[0]])
			for pair in pairs:
				if pair[0] == pair[1]:
					continue
				var a := _area(sheet.hurt(pair[0]))
				var b := _area(sheet.hurt(pair[1]))
				assert_lte(maxf(a, b) / minf(a, b), MAX_FRAME_JUMP, "%s/%s: %s -> %s changes the hit shape %.2fx in one frame" % [set_name, clip_name, pair[0], pair[1], maxf(a, b) / minf(a, b)])

# --- contact is where the pixels meet ---

func _pixels_near(a: Array, b: Array, limit: float) -> bool:
	for p in a:
		for q in b:
			if p.distance_to(q) <= limit:
				return true
	return false

## Global positions of a sprite's opaque pixel centres, every `step`-th one, optionally only its edge.
func _pixel_points(sprite: Sprite2D, image: Image, step: int, edge_only: bool) -> Array:
	var region := (sprite.texture as AtlasTexture).region
	var size := region.size
	var out: Array = []
	for y in range(0, int(size.y), 1):
		for x in range(0, int(size.x), 1):
			var px := image.get_pixel(int(region.position.x) + x, int(region.position.y) + y)
			if px.a < 0.5:
				continue
			if edge_only:
				var interior := true
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if nx < 0 or ny < 0 or nx >= size.x or ny >= size.y or image.get_pixel(int(region.position.x) + nx, int(region.position.y) + ny).a < 0.5:
						interior = false
						break
				if interior:
					continue
			elif (x + y) % step != 0:
				continue
			var lx := (float(x) + 0.5) - size.x / 2.0
			if sprite.flip_h:
				lx = -lx
			var ly := (float(y) + 0.5) - size.y / 2.0
			out.append(sprite.global_position + Vector2(lx, ly))
	return out

func test_contact_starts_only_when_drawn_pixels_meet_and_never_misses_an_overlap() -> void:
	await wait_physics_frames(14)  # the landing squash is over: the slime shows its idle frame
	var player_sprite: Sprite2D = player.get_node("Sprite")
	var player_pts := _pixel_points(player_sprite, player._sheet.texture.get_image(), 2, false)
	for id in CREATURES:
		var e := Enemy.new()
		e.setup(creatures[id], skills)
		add_child_autofree(e)
		e.set_physics_process(false)
		e.facing = -1
		var sheet: SpriteSheet = e._sheet
		var image := sheet.texture.get_image()
		for dx in range(20, 90, 2):
			e.global_position = Vector2(player.global_position.x + dx, player.global_position.y + Player.BODY_BOTTOM - Enemy.BODY_BOTTOM)
			e._update_visual(0.0)
			var enemy_pts := _pixel_points(e.get_node("Sprite"), image, 1, true)
			var touching := e.is_touching(player)
			var near := _pixels_near(enemy_pts, player_pts, NEAR_PX)
			var overlapping := _pixels_near(enemy_pts, player_pts, 0.8)
			if touching:
				assert_true(near, "%s at %d px: contact with no drawn pixels within %.1f px of each other" % [id, dx, NEAR_PX])
			if overlapping:
				assert_true(touching, "%s at %d px: drawn pixels overlap but there was no contact" % [id, dx])
		e.free()

# --- you can hit what can hit you ---

func test_every_creature_that_can_bite_the_slime_is_within_tackle_reach() -> void:
	await wait_physics_frames(14)
	for id in CREATURES:
		var e := Enemy.new()
		e.setup(creatures[id], skills)
		add_child_autofree(e)
		e.set_physics_process(false)
		e.facing = 1  # facing away, so even the lizard can be stunned
		var reach := 0
		for dx in range(20, 120):
			e.global_position = Vector2(player.global_position.x + dx, player.global_position.y + Player.BODY_BOTTOM - Enemy.BODY_BOTTOM)
			e._update_visual(0.0)
			if e.is_touching(player):
				reach = dx
		assert_gt(reach, 0, id)
		e.global_position = Vector2(player.global_position.x + reach, player.global_position.y + Player.BODY_BOTTOM - Enemy.BODY_BOTTOM)
		e._update_visual(0.0)
		assert_eq(player._tackle_target(), e, "%s bites from %d px away, so a tackle must reach it there" % [id, reach])
		e.free()

# --- damage cadence ---

func test_standing_in_a_creature_costs_at_most_one_hit_per_invulnerability_window() -> void:
	await wait_physics_frames(14)
	var e := Enemy.new()
	e.setup(creatures["toad"], skills)
	add_child_autofree(e)
	e.set_physics_process(false)
	e.global_position = Vector2(player.global_position.x + 20.0, player.global_position.y + Player.BODY_BOTTOM - Enemy.BODY_BOTTOM)
	e._update_visual(0.0)
	assert_true(e.is_touching(player))
	var before := player.health.hp
	var hits := 0
	var last := before
	var seconds := 3.2
	var frames := int(seconds * 60.0)
	for i in frames:
		player.receive_hit(e.stats.get_stat("atk"), "physical", e.global_position)  # what the enemy's contact does each physics frame
		player.tick(1.0 / 60.0)
		if player.health.hp < last:
			hits += 1
			last = player.health.hp
	assert_lte(hits, int(ceil(seconds / Player.INVULN_SECONDS)), "%d hits in %.1f s of continuous contact" % [hits, seconds])
	assert_gt(hits, 0, "the setup: contact does hurt")
