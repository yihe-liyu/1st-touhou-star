class_name EnemyService
extends RefCounted

var active: bool = true
var ctx: StageContext

func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	if not active: return null
	return StageManager.spawn_enemy(data, position, auto_start)

func spawn(key: String, pos: Vector2, params: Dictionary = {}) -> Enemy:
	var s: Script = AssetRegistry.enemies.get(key)
	if not s: return null
	return EnemyFactory.new().spawn_script(ctx, s, pos, params)

func spawn_boss(data: BossData, position: Vector2) -> void:
	if not active: return
	StageManager.spawn_boss(data, position, false, ctx)

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()
