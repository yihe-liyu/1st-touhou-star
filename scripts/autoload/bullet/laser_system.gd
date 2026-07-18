# LaserSystem — 激光管理
class_name LaserSystem
extends RefCounted

const POOL_SIZE := 32

var _pool: Array[Laser] = []
var _active_lasers: Array[Laser] = []
var _pool_index: int = 0
var _graze_cooldown: int = 0
var _parent: Node
var _physics: BulletPhysics


func setup(p_parent, p_physics) -> void:
	_parent = p_parent
	_physics = p_physics
	_init_pool()


func _init_pool() -> void:
	_pool.resize(POOL_SIZE)
	for i in POOL_SIZE:
		var laser := Laser.new()
		laser.name = "LaserPool_%d" % i
		_parent.add_child(laser)
		_pool[i] = laser


func _get_laser() -> Laser:
	for i in POOL_SIZE:
		var idx := (_pool_index + i) % POOL_SIZE
		if _pool[idx]._dead:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	# 全活 → 踢最老的
	var reuse: Laser = _active_lasers.pop_front()
	return reuse


func fire_fixed_path(curve: Curve2D, color: Color, lifetime: float, tex: Texture2D = null) -> Laser:
	var laser := _get_laser()
	if not laser: return null
	laser.init_fixed_path(curve, color, lifetime, tex)
	_active_lasers.append(laser)
	return laser


func fire_line(a: Vector2, b: Vector2, color: Color, lifetime: float, tex: Texture2D = null) -> Laser:
	var laser := _get_laser()
	if not laser: return null
	laser.init_line(a, b, color, lifetime, tex)
	_active_lasers.append(laser)
	return laser


func fire_growing(curve: Curve2D, color: Color, speed: float, tail: float, lifetime: float, tex: Texture2D = null) -> Laser:
	var laser := _get_laser()
	if not laser: return null
	laser.init_growing(curve, color, speed, tail, lifetime, tex)
	_active_lasers.append(laser)
	return laser


func clear() -> void:
	for laser in _active_lasers:
		laser._dead = true
	_active_lasers.clear()
	# 激光回到池中（_dead=true 的会被 _get_laser 复用）


func get_active() -> Array:
	return _active_lasers


func step(_delta: float) -> void:
	var player: Player = GameState.player
	var has_player: bool = is_instance_valid(player) and not player.is_invincible
	var missed: bool = false
	for i in range(_active_lasers.size() - 1, -1, -1):
		var laser: Laser = _active_lasers[i]

		if laser._dead:
			_active_lasers.remove_at(i)
			continue

		if has_player and not laser._fading and not missed:
			var pos := player.global_position
			if laser.is_hitting_player(pos):
				missed = true
				player.miss()
			elif _graze_cooldown <= 0 and laser.is_grazing_player(pos, player.graze_radius):
				_graze_cooldown = 3
				if _physics:
					_physics.on_graze()

	if _graze_cooldown > 0:
		_graze_cooldown -= 1
