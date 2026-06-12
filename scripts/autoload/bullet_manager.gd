# BulletManager.gd (Autoload) — 子弹/激光系统的门面
extends Node2D

# ═══ 子模块 ───
const PoolClass = preload("res://scripts/autoload/bullet/bullet_pool.gd")
const PhysicsClass = preload("res://scripts/autoload/bullet/bullet_physics.gd")
const LaserClass = preload("res://scripts/autoload/bullet/laser_system.gd")
const DeathClearClass = preload("res://scripts/autoload/bullet/death_clear.gd")

var _pool
var _physics
var _lasers
var _death_clear

## 暴露给 bullet_multi_mesh 等需要直接遍历子弹的地方
var active_bullets: Array:
	get: return _pool.active_bullets if _pool else []

var use_multi_mesh: bool = true
var _multi_mesh: Node2D
var _processing_paused: bool = false
const BulletMultiMeshClass = preload("res://scripts/bullet/bullet_multi_mesh.gd")


func _ready():
	z_index = 50
	
	_pool = PoolClass.new()
	_pool.setup(self)
	_physics = PhysicsClass.new()
	_physics.setup(_pool)
	_lasers = LaserClass.new()
	_lasers.setup(self, _physics)
	_death_clear = DeathClearClass.new()
	_death_clear.setup(_pool, _lasers)
	
	_pool.init_pool()
	
	if use_multi_mesh:
		_multi_mesh = BulletMultiMeshClass.new()
		_multi_mesh.enabled = true
		add_child(_multi_mesh)


# ═══ 每帧 ═══

func _physics_process(delta: float) -> void:
	if _processing_paused:
		return
	_physics.reset_frame()
	
	# 死亡清弹
	_death_clear.process(delta)
	
	# 激光步进 & 碰撞
	_lasers.step(delta)
	
	# 子弹碰撞
	_physics.process_collisions()
	
	# 出屏回收
	for i in range(_pool.active_bullets.size() - 1, -1, -1):
		if _pool.is_offscreen(_pool.active_bullets[i].global_position):
			_pool.return_bullet(_pool.active_bullets[i])


# ═══ 子弹 API（委托给 pool）═══

func shoot_bullet(data, pos: Vector2, direction: Vector2, override = null):
	return _pool.shoot(data, pos, direction, override)

func shoot_player_bullet(data, pos: Vector2, direction: Vector2, override = null):
	return _pool.shoot_player(data, pos, direction, override)

func shoot_enemy_bullet(data, pos: Vector2, direction: Vector2, override = null):
	return _pool.shoot_enemy(data, pos, direction, override)

func shoot_bomb_bullet(data, pos: Vector2, direction: Vector2, override = null):
	return _pool.shoot_bomb(data, pos, direction, override)

func return_bullet(bullet):
	_pool.return_bullet(bullet)


# ═══ 激光 API（委托给 lasers）═══

func fire_laser(data, origin: Vector2, guide_curve: Curve2D, rot_speed: float = 0.0):
	return _lasers.fire(data, origin, guide_curve, rot_speed)

func clear_all_lasers() -> void:
	_lasers.clear()


# ═══ 死亡清弹（委托给 death_clear）═══

func start_death_clear(pos: Vector2, max_radius: float = 1280.0, duration: float = 1.0, start_radius: float = 30.0) -> void:
	_death_clear.start(pos, max_radius, duration, start_radius)


# ═══ 全局清理 ═══

func clear_all():
	_pool.clear()
	_lasers.clear()
	_death_clear.clear_all()

func clear_bullets():
	_pool.clear()

func pause_processing() -> void:
	_processing_paused = true

func resume_processing() -> void:
	_processing_paused = false
