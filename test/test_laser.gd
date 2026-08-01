extends GutTest
## Laser 2.0 骨架 + 状态机 + 判定测试（第 1 步：测试地基）

# ── 骨架 ──

func test_skeleton_line_sampling():
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 100))
	assert_eq(sk.total_length, 100.0, "直线骨架总长 = 100")
	assert_eq(sk.sample_at(0), Vector2(0, 0), "起点")
	assert_eq(sk.sample_at(100), Vector2(0, 100), "终点")
	assert_eq(sk.sample_at(50), Vector2(0, 50), "中点")
	assert_eq(sk.tangent_at(50), Vector2(0, 1), "竖直切线向下")

func test_skeleton_curve_uniform_sampling():
	# S 形曲线：均匀采样后任意两相邻点距离 ≈ 段长
	var curve := Curve2D.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(200, 200), Vector2(-50, 0), Vector2(50, 0))
	curve.add_point(Vector2(400, 0))
	var sk := LaserSkeleton.new()
	sk.from_curve(curve, 32.0)
	assert_gt(sk.total_length, 400.0, "S 形曲线长度应大于直线距离")
	assert_gt(sk.points.size(), 10, "32px 段长应有多段")
	# 相邻采样点间距 ≈ 均匀
	var pts := sk.points
	for i in range(1, pts.size()):
		var d := pts[i].distance_to(pts[i - 1])
		assert_between(d, 20.0, 45.0, "相邻点间距应接近均匀（段长 32 附近）")

func test_skeleton_sample_range_single_safe():
	# count=1 不除零
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 100))
	var pts := sk.sample_range(0, 50, 1)
	assert_eq(pts.size(), 1, "count=1 只返回 1 点")
	assert_eq(pts[0], Vector2(0, 0), "返回起始点")

# ── 状态机 ──

func _make_beam() -> LaserBeam:
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 600))
	beam.grow_speed = 300.0
	beam.tail_distance = 100.0
	beam.max_lifetime = 5.0
	beam.spawn(sk, Color.RED)
	return beam

func test_grow_moves_head():
	var beam := _make_beam()
	beam._physics_process(0.1)
	assert_eq(beam.head_dist, 30.0, "0.1s × 300 = 30px")
	beam._physics_process(0.1)
	assert_eq(beam.head_dist, 60.0, "再 0.1s = 60px")
	beam._physics_process(0.1)
	assert_eq(beam.tail_dist, 0.0, "head=90 < tail_distance=100 → 尾部仍在起点")
	beam._physics_process(0.1)
	assert_eq(beam.tail_dist, 20.0, "head=120 → 尾部滞后 100 = 20")

func test_grow_reaches_sustain():
	var beam := _make_beam()
	for i in 25:  # 2.5s > 600/300
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "到顶转 SUSTAIN")
	assert_eq(beam.head_dist, 600.0, "头部到顶")

func test_sustain_then_contract_to_dead():
	var beam := _make_beam()
	for i in 25:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "到顶后 SUSTAIN")
	# 推到超时：应经过 CONTRACT 再 DEAD（尾部追上）
	var saw_contract := false
	for i in 40:
		beam._physics_process(0.1)
		if beam.phase == LaserBeam.Phase.CONTRACT:
			saw_contract = true
	assert_true(saw_contract, "超时后应经过 CONTRACT 阶段")
	assert_eq(beam.phase, LaserBeam.Phase.DEAD, "最终 DEAD（尾部追上消失）")

func test_fixed_beam_fades_on_timeout():
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 300))
	beam.grow_on_spawn = false  # 瞬间全开
	beam.max_lifetime = 0.5
	beam.spawn(sk, Color.BLUE)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "非生长型直接 SUSTAIN")
	assert_eq(beam.head_dist, 300.0, "非生长型 head = 全长（瞬间全开）")
	assert_eq(beam.tail_dist, 0.0, "尾部从 0 开始")
	# 0.6s 后应 FADE
	for i in 6:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.FADE, "超时转 FADE")
	for i in 3:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.DEAD, "淡完 → DEAD")

func test_dirty_flag_only_on_change():
	var beam := _make_beam()
	# 生长中：dirty
	beam._physics_process(0.1)
	assert_true(beam._dirty, "生长中应 dirty")
	# 到顶 SUSTAIN 后静止：不 dirty
	for i in 25:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "已 SUSTAIN")
	beam._physics_process(0.1)
	assert_false(beam._dirty, "SUSTAIN 静止时不应重建（dirty=false）")

# ── 判定 ──

## 全长可见的光束（FIXED 型）—— 判定测试用
func _make_full_beam() -> LaserBeam:
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 600))
	beam.grow_on_spawn = false
	beam.max_lifetime = 5.0
	beam.spawn(sk, Color.RED)
	return beam

func test_distance_and_hit():
	var beam := _make_full_beam()
	# 玩家在激光旁 3px → 命中；旁 10px → 不命中
	assert_true(beam.is_hitting(Vector2(3, 300)), "旁 3px 命中（hitbox 6）")
	assert_false(beam.is_hitting(Vector2(10, 300)), "旁 10px 不命中")
	# 线段外 → 不命中
	assert_false(beam.is_hitting(Vector2(0, 650)), "超出尾部不命中")

func test_graze():
	var beam := _make_full_beam()
	# 旁 20px：不命中但擦弹
	assert_false(beam.is_hitting(Vector2(20, 300)), "旁 20px 不命中")
	assert_true(beam.is_grazing(Vector2(20, 300), 10.0), "旁 20px 擦弹（graze 22 + 10）")
	assert_false(beam.is_grazing(Vector2(40, 300), 10.0), "旁 40px 不擦弹")

# ── 引擎池 ──

func test_engine_pool_reuse():
	var engine := LaserEngine.new()
	autofree(engine)
	engine.setup(self)
	for i in 10:
		var beam := engine.spawn_line(Vector2(0, 0), Vector2(0, 100), Color.RED)
		assert_not_null(beam, "第 %d 条应生成" % i)
	assert_eq(engine.get_active().size(), 10, "10 条活动")
	engine.clear()
	assert_eq(engine.get_active().size(), 0, "清空")
	# 复用：再生成（池中复用无泄漏）
	for i in 10:
		var beam := engine.spawn_line(Vector2(0, 0), Vector2(0, 100), Color.RED)
		assert_not_null(beam, "复用第 %d 条" % i)

func test_engine_spawn_curve():
	var engine := LaserEngine.new()
	autofree(engine)
	engine.setup(self)
	var curve := Curve2D.new()
	curve.add_point(Vector2(100, 100))
	curve.add_point(Vector2(300, 300))
	var beam := engine.spawn_curve(curve, Color.GREEN)
	assert_not_null(beam, "曲线激光应生成")
	assert_gt(beam.skeleton.total_length, 0.0, "曲线骨架应有长度")
