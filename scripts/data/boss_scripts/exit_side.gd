extends CoroutineScript
## Boss 退场脚本示例：向右上方飞出后销毁
## 挂到 BossData.exit_script；target = Boss

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "global_position", Vector2(GameConfig.FIELD_RIGHT + 100, -80), 2.0)
	tw.tween_callback(func():
		if is_instance_valid(target):
			target.queue_free()
	)
