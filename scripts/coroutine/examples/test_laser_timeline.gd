# test_laser_timeline.gd —— 时间线版激光测试
extends CreateScript
class_name TestLaserTimeline

const LASER_DATA = preload("res://data/laser_data/test_laser_red.tres")
const BULLET_DATA = preload("res://data/bullet_data/test_enemy_bullet.tres")
const TimelineClass = preload("res://scripts/coroutine/base/timeline.gd")

var _tl


func _on_step(_ctx: StageContext) -> Variant:
	return _tl.tick(_ctx.clock.delta)


func start_creating(p_ctx: StageContext):
	ctx = p_ctx
	var enemy := get_parent() as Node2D
	_tl = TimelineClass.new(ctx)

	# ① 六向梭形激光
	_tl.at(0.0); _tl.do(func():
		for i in 12:
			var a := deg_to_rad(i * 30)
			var dir := Vector2.RIGHT.rotated(a)
			ctx.bullets.fire_straight_laser(LASER_DATA, enemy.global_position, dir, 800)
	)

	# ② 1.5秒后，每1.2秒撒圆弹 ×3
	_tl.at(1.5); _tl.every(1.2); _tl.times(3); _tl.do(func():
		ctx.bullets.shoot_spread(BULLET_DATA, 24, TAU, Vector2.DOWN, enemy.global_position)
	)

	# ③ 5.1秒后，每0.8秒自机狙曲线激光 ×6
	_tl.at(5.1); _tl.every(0.8); _tl.times(6); _tl.do(func():
		var p := ctx.player.get_player()
		if p and is_instance_valid(p):
			var to_p := (p.global_position - enemy.global_position).normalized()
			var curve := _make_s_curve(enemy.global_position, to_p, 500, 150)
			ctx.bullets.fire_growing_laser(LASER_DATA, enemy.global_position, curve)
	)

	_tl.at(12.0); _tl.loop()
	super.start_creating(p_ctx)


func _make_s_curve(origin: Vector2, to_player: Vector2, length: float, bend: float) -> Curve2D:
	var curve := Curve2D.new()
	curve.add_point(origin)
	var end := origin + to_player * length
	var mid := (origin + end) / 2.0
	var ctrl := mid + to_player.orthogonal() * bend
	const SAMPLES := 100
	for i in range(SAMPLES + 1):
		var t := float(i) / SAMPLES
		var u := 1.0 - t
		curve.add_point(u * u * origin + 2 * u * t * ctrl + t * t * end)
	return curve
