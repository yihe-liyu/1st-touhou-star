# DeathClear — 死亡清弹圈 + 激光切割
class_name DeathClear
extends RefCounted

const LASER_CHECK_STEP := 5.0

var _death_clears: Array[Dictionary] = []
var _pool
var _laser_system


func _init() -> void:
	pass


func setup(p_pool, p_laser_sys) -> void:
	_pool = p_pool
	_laser_system = p_laser_sys


func start(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0) -> void:
	_death_clears.append({
		pos = pos,
		age = 0.0,
		duration = duration,
		start_r = start_radius,
		max_r = max_radius,
	})


func clear_all() -> void:
	_death_clears.clear()


func process(delta: float) -> void:
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
		for j in range(_pool.active_bullets.size() - 1, -1, -1):
			var bullet: Bullet = _pool.active_bullets[j]
			if not is_instance_valid(bullet) or bullet.faction != 1 or not bullet.is_ready:
				continue
			if bullet.global_position.distance_squared_to(center) <= radius_sq:
				if bullet.hit_effect:
					HitEffectPool.spawn(bullet.hit_effect, bullet.global_position, Vector2.ZERO, bullet.sprite.modulate)
				_pool.return_bullet(bullet)
		
		# 切穿激光
		for laser in _laser_system.get_active():
			if laser.phase != CurvedLaser.ALIVE:
				continue
			var visible_len := (laser.head_dist as float) - (laser.tail_dist as float)
			if visible_len <= 0:
				continue
			_cut(laser, center, radius, LASER_CHECK_STEP)


func _cut(laser, circle_center: Vector2, radius: float, check_step: float) -> void:
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
