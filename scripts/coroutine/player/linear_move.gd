extends CoroutineScript
## 极简线性移动：替代 _physics_process 默认路径
## auto_stop = false

func _tick(_p_ctx: StageContext):
	if not target: return false
	target.global_position += target.velocity / Engine.physics_ticks_per_second
	return true
