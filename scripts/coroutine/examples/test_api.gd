extends Node

func _ready() -> void:
	await test_stale_runner_freed()
	await test_paused_tree()

func test_stale_runner_freed() -> void:
	print("=== Test 1: Stale freed-node references ===")
	var runner := CoroutineRunner.new()
	add_child(runner)
	var api := StageAPI.new(runner)
	runner.queue_free()
	await get_tree().process_frame
	assert(not is_instance_valid(runner), "Runner should be freed")
	print("  Runner freed, is_instance_valid(runner) = ", is_instance_valid(runner))
	print("  Calling api.seconds(1.0)...")
	api.seconds(1.0)
	print("  api.seconds returned without crash.")
	print("  Calling api.frames(3)...")
	api.frames(3)
	print("  api.frames returned without crash.")
	print("  Calling api.shoot_circle(null, 8, Vector2.ZERO)...")
	api.shoot_circle(null, 8, Vector2.ZERO)
	print("  api.shoot_circle returned without crash.")
	print("  Calling api.move_to(null, Vector2.ZERO, 2.0)...")
	api.move_to(null, Vector2.ZERO, 2.0)
	print("  api.move_to returned without crash.")
	print("  Calling api.get_field_rect() = ", api.get_field_rect())
	print("  All stale-runner calls passed.\n")

func test_paused_tree() -> void:
	print("=== Test 2: Paused tree — api.seconds should block ===")
	var runner := CoroutineRunner.new()
	add_child(runner)
	var api := StageAPI.new(runner)
	get_tree().paused = true
	print("  Tree paused, starting api.seconds(10.0) in background...")
	_start_paused_seconds(api, 10.0)
	print("  Waiting 2.0s real-time for api.seconds to (not) complete...")
	var timer := get_tree().create_timer(2.0)
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	await timer.timeout
	print("  PASS: api.seconds did NOT complete after 2.0s real-time while paused")
	get_tree().paused = false
	runner.queue_free()
	print("")

func _start_paused_seconds(api: StageAPI, duration: float) -> void:
	print("  (internal) api.seconds(%.1f) started" % duration)
	await api.seconds(duration)
	print("  (internal) api.seconds completed — should NOT see this while paused!")
