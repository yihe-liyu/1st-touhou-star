extends Node
class_name ShootExecutor

signal finished()

var target: Node2D
var current_def: ShootPatternDef
var _active: bool = false
var _elapsed: float = 0.0
var _shoot_timer: float = 0.0
var _override: BulletOverride

func start(def: ShootPatternDef, shooter: Node2D):
	if not def.bullet_data:
		push_error("ShootExecutor: bullet_data is null in ShootPatternDef")
		_active = false
		return
	current_def = def
	target = shooter
	_elapsed = 0.0
	_shoot_timer = 0.0
	_active = true
	_override = BulletOverride.new()
	_on_start()

func stop():
	if not _active:
		return
	_active = false
	_on_stop()
	finished.emit()

func reset():
	_elapsed = 0.0
	_shoot_timer = 0.0

func _process(delta):
	if not _active:
		return

	_elapsed += delta

	if current_def.duration > 0 and _elapsed >= current_def.duration:
		_handle_duration_end()
		return

	_shoot_timer += delta
	while _shoot_timer >= current_def.interval:
		_shoot_timer -= current_def.interval
		_execute()

	_update(delta)

func _handle_duration_end():
	if current_def.next_def:
		start(current_def.next_def, target)
	else:
		stop()

func _on_start():
	pass

func _on_stop():
	pass

func _execute():
	pass

func _update(_delta: float):
	pass

func shoot_enemy_bullet(dir: Vector2):
	BulletManager.shoot_enemy_bullet(current_def.bullet_data, target.global_position, dir, _override)

func shoot_player_bullet(dir: Vector2):
	BulletManager.shoot_player_bullet(current_def.bullet_data, target.global_position, dir, _override)
