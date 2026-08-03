extends CoroutineScript
## Boss 入场脚本示例（stage01 风格）：从左侧飞入到舞台中央
## 挂到 BossData.enter_script；target = Boss，用 tween 控制移动

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	# 从左侧 (-50, 500) 飞入到 (448, 250)（stage01 卡摩瑞入场）
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "global_position", Vector2(GameConfig.FIELD_CENTER_X, 250), 1.5)
	# 入场演出完成后自动结束
	tw.tween_callback(func(): stop())
