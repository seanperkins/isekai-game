extends GutTest
## Not a `test_` file, so the suite never runs it: it is run by tools/enemy_trace.sh. Writes the FULL per-tick trace of every
## scenario to .tmp/enemy-trace/<TRACE_LABEL>.json (the differential the refactor is diffed against), and with TRACE_EMIT=1 also
## writes the compact expectations tests/support/enemy_trace_expected.json that test_enemy_traces.gd asserts.

func test_dump() -> void:
	var label := OS.get_environment("TRACE_LABEL")
	if label == "":
		pass_test("no TRACE_LABEL: nothing to dump")
		return
	var full := {}
	var compact := {}
	for sc in EnemyScenarios.all():
		var r: Dictionary = await EnemyRecorder.run(self, sc)
		full[sc["name"]] = r
		var end: Dictionary = r["samples"][r["samples"].size() - 1] if not r["samples"].is_empty() else {}
		compact[sc["name"]] = {"transitions": EnemyRecorder.transitions(r["samples"]), "events": r["events"],
			"hazards": r["hazards"], "hits": EnemyRecorder.summary(r["hits"]), "poisons": r["poisons"],
			"end": [end.get("x", 0), end.get("y", 0)]}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tmp/enemy-trace"))
	var f := FileAccess.open("res://.tmp/enemy-trace/%s.json" % label, FileAccess.WRITE)
	f.store_string(JSON.stringify(full))
	f.close()
	if OS.get_environment("TRACE_EMIT") == "1":
		var e := FileAccess.open("res://tests/support/enemy_trace_expected.json", FileAccess.WRITE)
		e.store_string(JSON.stringify(compact, "\t"))
		e.close()
	assert_gt(full.size(), 0)
