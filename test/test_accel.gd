extends GutTest
## 匀加速子弹测试

func test_accel_default_zero():
	var bd := BulletData.new()
	assert_eq(bd.accel, Vector2.ZERO, "accel 默认应为 ZERO（匀速）")

func test_accel_builder():
	var bd := BulletData.new().accelerate(0, -4000)
	assert_eq(bd.accel, Vector2(0, -4000), "accelerate() 应设置加速度（世界方向 px/s²）")

func test_bullet_velocity_accelerates():
	# bind 带 accel 的子弹，验证每帧 velocity 递增 accel*dt
	var bullet = preload("res://scenes/bullet.tscn").instantiate()
	autofree(bullet)
	add_child(bullet)
	var bd := BulletData.new().player().speed(1000).accelerate(0, -1000)
	bullet.bind(bd, Vector2.UP)
	await get_tree().physics_frame
	var v0: float = bullet.velocity.y
	await get_tree().physics_frame
	var v1: float = bullet.velocity.y
	# 向上加速：y 方向越来越负
	assert_lt(v1, v0, "速度应随时间增大（竖直向上匀加速）")
	var dt := 1.0 / Engine.physics_ticks_per_second
	assert_almost_eq(v1 - v0, -1000.0 * dt, 0.5, "帧间速度增量应 = accel*dt = %f" % (-1000.0 * dt))

func test_bullet_position_goes_up_faster():
	var bullet = preload("res://scenes/bullet.tscn").instantiate()
	autofree(bullet)
	add_child(bullet)
	var bd := BulletData.new().player().speed(0).accelerate(0, -600)
	bullet.bind(bd, Vector2.UP)
	bullet.global_position = Vector2(448, 800)
	var y0: float = bullet.global_position.y
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_lt(bullet.global_position.y, y0, "子弹应向上移动")
