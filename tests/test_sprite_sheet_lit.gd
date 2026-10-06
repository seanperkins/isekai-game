extends GutTest
## A sheet may carry normal maps laid out as its colour sheet: a frame then draws as a CanvasTexture the room's lights shade, mirrored (with its
## normal map's red channel flipped) when its creature faces left. tests/support/sheets holds a two-frame fixture.

var _saved := ""

func before_each() -> void:
	_saved = SpriteSheet.dir
	SpriteSheet.dir = "res://tests/support/sheets/"

func after_each() -> void:
	SpriteSheet.dir = _saved

func test_a_sheet_with_a_normal_map_says_so_and_one_without_does_not() -> void:
	assert_true(SpriteSheet.load_set("fixture_lit").has_normals())
	assert_false(SpriteSheet.load_set("fixture_plain").has_normals())

func test_a_lit_frame_is_the_frame_cut_from_both_sheets() -> void:
	var sheet := SpriteSheet.load_set("fixture_lit")
	var t := sheet.lit_texture("a") as CanvasTexture
	assert_not_null(t)
	assert_eq(t.diffuse_texture.get_size(), Vector2(4, 3))
	assert_eq(t.normal_texture.get_size(), Vector2(4, 3))
	var color := t.diffuse_texture.get_image()
	assert_eq(color.get_pixel(0, 0), Color8(220, 40, 40))
	assert_eq(color.get_pixel(3, 0), Color8(40, 40, 220))
	assert_eq(t.normal_texture.get_image().get_pixel(0, 0), Color8(200, 128, 255))

func test_the_second_frame_is_cut_from_its_own_rect() -> void:
	var t := SpriteSheet.load_set("fixture_lit").lit_texture("b") as CanvasTexture
	assert_eq(t.diffuse_texture.get_size(), Vector2(2, 2))
	assert_eq(t.diffuse_texture.get_image().get_pixel(1, 1), Color8(40, 220, 40))
	assert_eq(t.normal_texture.get_image().get_pixel(0, 0), Color8(128, 200, 230))

func test_a_frame_facing_left_is_mirrored_and_its_normals_have_their_red_flipped() -> void:
	var t := SpriteSheet.load_set("fixture_lit").lit_texture("a", true) as CanvasTexture
	var color := t.diffuse_texture.get_image()
	assert_eq(color.get_pixel(0, 0), Color8(40, 40, 220), "the picture is mirrored")
	assert_eq(color.get_pixel(3, 0), Color8(220, 40, 40))
	var n := t.normal_texture.get_image()
	assert_eq(n.get_pixel(0, 0), Color8(255 - 50, 128, 255), "a surface that faced right now faces left: red is inverted")
	assert_eq(n.get_pixel(3, 0), Color8(255 - 200, 128, 255))

func test_a_transparent_pixel_stays_transparent_when_mirrored() -> void:
	var sheet := SpriteSheet.load_set("fixture_lit")
	assert_eq(sheet.lit_texture("a", true).get_size(), Vector2(4, 3))

func test_pixel_art_is_not_smoothed() -> void:
	var t := SpriteSheet.load_set("fixture_lit").lit_texture("a") as CanvasTexture
	assert_eq(t.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)

func test_a_lit_frame_is_cut_once() -> void:
	var sheet := SpriteSheet.load_set("fixture_lit")
	assert_same(sheet.lit_texture("a"), sheet.lit_texture("a"))
	assert_not_same(sheet.lit_texture("a"), sheet.lit_texture("a", true))

func test_a_sheet_without_normals_has_no_lit_texture() -> void:
	assert_null(SpriteSheet.load_set("fixture_plain").lit_texture("a"))

func test_a_plain_sheet_still_draws_as_an_atlas() -> void:
	var sheet := SpriteSheet.load_set("fixture_plain")
	assert_true(sheet.frame_texture("a") is AtlasTexture)
