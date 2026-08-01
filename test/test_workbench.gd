extends GutTest
## 工作台步 1：LifecycleNode 基座测试
## 时间锚点 / 嵌套生成 / 确定性 / 死亡

## 测试母体：t=1.0 和 t=2.0 各生成一颗子弹，t>=5 死亡
class TestSpawner extends LifecycleNode:
	var spawn_times: Array = [1.0, 2.0]
	func _spawn_plan() -> Array:
		var plan: Array = []
		for t in spawn_times:
			var b := LifecycleBullet.new()
			b.origin = Vector2(400, 200)
			b.velocity = Vector2(0, -100)
			plan.append({"t": t, "node": b})
		return plan
	func _should_die() -> bool:
		return local_time >= 5.0

## 测试子弹：水平匀速
class TestBullet extends LifecycleNode:
	var origin: Vector2
	var velocity: Vector2
	func position() -> Vector2:
		return origin + velocity * local_time

func test_time_anchor_and_world_time():
	var stage := LifecycleNode.new()
	stage.simulate_to(2.0)  # 父推进到 2.0
	var child := TestBullet.new()
	child.spawn_under(stage)
	assert_eq(child.anchor, 2.0, "子锚点 = 父当前局部时间")
	child.simulate_to(1.0)
	assert_eq(child.world_time(), 3.0, "子世界时间 = 父锚点2.0 + 局部1.0")

func test_spawn_plan_nested():
	var spawner := TestSpawner.new()
	spawner.simulate_to(0.0)
	spawner.simulate_to(1.5)
	assert_eq(spawner.children.size(), 1, "t=1.0 的子已生成")
	var c := spawner.children[0]
	assert_eq(c.anchor, 1.0, "子锚点 = 生成时刻")
	assert_eq(c.local_time, 0.5, "子局部时间 = 父时间 - 锚点（1.5-1.0）")
	assert_eq(c.world_time(), 1.5, "子世界时间 = 当前父时间")

func test_spawn_plan_multiple():
	var spawner := TestSpawner.new()
	spawner.simulate_to(2.5)
	assert_eq(spawner.children.size(), 2, "两个子都生成")
	assert_eq(spawner.children[1].world_time(), 2.5, "第二个子世界时间 = 2.5")

func test_death():
	var spawner := TestSpawner.new()
	spawner.simulate_to(4.0)
	assert_true(spawner.alive, "t=4 未死")
	spawner.simulate_to(5.5)
	assert_false(spawner.alive, "t>=5 死亡")
	assert_almost_eq(spawner.died_at, 5.0, 0.05, "死亡时刻 ≈ 5.0（tick 粒度 1/60）")

func test_deterministic_replay():
	# 两次 simulate_to 结果一致（确定性）
	var a := TestSpawner.new()
	var b := TestSpawner.new()
	a.simulate_to(3.0)
	b.simulate_to(3.0)
	assert_eq(a.children.size(), b.children.size(), "子数量一致")
	for i in a.children.size():
		assert_eq(a.children[i].world_time(), b.children[i].world_time(), "子世界时间一致")
	# 子弹位置一致
	assert_eq(a.children[0].position(), b.children[0].position(), "子位置一致")

func test_reset_clears_children():
	var spawner := TestSpawner.new()
	spawner.simulate_to(3.0)
	assert_eq(spawner.children.size(), 2, "生成过子")
	spawner.reset_state()
	assert_eq(spawner.children.size(), 0, "重置清空子")
	assert_eq(spawner.local_time, 0.0, "重置时间归零")

func test_bullet_position_math():
	var b := LifecycleBullet.new()
	b.origin = Vector2(400, 300)
	b.velocity = Vector2(0, -100)
	b.simulate_to(2.0)
	assert_eq(b.position(), Vector2(400, 100), "直线子弹位置 = origin + v*t")
	assert_eq(b.world_time(), 2.0, "无父时世界时间 = 局部时间")

func test_bullet_offscreen_death():
	var b := LifecycleBullet.new()
	b.origin = Vector2(400, 300)
	b.velocity = Vector2(0, -100)
	b.simulate_to(3.5)
	assert_false(b.alive, "出框（y<32）后死亡")
