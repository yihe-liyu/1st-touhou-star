extends GutTest
## 碰撞性能基准：P-10 空间哈希的前置测量
## 记录当前 O(n×m) 全量碰撞的开销，优化后对比用

var _pool: BulletPool
var _physics: BulletPhysics
var _holder: Node

func before_each():
	# 池子弹挂独立 holder，随测试结束 autofree 释放（5000 上限的池不能挂测试脚本）
	_holder = Node.new()
	add_child_autofree(_holder)
	_pool = BulletPool.new()
	_pool.setup(_holder)
	_physics = BulletPhysics.new()
	_physics.setup(_pool)
	GameState.memory_value = 0.0  # 避免残留触发擦弹清除特效

func after_each():
	_pool.clear()
	GameState.player = null
	GameState.active_enemies.clear()

## 构造一颗敌弹数据（无雾，纯碰撞）
func _enemy_bullet_data() -> BulletData:
	var d := BulletData.new()
	d.faction = BulletData.Faction.ENEMY
	d.hitbox_shape = BulletData.HitboxShape.CIRCLE
	d.hitbox_radius = 4.0
	d.spawn_fog = false
	return d

## 上半屏散布敌弹（玩家在下半屏 → 纯检查不命中，基准稳定）
func _scatter_enemy_bullets(count: int) -> void:
	var d := _enemy_bullet_data()
	for i in count:
		var pos := Vector2(float(i % 28) * 32.0 + 16.0, float(i / 28) * 24.0 + 12.0)
		_pool.shoot(d, pos, Vector2.UP)

func _bench_frames(frames: int) -> float:
	var t0 := Time.get_ticks_usec()
	for f in frames:
		_physics.process_collisions()
	return float(Time.get_ticks_usec() - t0) / float(frames)

## 敌弹 vs 自机（STG 核心瓶颈：每帧每颗敌弹检查玩家）
func test_enemy_bullets_vs_player_bench():
	var player = preload("res://scenes/player.tscn").instantiate()
	autofree(player)
	player.player_data = load("res://data/player_data/marisa_data.tres")  # add_child 前设置（_ready 读取）
	add_child(player)
	player._reinit_shoot()
	player.global_position = Vector2(448, 700)
	player.is_invincible = false
	GameState.player = player
	for count in [1000, 2000, 4000]:
		_scatter_enemy_bullets(count)
		var us := _bench_frames(60)
		print("碰撞基准 [敌弹%d vs 玩家]: %.1f us/帧 (%.2f ms)" % [count, us, us / 1000.0])
		assert_gt(us, 0.0, "敌弹%d 碰撞基准应完成有效计时" % count)
		assert_lt(us, 50000.0, "敌弹%d 碰撞基准异常：%.1f us/帧（>50ms）" % [count, us])
		_pool.clear()

## 玩家弹 vs 敌人（每颗玩家弹遍历所有敌人）
func test_player_bullets_vs_enemies_bench():
	# 建 20 个敌人
	for i in 20:
		var enemy = load("res://scenes/enemy.tscn").instantiate()
		autofree(enemy)
		add_child(enemy)
		enemy.global_position = Vector2(32.0 + float(i % 5) * 200.0, 100.0 + float(i / 5) * 80.0)
		enemy.enemy_data = EnemyData.new()
		enemy._apply_enemy_data(enemy.enemy_data)
		GameState.active_enemies.append(enemy)
	# 玩家弹
	var d := BulletData.new()
	d.faction = BulletData.Faction.PLAYER
	d.hitbox_shape = BulletData.HitboxShape.CIRCLE
	d.hitbox_radius = 4.0
	d.spawn_fog = false
	for count in [200, 500, 1000]:
		for i in count:
			_pool.shoot(d, Vector2(float(i % 28) * 32.0 + 16.0, 500.0), Vector2.UP)
		var us := _bench_frames(60)
		print("碰撞基准 [玩家弹%d vs 敌20]: %.1f us/帧 (%.2f ms)" % [count, us, us / 1000.0])
		assert_gt(us, 0.0, "玩家弹%d 碰撞基准应完成有效计时" % count)
		assert_lt(us, 50000.0, "玩家弹%d 碰撞基准异常：%.1f us/帧（>50ms）" % [count, us])
		_pool.clear()
