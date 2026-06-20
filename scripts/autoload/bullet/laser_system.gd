# LaserSystem — 激光管理：每帧在起点发一颗胶囊体 + 渲染
class_name LaserSystem
extends RefCounted

const POOL_SIZE := 32

var _pool: Array[CurvedLaser] = []
var _active_lasers: Array[CurvedLaser] = []
var _pool_index: int = 0
var _parent
var _physics


func setup(p_parent, p_physics) -> void:
	_parent = p_parent
	_physics = p_physics
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
	var reuse: CurvedLaser = _active_lasers.front()
	_active_lasers.erase(reuse)
	return reuse


func fire(data: CurvedLaserData, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0) -> CurvedLaser:
	var laser := _get_laser()
	if not laser:
		return null
	laser.init(data, origin, guide_curve, rot_speed)
	_active_lasers.append(laser)
	return laser


func clear() -> void:
	for laser in _active_lasers:
		laser.phase = CurvedLaser.DEAD
		laser.line.visible = false
		for sl in laser._seg_lines:
			sl.visible = false
	_active_lasers.clear()


func get_active() -> Array:
	return _active_lasers


func step(delta: float) -> void:
	var player := GameState.player
	var has_player := is_instance_valid(player) and not player.is_invincible
	
	for laser in _active_lasers:
		if laser.phase == CurvedLaser.DEAD:
			continue
		laser.step(delta)
		
		if has_player and laser.phase == CurvedLaser.ALIVE:
			var pos := player.global_position
			if laser.is_hitting_player(pos):
				player.miss()
			elif laser.is_hitting_player(pos, player.graze_radius) and not laser.is_grazed(laser.find_closest_dist(pos)):
				laser.mark_grazed(laser.find_closest_dist(pos))
				# 通知 BulletPhysics 处理擦弹
				if _physics and _physics.has_method("on_graze"):
					_physics.on_graze()
