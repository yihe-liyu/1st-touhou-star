extends Node
class_name PatternRunner

var _pattern: ShootPatternBase
var _shooter: Node2D
var _override: BulletOverride
var _elapsed: float = 0.0
var _shoot_timer: float = 0.0
var _active: bool = false

func start(pattern: ShootPatternBase, shooter: Node2D):
	if not pattern or not pattern.bullet_data:
		push_error("PatternRunner: pattern or bullet_data is null")
		return
	_pattern = pattern
	_shooter = shooter
	_override = pattern.make_override()
	_elapsed = 0.0
	_shoot_timer = 0.0
	_active = true

func stop():
	_active = false

func _process(delta):
	if not _active:
		return

	_elapsed += delta

	if _pattern.duration > 0 and _elapsed >= _pattern.duration:
		if _pattern.next_pattern:
			start(_pattern.next_pattern, _shooter)
		else:
			stop()
		return

	_shoot_timer += delta
	while _shoot_timer >= _pattern.interval:
		_shoot_timer -= _pattern.interval
		_pattern.emit(_shooter, _override)
	while _shoot_timer >= _pattern.interval: while _shoot_timer >= _pattern.interval:			_shoot_timer - -= _patt_rn.inaervtltern.interval		_pattern.empt(ern.etsh, orovvreid))
