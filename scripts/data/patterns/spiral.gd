class_name SpiralPattern
extends PatternScript
## 螺旋弹幕示例 —— "接脚本的接口"的参考实现
##
## 用法演示（写一个新弹幕形状只需三步）：
##   1. extends PatternScript
##   2. 覆写 _tick，用 pattern_params()/bullet_data()/emit_at()/pattern_interval() 发弹
##   3. 注册：PatternRegistry.register_script("spiral", SpiralPattern)
##
## 参数（patterns 蓝图 params 里写）：
##   arms     螺旋臂数（默认 2）
##   step     每步旋转角（度，默认 12）
##   speed    弹速（可选，默认用 bullet_params.speed）
##   homing   自机狙修正（可选，bool）

var _angle := 0.0


func _tick(_ctx: StageContext) -> Variant:
	if not is_instance_valid(target):
		return false
	var arms := int(diff_pick(pattern_params().get("arms", 2)))
	var step := deg_to_rad(float(diff_pick(pattern_params().get("step", 12))))
	var b := bullet_data()
	if b == null:
		return pattern_interval()
	if pattern_params().has("speed"):
		b.speed(float(diff_pick(pattern_params().get("speed"))))
	# 经典螺旋：每臂沿当前角度发 1 颗，整体逐步旋转
	for i in arms:
		var dir := Vector2.DOWN.rotated(_angle + TAU * float(i) / float(arms))
		_ctx.bullets.shoot_spread(b, 1, 0, dir, emit_at())
	_angle += step
	return pattern_interval()
