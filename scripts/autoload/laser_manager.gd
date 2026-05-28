extends Node2D
## 激光管理器 autoload —— 对象池管理所有曲线激光

const MAX_LASERS := 64
const PHASE_DEAD := 3
const PHASE_ACTIVE := 1

var _active: Array = []


func _ready():
	z_index = 50


func fire(data, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0):
	print("[LaserMgr] fire: origin=", origin, " curve_pts=", guide_curve.get_point_count())
	for l in _active:
		if l.phase == PHASE_DEAD:
			l.init(data, origin, guide_curve, rot_speed)
			return l
	
	if _active.size() >= MAX_LASERS:
		push_warning("LaserManager: max lasers reached (%d)" % MAX_LASERS)
		return null
	
	var LaserCls = load("res://scripts/laser/curved_laser.gd")
	var laser = LaserCls.new()
	laser.name = "CurvedLaser_%d" % _active.size()
	add_child(laser)
	laser.init(data, origin, guide_curve, rot_speed)
	_active.append(laser)
	return laser


func clear_all():
	for laser in _active:
		laser.phase = PHASE_DEAD


func _physics_process(delta: float):
	var player_pos := Vector2.ZERO
	var player := GameState.player
	var has_player := false
	if player and is_instance_valid(player):
		player_pos = player.global_position
		has_player = true
	
	var damage_this_frame: Dictionary = {}
	
	for laser in _active:
		if laser.phase == PHASE_DEAD:
			continue
		
		laser.step(delta)
		
		if laser.phase == PHASE_ACTIVE and has_player:
			if laser.is_hitting_player(player_pos):
				if not damage_this_frame.has(player):
					damage_this_frame[player] = 0.0
				damage_this_frame[player] += laser.data.damage_per_second * delta
	
	for p in damage_this_frame:
		if p.has_method("take_damage"):
			p.take_damage(int(damage_this_frame[p]))
