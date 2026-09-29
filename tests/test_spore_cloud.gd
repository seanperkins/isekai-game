extends GutTest
## Spore Cloud: a lingering cloud that slows and poisons enemies, never the player, and expires.

class StubActor extends Node2D:
	var team := "player"
	var facing := 1

var actor: StubActor
var creatures := {}
var skills_by_id := {}

func before_all() -> void:
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	for d in DefLoader.load_dir("res://data/skills"):
		skills_by_id[d.id] = d

func before_each() -> void:
	actor = StubActor.new()
	add_child_autofree(actor)

func _toad(pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures["toad"], skills_by_id)
	e.position = pos
	add_child_autofree(e)
	e.set_physics_process(false)  # no floor here: it would fall out of the cloud
	return e

func test_the_cloud_poisons_and_slows_an_enemy_inside_it_each_second() -> void:
	var toad := _toad(Vector2(30, 0))
	var cloud := SporeCloudArea.new()
	add_child_autofree(cloud)
	cloud.launch(Vector2(30, 0), 24.0, 2.0, actor)
	var hp := toad.health.hp
	await wait_physics_frames(72)
	assert_eq(toad.health.hp, hp - 1, "one poison damage after the first second")
	assert_lt(toad._speed(), Enemy.BASE_SPEED * toad.stats.get_stat("spd") / 100.0, "slowed")

func test_an_enemy_outside_the_radius_is_untouched() -> void:
	var toad := _toad(Vector2(200, 0))
	var cloud := SporeCloudArea.new()
	add_child_autofree(cloud)
	cloud.launch(Vector2(0, 0), 24.0, 2.0, actor)
	await wait_physics_frames(72)
	assert_eq(toad.health.hp, toad.health.max_hp)

func test_the_cloud_expires_and_is_in_its_own_group_not_hazards() -> void:
	var cloud := SporeCloudArea.new()
	add_child_autofree(cloud)
	cloud.launch(Vector2.ZERO, 24.0, 0.5, actor)
	assert_true(cloud.is_in_group("player_clouds"))
	assert_false(cloud.is_in_group("hazards"), "the puff group hurts the player; this one never does")
	await wait_physics_frames(50)
	assert_false(is_instance_valid(cloud) and cloud.is_inside_tree())

func test_the_cloud_never_touches_the_player_or_other_team_members() -> void:
	var ally := _toad(Vector2(10, 0))
	ally.team = "player"
	var cloud := SporeCloudArea.new()
	add_child_autofree(cloud)
	cloud.launch(Vector2(10, 0), 24.0, 2.0, actor)
	await wait_physics_frames(72)
	assert_eq(ally.health.hp, ally.health.max_hp, "same team as the caster")

func test_duration_grows_with_level_and_the_ability_drops_a_cloud() -> void:
	assert_almost_eq(SporeCloud.duration_for(1), 2.0, 0.0001)
	assert_almost_eq(SporeCloud.duration_for(8), 3.75, 0.0001)
	var ability := SporeCloud.new()
	add_child_autofree(ability)
	ability.setup(actor, [24, 28, 32, 36, 40, 44, 48, 52], 3)
	assert_true(ability.activate())
	var clouds := get_tree().get_nodes_in_group("player_clouds")
	assert_eq(clouds.size(), 1)
	assert_eq((clouds[0] as SporeCloudArea).radius, 32.0, "radius is the level's value")
