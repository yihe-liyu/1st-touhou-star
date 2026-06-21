class_name EnemyService
## 敌人生成服务
extends RefCounted

var active: bool = true
var ctx: StageContext

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")


const SCRIPTS := {
	"red_soldier": preload("res://data/enemies/red_soldier.gd"),
}

func spawn(key: String, pos: Vector2) -> EnemyData:
	## 返回 EnemyData 构造链，最后 .spawn() 生成
	var ed := EnemyData.new()
	ed._spawn_meta = {"key": key, "pos": pos, "svc": self}
	return ed

func spawn_boss(data: BossData, position: Vector2) -> void:
	if not active: return
	StageManager.spawn_boss(data, position, false, ctx)

func all_defeated() -> bool:
	return GameState.active_enemies.is_empty()
