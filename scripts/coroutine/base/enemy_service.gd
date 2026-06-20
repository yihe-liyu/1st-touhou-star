class_name EnemyService
extends RefCounted
## 敌机服务 —— 拆自 StageAPI.spawn_enemy / spawn_boss

var active: bool = true
var ctx: StageContext

func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	if not active: return null
	return StageManager.spawn_enemy(data, position, auto_start)

func spawn_boss(data: BossData, position: Vector2) -> void:
	if not active: return
	StageManager.spawn_boss(data, position, false, ctx)

func spawn_composed(visual: PackedScene, move: Node, shoot: Node, pos: Vector2, opts: Dictionary = {}) -> Enemy:
	var f := EnemyFactory.new()
	return f.spawn(ctx, visual, move, shoot, pos, opts)

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()
