# GameState.gd
extends Node

var player: Player = null
var active_enemies: Array = []

func get_active_enemies() -> Array:
	return active_enemies
