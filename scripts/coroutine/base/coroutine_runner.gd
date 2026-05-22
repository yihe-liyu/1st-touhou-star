extends Node
class_name CoroutineRunner

signal finished()
signal cancelled()

var is_running: bool = false
var _run_id: int = 0

func run(method: Callable):
	if is_running:
		stop()
	_run_id += 1
	is_running = true
	_execute(method, _run_id)

func _execute(method: Callable, run_id: int):
	await method.call()
	if is_running and _run_id == run_id:
		is_running = false
		finished.emit()

func stop():
	if not is_running:
		return
	is_running = false
	cancelled.emit()

func _exit_tree():
	if is_running:
		is_running = false
