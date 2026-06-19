# boss_ex_shoot.gd
extends CreateScript
## 示例：每0.5秒打3发自机狙

const BULLET_DATA = preload("res://data/bullet_data/test_enemy_bullet.tres")

var _tick: int = 0

func _on_step(_api: StageAPI) -> Variant:
	_tick += 1
	if _tick < 30:  # ~0.5s
		return true
	_tick = 0
	
	var parent := get_parent()
	if not parent is Node2D: return true
	var pos := (parent as Node2D).global_position
	var player := GameState.player
	if not player: return true
	
	var base := (player.global_position - pos).angle()
	for i in range(3):
		var a := base + deg_to_rad((i - 1) * 10.0)
		ctx.bullets.shoot_spread(BULLET_DATA, 1, 0, Vector2(cos(a), sin(a)), pos)
	return true
