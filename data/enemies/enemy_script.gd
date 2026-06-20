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
