extends MoveScript
## 向下减速 → 停 3 秒 → 加速上飘离屏（时间线版）

var target_y: float = 200.0
var duration: float = 1.5
var wait_time: float = 3.0
var _speed: float = 0
var accel: float = 50.0

var _rand_angle: float


func start_moving(p_ctx: StageContext, p_target: Node2D):
	ctx = p_ctx
	target = p_target
	_rand_angle = RNG.randf_range(-0.6, 0.6)
	
	var tl := start_timeline()
	var end_pos := Vector2(target.global_position.x, target_y)
	
	# ① 下降
	target.create_tween().tween_property(target, "global_position", end_pos, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# ② 等待
	tl.at(duration)  # 锚点
	
	# ③ 上飘 — every frame
	tl.at(duration + wait_time).every(1.0/60.0).do(func():
		var dir := Vector2.UP.rotated(_rand_angle)
		target.global_position += dir * _speed / 60.0
		_speed += accel / 60.0
		if target.global_position.y < -100:
			target.queue_free()
	)
	
	super.start_moving(p_ctx, target)
