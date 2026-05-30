# BulletManager.gd (Autoload)
extends Node2D

const POOL_SIZE: int = 4000
const MAX_LASERS := 64

var use_multi_mesh: bool = true
var _multi_mesh: Node2D

const BulletMultiMeshClass = preload("res://scripts/bullet/bullet_multi_mesh.gd")

var bullet_scene = preload("res://scenes/bullet.tscn")
var active_bullets: Array = []
var bullet_pool: Array = []

# ── 激光 ──
var _active_lasers: Array = []
const CurvedLaserClass = preload("res://scripts/laser/curved_laser.gd")

# ── 死亡清弹 ──
var _death_clears: Array[Dictionary] = []
var _graze_sfx_played: bool = false  # 每帧只播一次擦弹音效


func _ready():
	z_index = 50

	if use_multi_mesh:
		_multi_mesh = BulletMultiMeshClass.new()
		_multi_mesh.enabled = true
		add_child(_multi_mesh)

	for i in range(POOL_SIZE):
		var b = bullet_scene.instantiate()
		b.visible = false
		b.process_mode = PROCESS_MODE_DISABLED
		if use_multi_mesh:
			b.get_node("Sprite2D").visible = false
		add_child(b)
		bullet_pool.append(b)


# ═══════════════════════════════════════
# 激光 API
# ═══════════════════════════════════════

func fire_laser(data, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0):
	for l in _active_lasers:
		if l.phase == CurvedLaserClass.DEAD:
			l.init(data, origin, guide_curve, rot_speed)
			return l
	
	if _active_lasers.size() >= MAX_LASERS:
		push_warning("BulletManager: max lasers reached (%d)" % MAX_LASERS)
		return null
	
	var laser = CurvedLaserClass.new()
	laser.name = "CurvedLaser_%d" % _active_lasers.size()
	add_child(laser)
	laser.init(data, origin, guide_curve, rot_speed)
	_active_lasers.append(laser)
	return laser


func clear_all_lasers() -> void:
	for laser in _active_lasers:
		laser.phase = CurvedLaserClass.DEAD
		laser.line.visible = false
		for sl in laser._seg_lines:
			sl.visible = false


# ═══════════════════════════════════════
# 子弹发射
# ═══════════════════════════════════════

func shoot_bullet(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	var bullet: Bullet
	
	if bullet_pool.is_empty():
		bullet = bullet_scene.instantiate()
		if use_multi_mesh:
			bullet.get_node("Sprite2D").visible = false
		add_child(bullet)
	else:
		bullet = bullet_pool.pop_back()
	
	bullet.bind(data, direction, override)
	bullet.global_position = pos
	bullet.visible = true
	bullet.process_mode = PROCESS_MODE_INHERIT
	active_bullets.append(bullet)
	
	return bullet

func shoot_player_bullet(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	shoot_bullet(data, pos, direction, override)

func shoot_enemy_bullet(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	shoot_bullet(data, pos, direction, override)

func shoot_bomb_bullet(data: BulletData, pos: Vector2, direction: Vector2, override: BulletOverride = null):
	shoot_bullet(data, pos, direction, override)


# ── 回收 ──

func return_bullet(bullet: Bullet):
	if bullet.coroutine_movement and is_instance_valid(bullet.coroutine_movement):
		bullet.coroutine_movement.stop()
		bullet.coroutine_movement.queue_free()
		bullet.coroutine_movement = null
	for child in bullet.get_children():
		if child is MoveScript:
			child.stop()
			child.queue_free()
	bullet.visible = false
	bullet.process_mode = PROCESS_MODE_DISABLED
	bullet.fog.visible = false
	bullet.fog.texture = null
	if bullet.fog.fog_finished.is_connected(bullet._on_fog_ready):
		bullet.fog.fog_finished.disconnect(bullet._on_fog_ready)
	active_bullets.erase(bullet)
	if bullet_pool.size() < POOL_SIZE:
		bullet_pool.append(bullet)
	else:
		bullet.queue_free()


# ═══════════════════════════════════════
# 每帧更新
# ═══════════════════════════════════════

func _physics_process(delta: float) -> void:
	_graze_sfx_played = false  # 每帧重置
	
	# 1. 死亡清弹（弹幕 + 激光切割）
	if not _death_clears.is_empty():
		_process_death_clears(delta)
	
	# 2. 激光步进 & 碰撞
	_step_lasers(delta)
	
	# 3. 弹幕碰撞
	for i in range(active_bullets.size() - 1, -1, -1):
		var bullet = active_bullets[i]
		if bullet.is_ready:
			_resolve_collisions(bullet)
		if _is_offscreen(bullet.global_position):
			return_bullet(bullet)


func _step_lasers(delta: float) -> void:
	var player_pos := Vector2.ZERO
	var player := GameState.player
	var has_player := false
	if player and is_instance_valid(player):
		player_pos = player.global_position
		has_player = true
	
	var hit := false
	for laser in _active_lasers:
		if laser.phase == CurvedLaserClass.DEAD:
			continue
		
		laser.step(delta)
		
		if laser.phase == CurvedLaserClass.ALIVE and has_player and not hit:
			if laser.is_hitting_player(player_pos):
				hit = true
			elif laser.is_hitting_player(player_pos, player.graze_radius):
				var dist := laser.find_closest_dist(player_pos)
				# 跳过孔洞区域
				if not laser.is_grazed(dist):
					var in_hole := false
					for h in laser.holes:
						if dist >= (h.start_dist as float) and dist <= (h.end_dist as float):
							in_hole = true
							break
					if not in_hole:
						laser.mark_grazed(dist)
						_on_graze()
	
	if hit and player.has_method("miss"):
		player.miss()


# ═══════════════════════════════════════
# 碰撞分流
# ═══════════════════════════════════════

func _resolve_collisions(bullet: Bullet):
	match bullet.faction:
		Bullet.FACTION_PLAYER:
			_player_bullet_vs_enemies(bullet)
		Bullet.FACTION_ENEMY:
			_enemy_bullet_vs_player(bullet)
		Bullet.FACTION_BOMB:
			_bomb_bullet_vs_enemies(bullet)


func _player_bullet_vs_enemies(bullet: Bullet):
	for enemy in GameState.get_active_enemies():
		if not is_instance_valid(enemy):
			continue
		if _bullet_hits_target(bullet, enemy):
			enemy.take_damage(bullet.damage)
			_spawn_hit_effect(bullet.hit_effect, bullet.global_position, bullet.velocity)
			return_bullet(bullet)
			return


func _enemy_bullet_vs_player(bullet: Bullet):
	var player = GameState.player
	if not is_instance_valid(player) or player.is_invincible:
		return
	if _bullet_hits_target(bullet, player):
		player.miss()
		return_bullet(bullet)
	elif not bullet._grazed and _bullet_grazes_player(bullet, player):
		bullet._grazed = true
		_on_graze()


func _bomb_bullet_vs_enemies(bullet: Bullet):
	for enemy in GameState.get_active_enemies():
		if not is_instance_valid(enemy):
			continue
		if _bullet_hits_target(bullet, enemy):
			enemy.take_damage(bullet.damage)
			_spawn_hit_effect(bullet.hit_effect, bullet.global_position)


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


func _spawn_hit_effect(effect_scene: PackedScene, pos: Vector2, velocity: Vector2 = Vector2.ZERO):
	if not effect_scene:
		return
	var effect = effect_scene.instantiate()
	var scene = get_tree().current_scene
	if is_instance_valid(scene):
		scene.add_child(effect)
	effect.global_position = pos
	if effect.has_method("set_velocity"):
		effect.set_velocity(velocity)


func _is_offscreen(pos: Vector2) -> bool:
	var r = get_viewport().get_visible_rect()
	var margin = 90.0
	return pos.x < -margin or \
		   pos.x > r.size.x + margin or \
		   pos.y < -margin or \
		   pos.y > r.size.y + margin


# ═══ 擦弹 ═══

func _bullet_grazes_player(bullet: Bullet, player: Player) -> bool:
	var center = bullet.global_position + bullet.hitbox_offset.rotated(bullet.rotation)
	var total_radius = bullet.hitbox_radius + player.graze_radius
	return center.distance_squared_to(player.global_position) < total_radius * total_radius


func _on_graze() -> void:
	GameState.graze_count += 1
	GameState.add_score(10)
	if not _graze_sfx_played:
		_graze_sfx_played = true
		AudioManager.play_sfx(preload("res://assets/Sound/graze.wav"), 4.0)


# ═══════════════════════════════════════
# 死亡清弹 & 激光切割
# ═══════════════════════════════════════

func start_death_clear(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0) -> void:
	_death_clears.append({
		pos = pos,
		age = 0.0,
		duration = duration,
		start_r = start_radius,
		max_r = max_radius,
	})


func _process_death_clears(delta: float) -> void:
	const LASER_CHECK_STEP := 5.0
	
	for i in range(_death_clears.size() - 1, -1, -1):
		var circle: Dictionary = _death_clears[i]
		circle.age += delta
		if circle.age >= circle.duration:
			_death_clears.remove_at(i)
			continue
		
		if circle.duration <= 0:
			continue
		var progress: float = circle.age / circle.duration
		var radius: float = lerpf(circle.start_r, circle.max_r, progress)
		var center: Vector2 = circle.pos
		var radius_sq: float = radius * radius
		
		# 清除圆内的敌弹
		for j in range(active_bullets.size() - 1, -1, -1):
			var bullet: Bullet = active_bullets[j]
			if not is_instance_valid(bullet) or bullet.faction != 1 or not bullet.is_ready:
				continue
			if bullet.global_position.distance_squared_to(center) <= radius_sq:
				return_bullet(bullet)
		
		# 切穿激光
		for laser: CurvedLaserClass in _active_lasers:
			if laser.phase != CurvedLaserClass.ALIVE:
				continue
			var visible_len := (laser.head_dist as float) - (laser.tail_dist as float)
			if visible_len <= 0:
				continue
			_cut_laser(laser, center, radius, LASER_CHECK_STEP)


func _cut_laser(laser: CurvedLaserClass, circle_center: Vector2, radius: float, check_step: float) -> void:
	var visible_len := (laser.head_dist as float) - (laser.tail_dist as float)
	var samples := maxi(int(visible_len / check_step), 4)
	
	var cutting := false
	var cut_start := 0.0
	
	for i in range(samples):
		var dist: float = (laser.tail_dist as float) + visible_len * float(i) / float(samples - 1)
		var point: Vector2 = laser._sample_curve(dist)
		var inside: bool = point.distance_squared_to(circle_center) <= radius * radius
		
		if inside and not cutting:
			cutting = true
			cut_start = dist
		elif not inside and cutting:
			cutting = false
			laser.add_hole(cut_start, dist)
	
	if cutting:
		laser.add_hole(cut_start, laser.head_dist)


# ═══════════════════════════════════════
# 切关清理
# ═══════════════════════════════════════

func clear_all():
	while active_bullets.size() > 0:
		return_bullet(active_bullets[0])
	clear_all_lasers()
	_death_clears.clear()
