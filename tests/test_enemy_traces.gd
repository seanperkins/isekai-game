extends GutTest
## The characterization of every enemy behaviour, recorded on the code BEFORE the state-machine refactor and asserted here
## unchanged: per scenario the run-length transitions of the observable state, the hazards and events with their ticks, the
## stub player's hit count and first-hit tick, its poisons, and the end position. The full per-tick differential lives in
## tools/enemy_trace.sh (not committed); this is the compact part a reader can check. Regenerate ONLY when a behaviour is
## meant to change: TRACE_LABEL=x TRACE_EMIT=1 tools/enemy_trace.sh.

var expected := {}

func before_all() -> void:
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string("res://tests/support/enemy_trace_expected.json"))
	expected = json.data

## JSON turns every number into a float: compare through the same round trip.
func _norm(v):
	return JSON.parse_string(JSON.stringify(v))

func test_every_scenario_is_pinned() -> void:
	var names := EnemyScenarios.all().map(func(sc): return sc["name"])
	names.sort()
	var keys := expected.keys()
	keys.sort()
	assert_eq(keys, names, "the expectations cover exactly the scenarios")

func _check(name: String) -> void:
	var sc: Dictionary = {}
	for s in EnemyScenarios.all():
		if s["name"] == name:
			sc = s
	var r: Dictionary = await EnemyRecorder.run(self, sc)
	var want: Dictionary = expected[name]
	var end: Dictionary = r["samples"][r["samples"].size() - 1]
	assert_eq(_norm(EnemyRecorder.transitions(r["samples"])), want["transitions"], "%s: transitions" % name)
	assert_eq(_norm(r["events"]), want["events"], "%s: events" % name)
	assert_eq(_norm(r["hazards"]), want["hazards"], "%s: hazards" % name)
	assert_eq(_norm(EnemyRecorder.summary(r["hits"])), want["hits"], "%s: contact hits" % name)
	assert_eq(_norm(r["poisons"]), want["poisons"], "%s: poisons" % name)
	assert_eq(_norm([end["x"], end["y"]]), want["end"], "%s: end position" % name)

func test_walkers() -> void:
	for n in ["walker_patrol", "walker_chase"]:
		await _check(n)

func test_the_toad() -> void:
	for n in ["toad_spit", "toad_stunned_right_after_spitting"]:
		await _check(n)

func test_the_armored_chargers() -> void:
	for n in ["lizard_plain", "lizard_stunned_mid_windup", "lizard_stunned_mid_charge", "lizard_stunned_mid_rest", "lizard_killed_in_windup", "crab_plain"]:
		await _check(n)

func test_the_bat() -> void:
	for n in ["bat_plain", "bat_stunned_in_warn", "bat_stunned_in_dive", "bat_killed_in_warn", "bat_alert_lost_then_found_again", "bat_slowed"]:
		await _check(n)

func test_the_spider() -> void:
	for n in ["spider_drop", "spider_stunned_hanging"]:
		await _check(n)

func test_the_moth() -> void:
	for n in ["moth_plain", "moth_leaves_and_returns", "moth_stunned_in_flash", "moth_player_leaves_mid_flash"]:
		await _check(n)

func test_the_snake() -> void:
	for n in ["snake_plain", "snake_stunned_in_coil", "snake_stunned_in_lunge", "snake_stunned_in_retreat"]:
		await _check(n)

# --- the legacy single-sprite path (no sheet), which reads the same behaviour state ---

func _enemy(id: String) -> Enemy:
	var creatures := {}
	for c in DefLoader.load_dir("res://data/creatures"):
		creatures[c.id] = c
	var skills := {}
	for d in DefLoader.load_dir("res://data/skills"):
		skills[d.id] = d
	var e := Enemy.new()
	e.use_sheet = false
	e.setup(creatures[id], skills)
	add_child_autofree(e)
	return e

func test_the_legacy_frame_names_read_the_behaviour_state() -> void:
	var toad := _enemy("toad")
	assert_eq(toad.frame_name(), "toad_idle")
	toad._state = "puff"
	toad._state_t = 0.3
	assert_eq(toad.frame_name(), "toad_spit", "a toad puffing up")
	toad._state = ""
	toad._spit_cd = Enemy.SPIT_COOLDOWN
	assert_eq(toad.frame_name(), "toad_spit", "and for a moment after the spit")
	var spider := _enemy("spider")
	assert_eq(spider.frame_name(), "spider_hang")
	spider._on_ceiling = false
	assert_eq(spider.frame_name(), "spider_crawl")
