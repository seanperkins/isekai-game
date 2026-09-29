extends SceneTree
## Shoots one demo room per biome so the biomes can be compared side by side:
## .tmp/shots/biome_<name>_<n>.png. The rooms only exist in memory: they are built here from each
## biome's prefab set and are not part of the world data. Needs a window (no --headless).
##   env HOME="$PWD/.tmp/gdhome" godot --path . -s tools/shoot_biomes.gd -- cave grotto flooded

const SHOTS := {  # camera focus x in the 1280-wide demo room
	"a": 320.0,
	"b": 960.0,
}

func _initialize() -> void:
	var biomes: Array = OS.get_cmdline_user_args()
	if biomes.is_empty():
		biomes = ["cave", "grotto", "flooded"]
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for _i in 4:
		await process_frame
	var world: World = game.world
	var dir := ProjectSettings.globalize_path("res://.tmp/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	for biome in biomes:
		var id: String = "DEMO_" + str(biome)
		world.rooms[id] = demo_room(id, biome)
		world.enter(id)
		world.set_physics_process(false)
		var rect := world.current_rect()
		game.player.velocity = Vector2.ZERO
		for key in SHOTS:
			var focus := rect.position + Vector2(SHOTS[key], 250)
			game.player.global_position = focus
			world.camera.global_position = World.view_center(rect, focus)
			for _i in 8:
				await process_frame
			var path := "%s/biome_%s_%s.png" % [dir, biome, key]
			root.get_texture().get_image().save_png(path)
			print("saved ", path)
		world.set_physics_process(true)
	quit(0)

## A 2x1 room dressed from the biome's own prefab set, plus a few ledges.
static func demo_room(id: String, biome: String) -> RoomDef:
	var f := {"id": id, "area": biome, "cell": Vector2i(0, 8), "size": Vector2i(2, 1),
		"start": Vector2(60, 308), "exits": [], "spawns": [], "features": []}
	var ids: Array = Prefabs.ids_for(biome)
	var floor_ids: Array = ids.filter(func(p): return not Prefabs.library()[p].get("ceiling", false) and p != "scatter")
	var x := 150.0
	for i in floor_ids.size():
		Prefabs.stamp(f, floor_ids[i], Vector2(x, 320), i % 2 == 1, biome)
		x += float(Prefabs.library()[floor_ids[i]]["width"]) + 90.0
	Prefabs.stamp(f, "scatter", Vector2(60, 320), false, biome)
	Prefabs.stamp(f, "stalactites", Vector2(200, 20), false, biome)
	Prefabs.stamp(f, "stalactites", Vector2(900, 20), true, biome)
	var solids: Array = f["solids"]
	solids.append(Rect2(330, 190, 130, 12))
	solids.append(Rect2(760, 170, 130, 12))
	var r := RoomDef.new()
	for k in f:
		r.set(k, f[k])
	return r
