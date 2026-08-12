extends GutTest
## enemy04 移动测试：匀速下移直到离开屏幕（弹幕结束后移动不中断）

const ENEMY04 = preload("res://data/stages/stage01/enemy/enemy04.gd")


func test_moves_down_until_offscreen() -> void:
	var cs: CoroutineScript = ENEMY04.new()
	var tgt := Node2D.new()
	add_child(tgt)
	tgt.global_position = Vector2(448, 100)
	cs.target = tgt
	cs.start_fast(null, tgt)

	# 中途：持续下移、返回 true（未出屏）
	var frames := 0
	var alive := true
	while frames < 100:
		alive = cs.tick_fast(0.1)
		frames += 1
		if not alive:
			break
	assert_true(alive, "出屏前应持续移动")
	assert_gt(tgt.global_position.y, 100.0 + 60.0, "应已下移（60px/s × 10s）")

	# 继续：直到离开屏幕 → 返回 false
	var out_frames := 0
	while cs.tick_fast(0.1) and out_frames < 2000:
		out_frames += 1
		assert_lt(out_frames, 2000, "应在出屏后结束")
		if out_frames >= 1999:
			break
	assert_gt(tgt.global_position.y, GameConfig.VIEW_HEIGHT + 80.0, "结束时应在屏幕之外")
