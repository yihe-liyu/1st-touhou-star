extends GutTest
## 径向加速弹测试：加速度沿初始发射方向（角度），不偏转

const Radial = preload("res://data/stages/stage01/bullet/radial_accel_bullet.gd")


func test_accelerates_along_launch_direction() -> void:
	var cs: CoroutineScript = Radial.new()
	autofree(cs)  # CoroutineScript 是 Node，不挂树也不释放会成孤儿
	var bullet := Bullet.new()
	autofree(bullet)
	bullet.velocity = Vector2(0, 150)  # 向下发射
	bullet.global_position = Vector2(448, 500)  # 远离上版边（不触发撞边）
	cs.start_fast(null, bullet)

	cs.tick_fast(0.1)  # 记录方向 (0,1)，vel.y += 250*0.1 = 25
	cs.tick_fast(0.1)  # vel.y += 25
	cs.tick_fast(0.1)  # vel.y += 25

	assert_almost_eq(bullet.velocity.x, 0.0, 0.01, "x 方向不应加速（方向固定为发射角）")
	assert_almost_eq(bullet.velocity.y, 150.0 + 45.0, 0.01, "y 方向应沿发射角加速 45（accel_rate=150）")


func test_slanted_launch_stays_on_line() -> void:
	var cs: CoroutineScript = Radial.new()
	autofree(cs)
	var bullet := Bullet.new()
	autofree(bullet)
	bullet.velocity = Vector2(100, 0)  # 水平发射
	bullet.global_position = Vector2(448, 500)  # 远离上版边
	cs.start_fast(null, bullet)

	cs.tick_fast(0.1)
	cs.tick_fast(0.1)

	assert_almost_eq(bullet.velocity.y, 0.0, 0.01, "斜方向也只在发射方向加速")
	assert_almost_eq(bullet.velocity.x, 100.0 + 30.0, 0.01, "水平方向应加速 30（accel_rate=150）")


func test_bounce_down_on_top_edge() -> void:
	# 真子弹（带 sprite）+ 共享 ctx：撞上版边 → 回收自己 + 生成竖直向下匀速弹
	var data := BulletData.new().enemy().tex("棱弹").color(Color.FUCHSIA)
	data.velocity = Vector2(0, 120)
	var bullet: Bullet = BulletManager.shoot_enemy_bullet(data, Vector2(448, 500), Vector2.UP)
	assert_not_null(bullet, "应发射成功")
	if bullet == null:
		return
	var cs: CoroutineScript = Radial.new()
	autofree(cs)
	cs.start_fast(BulletManager.get_bullet_ctx(), bullet)

	# 移到版边附近再 tick → 触发撞边变轨
	bullet.global_position = Vector2(448, 30)
	var ret := cs.tick_fast(0.016)
	assert_false(ret, "撞边后协程应结束（自己删除）")

	# 新子弹：active_bullets 里应有一颗竖直向下、速度大小 = 撞边时速度
	var found := false
	for b in BulletManager._pool.active_bullets:
		if is_instance_valid(b) and b.velocity.y > 0 and absf(b.velocity.x) < 0.01:
			found = true
			assert_almost_eq(b.velocity.length(), 120.0, 0.5, "新弹应保留速度大小（撞边时速度≈120）")
			break
	assert_true(found, "应生成竖直向下的新子弹")
	BulletManager.clear_all()
