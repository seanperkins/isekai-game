extends SceneTree
## Builds default_bus_layout.tres from scratch. Run from the project root:
##   mkdir -p .tmp/gdhome && env HOME="$PWD/.tmp/gdhome" godot --headless -s tools/audio/build_bus_layout.gd

func _init() -> void:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	while AudioServer.get_bus_effect_count(0) > 0:
		AudioServer.remove_bus_effect(0, 0)
	for bus_name in ["Music", "Ambience", "SFX_Player", "SFX_Enemy", "SFX_World", "UI"]:
		var i := AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), AudioEffectAmplify.new())  # the duck
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.6
	reverb.damping = 0.5
	reverb.wet = 0.15
	reverb.dry = 1.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX_World"), reverb)
	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	quit(0 if err == OK else 1)
