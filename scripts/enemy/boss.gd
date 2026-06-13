# Boss.gd
class_name Boss
extends Area2D

var boss_data: BossData
var hp: int = 0
var hitbox_radius: float = 24.0

var _api: StageAPI
var _phase_index: int = -1
var _current_phase: PhaseData
var _bonus: int = 0
var _elapsed: float = 0.0
var _invincible: bool = false
var _move: CoroutineRunner
var _shoot: CoroutineRunner
var _stage_id: int = 1
var _spell_count: int = 0
var _non_count: int = 0

func current_phase() -> PhaseData: return _current_phase
func current_bonus() -> int: return _bonus


func setup(bd: BossData, api: StageAPI) -> void:
	boss_data = bd
	_api = api
	
	var shape := CircleShape2D.new()
	shape.radius = hitbox_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	collision_layer = 4
	collision_mask = 2
	area_entered.connect(_on_area_entered)

func start_boss() -> void:
	set_process(true)
	GameState.active_enemies.append(self)
	tree_exited.connect(func(): GameState.active_enemies.erase(self))
	GameEvents.boss_spawned.emit(self)
	_next_phase()

func _next_phase() -> void:
	_phase_index += 1
	if _phase_index >= boss_data.phases.size():
		_die_boss()
		return
	
	_current_phase = boss_data.phases[_phase_index]
	_elapsed = 0.0
	_bonus = _current_phase.bonus
	
	# 计数
	if _current_phase.name != "" or _current_phase.spell_id != 0:
		_spell_count += 1
	else:
		_non_count += 1
	
	if _current_phase.is_timeout_only:
		_invincible = true
		hp = 999999
	else:
		_invincible = false
		hp = _current_phase.hp
	
	if _current_phase.name != "":
		GameEvents.phase_start.emit(_current_phase)
	
	if _current_phase.move_script:
		_move = _current_phase.move_script.new()
		add_child(_move)
		_move.start_moving(_api, self)
	if _current_phase.shoot_script:
		_shoot = _current_phase.shoot_script.new()
		add_child(_shoot)
		_shoot.start_creating(_api)

func _process(delta: float) -> void:
	if not _current_phase: return
	
	_elapsed += delta
	
	if _bonus > 0:
		var tick := maxi(1, int(float(_current_phase.bonus) / _current_phase.time_limit * delta))
		_bonus = maxi(0, _bonus - tick)
	
	GameEvents.phase_bonus_tick.emit(_bonus)
	
	if _elapsed >= _current_phase.time_limit:
		_on_phase_clear(_current_phase.is_timeout_only)

func _on_area_entered(_area: Area2D) -> void:
	# 子弹碰撞由 BulletPhysics 处理
	pass

func take_damage(damage: int) -> void:
	if _invincible: return
	hp -= damage
	if hp <= 0 and not _current_phase.is_timeout_only:
		_on_phase_clear(true)

func _on_phase_clear(captured: bool) -> void:
	if _move: _move.stop(); _move.queue_free(); _move = null
	if _shoot: _shoot.stop(); _shoot.queue_free(); _shoot = null
	
	if _current_phase.spell_id != 0:
		var ch: int = GameState.selected_character
		var st: int = _stage_id
		var is_spell := _current_phase.name != "" or _current_phase.spell_id != 0
		var pt: int = SpellRecord.PhaseType.SPELL if is_spell else SpellRecord.PhaseType.NONSPELL
		var pn: int = _spell_count if is_spell else _non_count
		var diff: int = GameState.selected_difficulty
		GameState.record_spell(ch, st, pt, pn, diff, captured, _bonus, _elapsed, _phase_index + 1, _current_phase.spell_id)
	
	GameEvents.phase_end.emit(captured, _bonus)
	if captured and _bonus > 0:
		GameState.add_score(_bonus)
	_next_phase()

func _die_boss() -> void:
	set_process(false)
	GameState.active_enemies.erase(self)
	GameEvents.boss_defeated.emit(self)
	queue_free()
