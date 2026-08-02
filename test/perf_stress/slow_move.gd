extends CoroutineScript
## 压力测试专用：匀速慢速移动（无重力，寿命长，保持高密度）
func _tick(_ctx: StageContext):
	if not target:
		return false
	target.global_position += target.velocity * get_dt()
	return true
