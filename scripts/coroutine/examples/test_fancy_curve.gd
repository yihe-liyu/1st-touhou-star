extends CreateScript
class_name TestFancyCurve

const LASER_DATA = preload("res://data/laser_data/test_laser_red.tres")

func _on_step(api: StageAPI) -> Variant:
	var enemy := get_parent() as Node2D
	if not enemy or not is_instance_valid(enemy):
		return false

	for i in 24:
		# 每条激光偏移一点角度，错开发射
		var base_angle := deg_to_rad(i * 15)
		var fancy_curve := _make_fancy_curve(enemy.global_position, base_angle)
		ctx.bullets.fire_growing_laser(LASER_DATA, enemy.global_position, fancy_curve)

	return ctx.clock.wait(9.0)


func _make_fancy_curve(origin: Vector2, offset_angle: float) -> Curve2D:

	var curve := Curve2D.new()
	var pos := origin
	var dir := Vector2.RIGHT.rotated(offset_angle)  # 初始方向

	# ═══════════════════════════════════
	# ① 转第一个圈（半径 90px，向左弯）
	# ═══════════════════════════════════
	const CIRCLE1_RADIUS := 90.0
	const CIRCLE1_STEPS := 40
	curve.add_point(origin)  # 起点 = 敌人位置
	var circle1_center := origin + dir * CIRCLE1_RADIUS
	for i in range(CIRCLE1_STEPS):
		var t := float(i) / CIRCLE1_STEPS
		var angle := TAU * t
		var pt := circle1_center + dir.rotated(angle) * CIRCLE1_RADIUS
		curve.add_point(pt)
	var circle1_dir := (curve.get_point_position(curve.get_point_count() - 1) -
		curve.get_point_position(curve.get_point_count() - 2)).normalized()
	pos = curve.get_point_position(curve.get_point_count() - 1)

	# ═══════════════════════════════════
	# ② 直飞一段（300px）
	# ═══════════════════════════════════
	#const STRAIGHT1_LEN := 300.0
	#const STRAIGHT1_STEPS := 30
	#for i in range(1, STRAIGHT1_STEPS + 1):
		#var t := float(i) / STRAIGHT1_STEPS
		#curve.add_point(pos + circle1_dir * STRAIGHT1_LEN * t)
	#pos = curve.get_point_position(curve.get_point_count() - 1)

	# ═══════════════════════════════════
	# ③ 转第二个圈（半径 80px，向右弯）
	# ═══════════════════════════════════
	const CIRCLE2_RADIUS := 360.0
	const CIRCLE2_STEPS := 50
	var perp := -circle1_dir.orthogonal()  # 垂直方向
	var circle2_center := pos + perp * CIRCLE2_RADIUS
	for i in range(CIRCLE2_STEPS):
		var t := float(i) / CIRCLE2_STEPS
		var angle := TAU * t
		var pt := circle2_center + circle1_dir.rotated(angle) * CIRCLE2_RADIUS
		curve.add_point(pt)
	pos = curve.get_point_position(curve.get_point_count() - 1)
	var circle2_dir := (curve.get_point_position(curve.get_point_count() - 1) -
		curve.get_point_position(curve.get_point_count() - 2)).normalized()

	# ═══════════════════════════════════
	# ④ 往回折返（弯向起点方向）
	# ═══════════════════════════════════
	const RETURN_STEPS := 40
	var return_target := origin  # 回起点
	for i in range(1, RETURN_STEPS + 1):
		var t := float(i) / RETURN_STEPS
		# 贝塞尔弯向起点
		var u := 1.0 - t
		var mid := pos + circle2_dir * 200.0  # 控制点：先沿当前方向走200px
		var pt := u * u * pos + 2 * u * t * mid + t * t * return_target
		curve.add_point(pt)

	return curve
