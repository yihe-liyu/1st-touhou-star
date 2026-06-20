# BulletPhysics — 碰撞检测、分流、擦弹、击中特效
class_name BulletPhysics
extends RefCounted

var _pool
var _graze_sfx_played: bool = false


func _init() -> void:
	pass


func setup(p_pool) -> void:
	_pool = p_pool


func reset_frame() -> void:
	_graze_sfx_played = false


func process_collisions() -> void:
	for i in range(_pool.active_bullets.size() - 1, -1, -1):
		var bullet = _pool.active_bullets[i]
		if bullet.is_ready:
			_resolve(bullet)


func _resolve(bullet: Bullet) -> void:
	match bullet.faction:
		Bullet.FACTION_PLAYER:
			_player_vs_enemies(bullet)
		Bullet.FACTION_ENEMY:
			_enemy_vs_player(bullet)
		Bullet.FACTION_BOMB:
			_bomb_vs_enemies(bullet)


func _player_vs_enemies(bullet: Bullet) -> void:
	var bonus := 1.0
	if bullet.faction == Bullet.FACTION_PLAYER and GameState.memory_value < 50.0:
		bonus = 1.0 + remap(GameState.memory_value, 0.0, 50.0, 0.15, 0.05)
	
	for enemy in GameState.get_active_enemies():
		if not is_instance_valid(enemy):
			continue
		# 时符阶段：Boss 不可被击中，子弹穿过
		if enemy is Boss:
			var phase = (enemy as Boss).current_phase()
			if phase and phase.is_timeout_only:
				continue
		if _hit_target(bullet, enemy):
			enemy.take_damage(ceilf(bullet.damage * bonus))
			GameState.reduce_memory(GameState.MEMORY_HIT_BY_BULLET)
			_spawn_effect(bullet.hit_effect, bullet.global_position, bullet.velocity, bullet.sprite.modulate)
			_pool.return_bullet(bullet)
			return


func _enemy_vs_player(bullet: Bullet) -> void:
	var player = GameState.player
	if not is_instance_valid(player) or player.is_invincible:
		return
	if _hit_target(bullet, player):
		player.miss()
		# 激光胶囊体由 LaserSystem 自己回收，不走 return_bullet
		if bullet.hitbox_shape != BulletData.HitboxShape.CAPSULE:
			_pool.return_bullet(bullet)
	elif not bullet._grazed and _grazes_player(bullet, player):
		bullet._grazed = true
		on_graze()
		if GameState.memory_value >= 50.0:
			var chance := remap(GameState.memory_value, 50.0, 100.0, 0.05, 0.30)
			if RNG.randf() < chance:
				if bullet.hit_effect:
					_spawn_effect(bullet.hit_effect, bullet.global_position, Vector2.ZERO, bullet.sprite.modulate)
				if bullet.hitbox_shape != BulletData.HitboxShape.CAPSULE:
					_pool.return_bullet(bullet)


func _bomb_vs_enemies(bullet: Bullet) -> void:
	for enemy in GameState.get_active_enemies():
		if not is_instance_valid(enemy):
			continue
		if enemy is Boss:
			var phase = (enemy as Boss).current_phase()
			if phase and phase.is_timeout_only:
				continue
		if _hit_target(bullet, enemy):
			enemy.take_damage(bullet.damage)
			_spawn_effect(bullet.hit_effect, bullet.global_position)


func check_capsules(capsules: Array) -> void:
	var player = GameState.player
	if not is_instance_valid(player) or player.is_invincible:
		return
	for b in capsules:
		if not is_instance_valid(b) or not b.is_ready:
			continue
		if _hit_target(b, player):
			player.miss()
			return
		elif not b._grazed and _grazes_player(b, player):
			b._grazed = true
			on_graze()


# ── 命中检测 ──

func _hit_target(bullet: Bullet, target: Node2D) -> bool:
	match bullet.hitbox_shape:
		BulletData.HitboxShape.CIRCLE:
			return _check_circle(bullet, target)
		BulletData.HitboxShape.RECTANGLE:
			return _check_rect(bullet, target)
		BulletData.HitboxShape.CAPSULE:
			return _check_capsule(bullet, target)
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


func _check_capsule(bullet: Bullet, target: Node2D) -> bool:
	var a: Vector2 = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	var dir: Vector2 = Vector2.RIGHT.rotated(bullet.rotation)
	var b: Vector2 = a + dir * bullet.hitbox_length
	var target_center: Vector2 = target.global_position
	var target_radius: float = target.get("hitbox_radius") if "hitbox_radius" in target else 8.0
	var threshold: float = bullet.hitbox_radius + target_radius
	
	var ab: Vector2 = b - a
	var ap: Vector2 = target_center - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.0001:
		return ap.length_squared() < threshold * threshold
	var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return closest.distance_squared_to(target_center) < threshold * threshold


# ── 擦弹 ──

func _grazes_player(bullet: Bullet, player: Player) -> bool:
	var center: Vector2 = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	
	if bullet.hitbox_shape == BulletData.HitboxShape.CAPSULE:
		var dir: Vector2 = Vector2.RIGHT.rotated(bullet.rotation)
		var a: Vector2 = center
		var b: Vector2 = a + dir * bullet.hitbox_length
		var ab: Vector2 = b - a
		var ap: Vector2 = player.global_position - a
		var len_sq: float = ab.length_squared()
		if len_sq < 0.0001:
			return ap.length_squared() < (bullet.hitbox_radius + player.graze_radius) ** 2
		var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
		var closest: Vector2 = a + ab * t
		return closest.distance_squared_to(player.global_position) < (bullet.hitbox_radius + player.graze_radius) ** 2
	
	var total_radius: float = bullet.hitbox_radius + player.graze_radius
	return center.distance_squared_to(player.global_position) < total_radius * total_radius


func on_graze() -> void:
	GameState.graze_count += 1
	GameState.add_score(10)
	GameState.add_memory(GameState.MEMORY_GRAZE)
	
	if not _graze_sfx_played:
		_graze_sfx_played = true
		AudioManager.play_sfx(preload("res://assets/Sound/graze.wav"), -2.0)


# ── 击中特效 ──

func _spawn_effect(effect_scene: PackedScene, pos: Vector2, velocity: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	HitEffectPool.spawn(effect_scene, pos, velocity, tint)
