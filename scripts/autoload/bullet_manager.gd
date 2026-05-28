# BulletManager.gd (Autoload)
extends Node

const POOL_SIZE: int = 4000

var use_batch_render: bool = false
var use_multi_mesh: bool = true
var _multi_mesh: Node2D
var _batch_player: Node2D
var _batch_enemy: Node2D

const BulletBatchCanvasClass = preload("res://scripts/bullet/bullet_batch_canvas.gd")
const BulletMultiMeshClass = preload("res://scripts/bullet/bullet_multi_mesh.gd")

var bullet_scene = preload("res://scenes/bullet.tscn")
var active_bullets: Array = []
var bullet_pool: Array = []

func _ready():
	# MultiMesh 批渲染（高性能）
	if use_multi_mesh:
		_multi_mesh = BulletMultiMeshClass.new()
		_multi_mesh.enabled = true
		add_child(_multi_mesh)

	if use_batch_render:
		_batch_enemy = BulletBatchCanvasClass.new()
		_batch_enemy.enabled = true
		_batch_enemy.faction = Bullet.FACTION_ENEMY
		_batch_enemy.z_index = 10
		add_child(_batch_enemy)

		_batch_player = BulletBatchCanvasClass.new()
		_batch_player.enabled = true
		_batch_player.faction = Bullet.FACTION_PLAYER
		_batch_player.z_index = 5
		add_child(_batch_player)

	for i in range(POOL_SIZE):
		var b = bullet_scene.instantiate()
		b.visible = false
		b.process_mode = PROCESS_MODE_DISABLED
		if use_batch_render or use_multi_mesh:
			b.get_node("Sprite2D").visible = false
		add_child(b)
		bullet_pool.append(b)

# ── 发射 ──

func shoot_bullet(data: BulletData, position: Vector2, direction: Vector2, override: BulletOverride = null):
	var bullet: Bullet
	
	if bullet_pool.is_empty():
		bullet = bullet_scene.instantiate()
		if use_batch_render or use_multi_mesh:
			bullet.get_node("Sprite2D").visible = false
		add_child(bullet)
	else:
		bullet = bullet_pool.pop_back()
	
	bullet.bind(data, direction, override)
	bullet.global_position = position
	bullet.visible = true
	bullet.process_mode = PROCESS_MODE_INHERIT
	active_bullets.append(bullet)
	
	return bullet

func shoot_player_bullet(data: BulletData, position: Vector2, direction: Vector2, override: BulletOverride = null):
	shoot_bullet(data, position, direction, override)

func shoot_enemy_bullet(data: BulletData, position: Vector2, direction: Vector2, override: BulletOverride = null):
	shoot_bullet(data, position, direction, override)

func shoot_bomb_bullet(data: BulletData, position: Vector2, direction: Vector2, override: BulletOverride = null):
	shoot_bullet(data, position, direction, override)

# ── 回收 ──

func return_bullet(bullet: Bullet):
	if bullet.coroutine_movement and is_instance_valid(bullet.coroutine_movement):
		bullet.coroutine_movement.stop()
		bullet.coroutine_movement.queue_free()
		bullet.coroutine_movement = null
	bullet.visible = false
	bullet.process_mode = PROCESS_MODE_DISABLED
	active_bullets.erase(bullet)
	if bullet_pool.size() < POOL_SIZE:
		bullet_pool.append(bullet)
	else:
		bullet.queue_free()

# ── 每帧更新 ──

func _physics_process(delta):
	for i in range(active_bullets.size() - 1, -1, -1):
		var bullet = active_bullets[i]
		
		if bullet.is_ready:
			_resolve_collisions(bullet)
		
		if _is_offscreen(bullet.global_position):
			return_bullet(bullet)
			continue
	
	# 每 60 帧打一次对象数
	if Engine.get_frames_drawn() % 60 == 0:
		var objs = Performance.get_monitor(Performance.OBJECT_COUNT)
		var nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		var res = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
		print("OBJ:%d NODE:%d ORPH:%d RES:%d ACT:%d POOL:%d" % [objs, nodes, orphans, res, active_bullets.size(), bullet_pool.size()])

# ── 碰撞分流 ──

func _resolve_collisions(bullet: Bullet):
	match bullet.faction:
		Bullet.FACTION_PLAYER:
			_player_bullet_vs_enemies(bullet)
		Bullet.FACTION_ENEMY:
			_enemy_bullet_vs_player(bullet)
		Bullet.FACTION_BOMB:
			_bomb_bullet_vs_enemies(bullet)

# ── 自机弹 vs 敌人 ──

func _player_bullet_vs_enemies(bullet: Bullet):
	for enemy in GameState.get_active_enemies():
		if not is_instance_valid(enemy):
			continue
		if _bullet_hits_target(bullet, enemy):
			enemy.take_damage(bullet.damage)
			_spawn_hit_effect(bullet.hit_effect, bullet.global_position, bullet.velocity)
			return_bullet(bullet)
			return

# ── 敌弹 vs 玩家 ──

func _enemy_bullet_vs_player(bullet: Bullet):
	var player = GameState.player
	if not is_instance_valid(player) or player.is_invincible:
		return
	
	if _bullet_hits_target(bullet, player):
		player.miss()
		return_bullet(bullet)

# ── Bomb 弹 vs 敌人（穿透，不回收） ──

func _bomb_bullet_vs_enemies(bullet: Bullet):
	for enemy in GameState.get_active_enemies():
		if not is_instance_valid(enemy):
			continue
		if _bullet_hits_target(bullet, enemy):
			enemy.take_damage(bullet.damage)
			_spawn_hit_effect(bullet.hit_effect, bullet.global_position)
			# Bomb 子弹不回收，继续穿透

# ── 命中检测 ──

func _bullet_hits_target(bullet: Bullet, target: Node2D) -> bool:
	match bullet.hitbox_shape:
		BulletData.HitboxShape.CIRCLE:
			return _check_circle(bullet, target)
		BulletData.HitboxShape.RECTANGLE:
			return _check_rect(bullet, target)
	return false

func _check_circle(bullet: Bullet, target: Node2D) -> bool:
	var center = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	var target_center = target.global_position
	var target_radius = target.get("hitbox_radius") if "hitbox_radius" in target else 8.0
	var total_radius = bullet.hitbox_radius + target_radius
	return center.distance_squared_to(target_center) < total_radius * total_radius

func _check_rect(bullet: Bullet, target: Node2D) -> bool:
	var box_center = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	var half = bullet.hitbox_size / 2.0
	var angle = bullet.rotation + deg_to_rad(bullet.hitbox_rotation)
	
	var target_center = target.global_position
	var target_radius = target.get("hitbox_radius") if "hitbox_radius" in target else 8.0
	
	var local_target = (target_center - box_center).rotated(-angle)
	var closest = Vector2(
		clamp(local_target.x, -half.x, half.x),
		clamp(local_target.y, -half.y, half.y)
	)
	return closest.distance_squared_to(local_target) < target_radius * target_radius

# ── 命中特效 ──

func _spawn_hit_effect(effect_scene: PackedScene, position: Vector2, velocity: Vector2 = Vector2.ZERO):
	if not effect_scene:
		return
	var effect = effect_scene.instantiate()
	var scene = get_tree().current_scene
	if is_instance_valid(scene):
		scene.add_child(effect)
	effect.global_position = position

	# 把速度传给特效，让特效自己决定怎么用
	if effect.has_method("set_velocity"):
		effect.set_velocity(velocity)

# ── 出屏判断 ──

func _is_offscreen(position: Vector2) -> bool:
	var r = get_viewport().get_visible_rect()
	var margin = 90.0
	return position.x < -margin or \
		   position.x > r.size.x + margin or \
		   position.y < -margin or \
		   position.y > r.size.y + margin

# ── 切关清理 ──

func clear_all():
	while active_bullets.size() > 0:
		return_bullet(active_bullets[0])
