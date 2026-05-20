extends Node

var _test_results: Array[String] = []

func _ready():
	print("=== CoroutineRunner Tests ===")
	await test_basic_run()
	await test_stop_cancelled()
	await test_reentry_race()
	await test_exit_tree_no_cancelled()
	print("=== All tests completed ===")
	for result in _test_results:
		print("  ", result)

func _assert(condition: bool, message: String):
	if condition:
		_test_results.append("[PASS] " + message)
	else:
		_test_results.append("[FAIL] " + message)

func test_basic_run():
	var runner = CoroutineRunner.new()
	add_child(runner)

	var finished_emitted = false
	runner.finished.connect(func(): finished_emitted = true)

	runner.run(func(): pass)
	await get_tree().process_frame

	_assert(finished_emitted, "Basic run emits finished signal")
	runner.queue_free()

func test_stop_cancelled():
	var runner = CoroutineRunner.new()
	add_child(runner)

	var cancelled_emitted = false
	var finished_emitted = false
	runner.cancelled.connect(func(): cancelled_emitted = true)
	runner.finished.connect(func(): finished_emitted = true)

	runner.run(func(): await get_tree().create_timer(10.0).timeout)
	runner.stop()

	await get_tree().process_frame

	_assert(cancelled_emitted, "stop() emits cancelled signal")
	_assert(not finished_emitted, "stop() does NOT emit finished signal")
	runner.queue_free()

func test_reentry_race():
	var runner = CoroutineRunner.new()
	add_child(runner)

	var finished_count = 0
	var cancelled_count = 0
	runner.finished.connect(func(): finished_count += 1)
	runner.cancelled.connect(func(): cancelled_count += 1)

	runner.run(func():
		await get_tree().create_timer(10.0).timeout
	)

	runner.run(func():
		await get_tree().create_timer(0.1).timeout
	)

	await get_tree().create_timer(0.5).timeout

	_assert(cancelled_count == 1, "Re-entry: cancelled emitted exactly once")
	_assert(finished_count == 1, "Re-entry: finished emitted exactly once (only B)")
	runner.queue_free()

func test_exit_tree_no_cancelled():
	var cancelled_emitted = false

	var runner = CoroutineRunner.new()
	add_child(runner)

	runner.cancelled.connect(func(): cancelled_emitted = true)

	runner.run(func():
		await get_tree().create_timer(10.0).timeout
	)

	runner.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert(not cancelled_emitted, "queue_free does NOT emit cancelled signal")
