extends GutTest
## 非符1（面）发弹脚本冒烟测试 —— 只验证机制，不锁参数值
## 参数（_burst_count/_shot_interval/_bounce_step/accel…）在编辑器频繁调优，
## 锁值断言只会跟着改而添乱；参数语义由反弹行为测试（test_bounce_bullet.gd）覆盖

const Shoot = preload("res://data/stages/stage01/phase/non01/non01_shoot.gd")
const ShootBehavior = preload("res://data/stages/stage01/bullet/bounce_bullet.gd")

var _boss: Node2D
var _orig_difficulty: int


func before_each():
	BulletManager.clear_all()
	_orig_difficulty = GameState.selected_difficulty
	_boss = Node2D.new()
	_boss.global_position = Vector2(448, 240)
	add_child_autofree(_boss)


func after_each():
	GameState.selected_difficulty = _orig_difficulty
	BulletManager.clear_all()
	# 行为脚本是无节点模式（不进树），clear_all 只 queue_free —— 等一帧让删除队列真正执行，
	# 否则 GUT 孤儿检测会把它们算成孤儿
	await get_tree().process_frame


func _active_count() -> int:
	return BulletManager.active_bullets.size()


## 冒烟：开一波确实发弹，且每颗都挂反弹行为、注入的反弹角/加速度是数值
func test_fires_ring_with_bounce_behavior():
	GameState.selected_difficulty = 1
	var cs: CoroutineScript = Shoot.new()
	autofree(cs)
	cs._burst_t = 0.0  # 屏蔽脚本初始 _burst_t（编辑器可调），测试从 0 计时
	cs.start_fast(BulletManager.get_bullet_ctx(), _boss)
	cs._fire_burst(BulletManager.get_bullet_ctx())  # 直接开一波，不依赖计时参数

	assert_gt(_active_count(), 0, "开一波应发弹")
	for b in BulletManager.active_bullets:
		var cb = b.coroutine_script
		assert_not_null(cb, "每颗弹都应挂行为脚本")
		if cb == null:
			continue
		assert_eq(cb.get_script(), ShootBehavior, "应挂反弹脚本")
		assert_true(typeof(cb.bounce_angle) == TYPE_FLOAT, "反弹角应注入（float）")
		assert_true(typeof(cb.accel) == TYPE_FLOAT, "加速度应注入（float）")


## 无目标：不死不炸（协程应继续等待而不是每帧空转）
func test_no_target_waits():
	var cs: CoroutineScript = Shoot.new()
	autofree(cs)
	cs.start_fast(BulletManager.get_bullet_ctx())  # 不设 target
	var ret := cs.tick_fast(0.016)
	assert_true(ret, "无 target 时应等待而非结束")
	assert_eq(_active_count(), 0, "无 target 不应发弹")
