class_name EnemyService
extends RefCounted
## 敌机服务 —— 拆自 StageAPI.spawn_enemy / spawn_boss

var active: bool = true

func spawn_enemy(data: EnemyData, position: Vector2) -> Enemy:
	if not active: return null
	return StageManager.spawn_enemy(data, position)

func spawn_boss(data: BossData, position: Vector2, api: StageAPI = null) -> void:
	if not active: return
	StageManager.spawn_boss(data, position, api)  # ctx 暂为空

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()
