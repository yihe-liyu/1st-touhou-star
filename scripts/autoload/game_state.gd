# GameState.gd
extends Node

var player: Player = null
var active_enemies: Array = []

func get_active_enemies() -> Array:
	return active_enemies

func clear_enemies():
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			for exec in enemy.executors:
				if is_instance_valid(exec):
					exec.stop()
			enemy.set_process(false)
			enemy.set_physics_process(false)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			if enemy.shoot_pattern:
				enemy.shoot_pattern = null
			enemy.queue_free()
	active_enemies.clear()
