extends Node
class_name EnemyMovement

signal finished()

var enemy: Enemy

func start(e: Enemy, wave: WaveData):
	enemy = e
	_on_start()

func _on_start():
	pass

func _physics_process(delta: float):
	pass

func stop():
	finished.emit()
	queue_free()
