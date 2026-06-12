# boss_shoot_test.gd
extends CreateScript

const BULLET_DATA = preload("res://data/bullet_data/test_enemy_bullet.tres")

var _tick: int = 0

func _on_step(_api: StageAPI) -> Variant:
	_tick += 1
	if _tick < 20:  # ~0.3s at 60fps
		return true
	_tick = 0
	
	var parent := get_parent()
	if not parent is Node2D:
		return true
	
	var boss_pos := (parent as Node2D).global_position
	var player := GameState.player
	if not player:
		return true
	
	var base := (player.global_position - boss_pos).angle()
	for i in range(5):
		var a := base + deg_to_rad((i - 2) * 15.0)
		_api.shoot_spread(BULLET_DATA, 1, 0, Vector2(cos(a), sin(a)), boss_pos)
	return true
