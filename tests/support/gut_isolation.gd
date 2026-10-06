class_name GutIsolation
extends GutHookScript
## Run before the suite (tools/run_tests.sh passes it as GUT's pre-run script): every test script starts from the input state the game starts with. A test that sent a mouse click or a pad
## button through the real input path leaves the Controls autoload on the mouse or the pad, and the next test file that happens to run after it in the same process aims at a pointer nobody
## moved or reads "Start" for "Esc": passing alone, failing in another order, which a suite dealt out to several processes makes every run.

func run() -> void:
	gut.start_script.connect(func(_script) -> void: fresh())

## The state the game starts with: no device last used, nothing held.
static func fresh() -> void:
	Controls.forget_device()
	for action in InputMap.get_actions():
		Input.action_release(action)
