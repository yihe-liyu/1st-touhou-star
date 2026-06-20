extends CoroutineRunner
class_name EnemyScript
## 敌人脚本基类——一个文件 = 外观 + 移动 + 弹幕

var enemy: Enemy
var ctx: StageContext
var _tl: Timeline

func start_timeline() -> Timeline:
	_tl = Timeline.new(ctx)
	return _tl

func setup(_enemy: Enemy, _ctx: StageContext) -> void:
	enemy = _enemy
	ctx = _ctx

func _on_step(_ctx: StageContext) -> Variant:
	if _tl:
		_tl.tick(get_physics_process_delta_time())
	return true

func start() -> void:
	run(_on_step.bind(ctx))

func make_bullet(tex_key: String, speed: int, color: Color) -> BulletData:
	var b := BulletData.new()
	b.texture = AssetRegistry.bullet_textures.get(tex_key)
	b.velocity = Vector2(0, speed)
	b.tint = color
	b.faction = BulletData.Faction.ENEMY
	b.can_be_canceled = true
	return b
