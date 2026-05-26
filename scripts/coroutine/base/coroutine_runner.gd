extends Node
class_name CoroutineRunner

signal finished()
signal cancelled()

var is_running: bool = false
var _runs: Dictionary = {}
var _next_run_id: int = 0

func run(method: Callable):
	stop()
	_start_run(method)

func run_parallel(method: Callable):
	_start_run(method)

func _start_run(method: Callable):
	var run_id = _next_run_id
	_next_run_id += 1
	_runs[run_id] = true
	is_running = true
	_execute(method, run_id)

func _execute(method: Callable, run_id: int):
	await method.call()
	if not _runs.has(run_id):
		return
	_runs.erase(run_id)
	if _runs.is_empty():
		is_running = false
		finished.emit()

func stop():
	if not is_running:
		return
	_runs.clear()
	is_running = false
	cancelled.emit()

func _exit_tree():
	if is_running:
		_runs.clear()
		is_running = false
