extends GutTest
## The creature size ladder: every creature's first frame (px, as drawn in game), pinned so a change of art is a decision and
## not a drift. Sean, 2026-10-04: every monster must feel the right size next to the others; the player's body boxes and reach
## are tuned to fit that, not the other way round. Sizes within 2 px (the anchored sheets round).

const LADDER := {
	"vine_snake": ["slither_1", 46, 13],
	"lizard": ["idle_1", 56, 18],
	"spider": ["hang_1", 33, 23],
	"toad": ["idle_1", 40, 25],
	"bat": ["fly_1", 29, 29],
	"slime": ["idle_1", 44, 33],
	"spore_moth": ["fly_1", 30, 33],
	"drift_jelly": ["drift_1", 34, 34],
	"gloom_wolf": ["idle_1", 54, 37],
	"cave_crayfish": ["idle_1", 44, 37],
	"mushroom_crab": ["idle_1", 44, 37],
	"armed_ant": ["idle_1", 31, 38],
	"pale_moth": ["fly_1", 34, 38],
	"goblin": ["idle_1", 17, 39],
	"bog_lizardman": ["idle_1", 40, 48],
	"stone_drake": ["idle_1", 108, 50],
	"taratect": ["hang_1", 90, 62],
}

func _size(id: String) -> Vector2:
	var sheet := SpriteSheet.load_set(id)
	return sheet.frame_size(LADDER[id][0])

func test_every_creature_is_the_size_the_ladder_says() -> void:
	for id in LADDER:
		var size := _size(id)
		assert_almost_eq(size.x, float(LADDER[id][1]), 2.0, "%s width" % id)
		assert_almost_eq(size.y, float(LADDER[id][2]), 2.0, "%s height" % id)

func test_the_stone_drake_looms_over_the_wolf() -> void:
	assert_gte(_size("stone_drake").y, _size("gloom_wolf").y * 1.3)
	assert_gte(_size("stone_drake").x, _size("gloom_wolf").x * 1.8)

func test_the_boss_spider_towers_over_the_player_spider() -> void:
	assert_gte(_size("taratect").x, _size("spider").x * 2.5)
	assert_gte(_size("taratect").y, _size("spider").y * 2.5)

func test_the_armed_ant_is_no_taller_than_the_goblin() -> void:
	assert_lte(_size("armed_ant").y, _size("goblin").y)

func test_the_pale_moth_is_well_under_the_lizardman() -> void:
	assert_lt(_size("pale_moth").y, _size("bog_lizardman").y * 0.85)
