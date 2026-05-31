extends Node
## 测试脚本：循环 memory_value -100→200→-100
## 挂到 game_scene 上测试水面效果

@export var speed: float = 25.0  # 每秒变化量
var _dir: int = 1


#func _process(delta: float) -> void:
	#GameState.memory_value += speed * delta * _dir
	#
	#if GameState.memory_value >= 200.0:
		#GameState.memory_value = 200.0
		#_dir = -1
	#elif GameState.memory_value <= -100.0:
		#GameState.memory_value = -100.0
		#_dir = 1
