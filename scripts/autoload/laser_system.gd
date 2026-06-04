# LaserSystem — 激光管理、步进、碰撞
class_name LaserSystem
extends RefCounted

const MAX_LASERS := 64
const CurvedLaserClass = preload("res://scripts/laser/curved_laser.gd")

var _active_lasers: Array = []
var _parent
var _physics


func _init() -> void:
	pass


func setup(p_parent, p_physics) -> void:
	_parent = p_parent
	_physics = p_physics


func fire(data: Resource, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0):
	for l in _active_lasers:
		if l.phase == CurvedLaserClass.DEAD:
			l.init(data, origin, guide_curve, rot_speed)
			return l
	
	if _active_lasers.size() >= MAX_LASERS:
		push_warning("LaserSystem: max lasers reached (%d)" % MAX_LASERS)
		return null
	
	var laser = CurvedLaserClass.new()
	laser.name = "CurvedLaser_%d" % _active_lasers.size()
	_parent.add_child(laser)
	laser.init(data, origin, guide_curve, rot_speed)
	_active_lasers.append(laser)
	return laser


func clear() -> void:
	for laser in _active_lasers:
		laser.phase = CurvedLaserClass.DEAD
		laser.line.visible = false
		for sl in laser._seg_lines:
			sl.visible = false


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
		if laser.phase == CurvedLaserClass.DEAD:
			continue
		
		laser.step(delta)
		
		if laser.phase == CurvedLaserClass.ALIVE and has_player and not hit:
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
