# LaserSystem — 激光管理、步进、碰撞
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
	var player_pos := Vector2.ZERO
	var player := GameState.player
	var has_player := false
	if player and is_instance_valid(player):
		player_pos = player.global_position
		has_player = true
	
	var hit := false
	for laser in _active_lasers:
		if laser.phase == CurvedLaser.DEAD:
			continue
		
		laser.step(delta)
		
		if laser.phase == CurvedLaser.ALIVE and has_player and not hit:
			if laser.is_hitting_player(player_pos):
				hit = true
			elif laser.is_hitting_player(player_pos, player.graze_radius):
				var dist: float = laser.find_closest_dist(player_pos)
				if not laser.is_grazed(dist):
					var in_hole := false
					for h in laser.holes:
						if dist >= (h.start_dist as float) and dist <= (h.end_dist as float):
							in_hole = true
							break
					if not in_hole:
						laser.mark_grazed(dist)
						_physics.on_graze()
	
	if hit and player.has_method("miss"):
		player.miss()
