# LaserSystem — 激光管理、步进、碰撞
class_name LaserSystem
extends RefCounted

const POOL_SIZE := 32

var _pool: Array[CurvedLaser] = []
var _active_lasers: Array[CurvedLaser] = []
var _pool_index: int = 0
var _parent
var _physics
var _bullet_pool: BulletPool

# 胶囊体子弹映射：{laser: [Bullet, ...]}
var _capsule_map: Dictionary = {}


func setup(p_parent, p_physics, p_bullet_pool: BulletPool) -> void:
	_parent = p_parent
	_physics = p_physics
	_bullet_pool = p_bullet_pool
	_init_pool()


func _init_pool() -> void:
	_pool.resize(POOL_SIZE)
	for i in POOL_SIZE:
		var laser := CurvedLaser.new()
		laser.phase = CurvedLaser.DEAD
		_parent.add_child(laser)
		_pool[i] = laser


func _get_laser() -> CurvedLaser:
	for i in POOL_SIZE:
		var idx := (_pool_index + i) % POOL_SIZE
		if _pool[idx].phase == CurvedLaser.DEAD:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	# 全部在用——覆盖最早发射的那条
	var reuse: CurvedLaser = _active_lasers.front()
	_active_lasers.erase(reuse)
	return reuse


func fire(data: CurvedLaserData, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0) -> CurvedLaser:
	var laser := _get_laser()
	if not laser:
		return null
	laser.init(data, origin, guide_curve, rot_speed)
	_active_lasers.append(laser)
	_capsule_map[laser] = []
	return laser


func clear() -> void:
	for laser in _active_lasers:
		laser.phase = CurvedLaser.DEAD
		laser.line.visible = false
		for sl in laser._seg_lines:
			sl.visible = false
		# 回收激光的胶囊体子弹
		var bullets: Array = _capsule_map.get(laser, [])
		for b in bullets:
			_bullet_pool.return_bullet(b)
		_capsule_map.erase(laser)
	_active_lasers.clear()


func get_active() -> Array:
	return _active_lasers


func step(delta: float) -> void:
	var player := GameState.player
	
	for laser in _active_lasers:
		if laser.phase == CurvedLaser.DEAD:
			continue
		
		laser.step(delta)
		
		if laser.phase != CurvedLaser.ALIVE:
			# 激光淡出/死亡，回收它的胶囊体
			_recycle_capsules(laser)
			continue
		
		_update_capsules(laser)


func _capsule_step(step_px: float = 20.0) -> float:
	return step_px


func _update_capsules(laser: CurvedLaser) -> void:
	var segs: Array = laser.visible_segments()
	var bullets: Array = _capsule_map.get(laser)
	if bullets == null:
		return
	
	# 计算需要的总采样数
	var total_needed := 0
	var samples_per_seg: Array[int] = []
	for seg in segs:
		var seg_len: float = (seg.end_dist as float) - (seg.start_dist as float)
		var n := maxi(int(seg_len / _capsule_step()), 3)
		samples_per_seg.append(n)
		total_needed += n
	
	# 回收多余的
	while bullets.size() > total_needed:
		_bullet_pool.return_bullet(bullets.pop_back())
	
	# 补充不足的
	while bullets.size() < total_needed:
		var b := _bullet_pool.request_bullet()
		if b:
			bullets.append(b)
	
	# 更新位置
	var idx := 0
	for si in segs.size():
		var seg = segs[si]
		var seg_len: float = (seg.end_dist as float) - (seg.start_dist as float)
		var n := samples_per_seg[si]
		for i in n:
			var t: float = float(i) / float(n - 1) if n > 1 else 0.0
			var dist: float = (seg.start_dist as float) + seg_len * t
			var pos: Vector2 = laser.sample_curve(dist)
			var dir: Vector2 = laser.sample_dir(dist)
			var b: Bullet = bullets[idx]
			b.global_position = pos
			b.rotation = dir.angle()
			b.hitbox_shape = BulletData.HitboxShape.CAPSULE
			b.hitbox_radius = laser.data.hitbox_width
			b.hitbox_length = seg_len / float(n - 1) if n > 1 else seg_len
			b.hitbox_offset = Vector2.ZERO
			b.faction = Bullet.FACTION_ENEMY
			idx += 1


func _recycle_capsules(laser: CurvedLaser) -> void:
	var bullets: Array = _capsule_map.get(laser, [])
	for b in bullets:
		_bullet_pool.return_bullet(b)
	_capsule_map.erase(laser)
