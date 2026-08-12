extends GutTest
## 径向加速弹测试：加速度沿初始发射方向（角度），不偏转

const Radial = preload("res://data/stages/stage01/bullet/radial_accel_bullet.gd")


func test_accelerates_along_launch_direction() -> void:
	var cs: CoroutineScript = Radial.new()
	var bullet := Bullet.new()
	bullet.velocity = Vector2(0, 150)  # 向下发射
	cs.start_fast(null, bullet)

	cs.tick_fast(0.1)  # 记录方向 (0,1)，vel.y += 250*0.1 = 25
	cs.tick_fast(0.1)  # vel.y += 25
	cs.tick_fast(0.1)  # vel.y += 25

	assert_almost_eq(bullet.velocity.x, 0.0, 0.01, "x 方向不应加速（方向固定为发射角）")
	assert_almost_eq(bullet.velocity.y, 150.0 + 75.0, 0.01, "y 方向应沿发射角加速 75")


func test_slanted_launch_stays_on_line() -> void:
	var cs: CoroutineScript = Radial.new()
	var bullet := Bullet.new()
	bullet.velocity = Vector2(100, 0)  # 水平发射
	cs.start_fast(null, bullet)

	cs.tick_fast(0.1)
	cs.tick_fast(0.1)

	assert_almost_eq(bullet.velocity.y, 0.0, 0.01, "斜方向也只在发射方向加速")
	assert_almost_eq(bullet.velocity.x, 100.0 + 50.0, 0.01, "水平方向应加速 50")
