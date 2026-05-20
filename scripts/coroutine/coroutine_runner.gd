extends Node
class_name CoroutineRunner

signal finished()
signal cancelled()

var is_running: bool = false

func run(method: Callable):
	if is_running:
		stop()
	is_running = true
	_execute(method)

func _execute(method: Callable):
	await method.call()
	if is_running:
		is_running = false
		finished.emit()

func stop():
	if not is_running:
		return
	is_running = false
	cancelled.emit()
