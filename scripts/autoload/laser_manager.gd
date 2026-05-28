extends Node2D
## 激光管理器 autoload —— 对象池管理所有曲线激光

const MAX_LASERS := 64
const PHASE_DEAD := 2
const PHASE_ALIVE := 0

var _active: Array = []


func _ready():
	z_index = 50


func fire(data, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0):
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
		if laser.line:
			laser.line.visible = false


func _physics_process(delta: float):
	var player_pos := Vector2.ZERO
	var player := GameState.player
	var has_player := false
	if player and is_instance_valid(player):
		player_pos = player.global_position
		has_player = true
	
	var hit := false
	for laser in _active:
		if laser.phase == PHASE_DEAD:
			continue
		
		laser.step(delta)
		
		if laser.phase == PHASE_ALIVE and has_player and not hit:
			if laser.is_hitting_player(player_pos):
				hit = true
	
	if hit and player.has_method("miss"):
		player.miss()
