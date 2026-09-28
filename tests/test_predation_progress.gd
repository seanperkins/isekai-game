extends GutTest
## How far through the eat hold we are (the frame animator and the eating cover read it).

func test_progress_runs_from_zero_to_one() -> void:
	var hold := PredationHold.new()
	assert_eq(hold.progress(), 0.0)
	hold.start(Node2D.new(), 100)
	assert_eq(hold.progress(), 0.0)
	hold.update(0.5)
	assert_almost_eq(hold.progress(), 0.5, 0.001)
	hold.update(2.0)
	assert_eq(hold.progress(), 1.0)
	hold.cancel()
	assert_eq(hold.progress(), 0.0)
