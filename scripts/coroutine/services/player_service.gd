class_name PlayerService
extends RefCounted
## 玩家服务 —— 只读访问玩家状态

func get_player() -> Player:
	return GameState.player

func get_position() -> Vector2:
	var p := GameState.player
	return p.global_position if p else Vector2.ZERO
