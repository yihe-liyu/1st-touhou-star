# Boss.gd
class_name Boss
extends Area2D

const HPRingClass = preload("res://scripts/scenes/boss_hp_ring.gd")

var boss_data: BossData
var hp: int = 0
var hitbox_radius: float

var _ctx: StageContext
var _phase_index: int = -1
var _current_phase: PhaseData
var _bonus: int = 0
var _elapsed: float = 0.0
var _invincible: bool = false
var _move: CoroutineRunner
var _shoot: CoroutineRunner
var _stage_id: int
var _in_gap: bool = false
var _spell_count: int = 0
var _non_count: int = 0
var _pid: PhaseIdentity
var _exit_controlled: bool = false
var _cleared: bool = false  # true=不自动 queue_free，由外部飞走脚本释放

func current_phase() -> PhaseData: return _current_phase
func current_bonus() -> int: return _bonus
func is_in_gap() -> bool: return _in_gap
func get_elapsed() -> float: return _elapsed
func get_phase_id() -> PhaseIdentity: return _pid

## 标记退场由外部控制（飞走脚本负责 queue_free）
func set_exit_controlled() -> void:
	_exit_controlled = true


func setup(data: BossData, p_ctx: StageContext = null) -> void:
	boss_data = data
	_ctx = p_ctx
	z_index = LayerConfig.BOSS
	
	if GameState.is_practice_mode:
		_stage_id = GameState.practice_stage_id
	else:
		_stage_id = GameState.current_stage_id
	
	# 环形血条
	var ring := HPRingClass.new()
	ring.setup(self)
	add_child(ring)
	
	hitbox_radius = data.hitbox_radius
	var shape := CircleShape2D.new()
	shape.radius = hitbox_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	collision_layer = 0  # 出场期间无碰撞，begin_battle 后开启
	collision_mask = 0
	area_entered.connect(_on_area_entered)

	# 血条初始隐藏
	ring.visible = false

func start_boss(defer: bool = false) -> void:
	set_process(true)
	GameState.active_enemies.append(self)
	tree_exited.connect(func(): GameState.active_enemies.erase(self))
	GameEvents.boss_spawned.emit(self)
	if not defer:
		_next_phase()


func begin_battle() -> void:
	_next_phase()

func _next_phase() -> void:
	_in_gap = false
	_cleared = false
	_phase_index += 1
	if _phase_index >= boss_data.phases.size():
		_die_boss()
		return
	
	# 正式开战：开启碰撞 + 显示血条
	collision_layer = 4
	collision_mask = 2
	for child in get_children():
		if child.get_script() == HPRingClass:
			child.visible = true
			break
	
	_current_phase = boss_data.phases[_phase_index]
	_elapsed = 0.0
	_bonus = _current_phase.bonus
	_invincible = true
	hp = 0
	
	# 计数
	if _current_phase.uid != 0:
		_spell_count += 1
	else:
		_non_count += 1
	
	_pid = PhaseIdentity.from_phase(_current_phase, _stage_id, _phase_index, _spell_count, _non_count)
	if not GameState.is_practice_mode:
		GameState.unlock_spell(_pid)
	
	if _current_phase.name != "":
		GameEvents.phase_start.emit(_current_phase)
	
	# HP 从 0 涨到满 → 然后开始
	var twn := create_tween()
	twn.tween_property(self, "hp", _current_phase.hp, 1.0)
	twn.tween_callback(_begin_phase)

func _begin_phase() -> void:
	if _current_phase.is_timeout_only:
		_invincible = true
		hp = 999999
	else:
		_invincible = false
	
	if _current_phase.move_script:
		_move = _current_phase.move_script.new()
		add_child(_move)
		_move.start(_ctx, self)
	if _current_phase.shoot_script:
		_shoot = _current_phase.shoot_script.new()
		add_child(_shoot)
		_shoot.start(_ctx, self)

func _process(delta: float) -> void:
	if not _current_phase: return
	
	_elapsed += delta
	
	if _bonus > 0:
		var tick := maxi(1, int(float(_current_phase.bonus) / _current_phase.time_limit * delta))
		_bonus = maxi(0, _bonus - tick)
	
	GameEvents.phase_bonus_tick.emit(_bonus)
	
	if _elapsed >= _current_phase.time_limit:
		_on_phase_clear(_current_phase.is_timeout_only)
		_current_phase = null  # 防止重复触发

func _on_area_entered(_area: Area2D) -> void:
	# 子弹碰撞由 BulletPhysics 处理
	pass

func take_damage(damage: int) -> void:
	if _invincible: return
	if not _current_phase: return  # 还没 begin_battle，不受伤害
	hp -= damage
	if hp <= 0 and not _current_phase.is_timeout_only:
		_on_phase_clear(true)

func _on_phase_clear(captured: bool) -> void:
	if _cleared:
		return
	_cleared = true
	_invincible = true  # 防重入
	if _move: _move.stop(); _move.queue_free(); _move = null
	if _shoot: _shoot.stop(); _shoot.queue_free(); _shoot = null
	
	# 更新收取统计
	if GameState.is_practice_mode:
		GameState.record_practice(_pid, captured)
	else:
		GameState.record_spell(_pid, captured, _bonus, _elapsed)
	
	GameEvents.phase_end.emit(captured, _bonus)
	if captured and _bonus > 0:
		GameState.add_score(_bonus)
	
	# 掉落 Item
	_drop_items()
	
	# 消弹圈
	BulletManager.start_death_clear(global_position, 960, 0.75, 30)
	
	# 阶段间隔
	_in_gap = true
	get_tree().create_timer(2.0).timeout.connect(_next_phase, CONNECT_ONE_SHOT)

func _die_boss() -> void:
	set_process(false)
	_current_phase = null  # 隐藏血条
	GameState.active_enemies.erase(self)
	GameEvents.boss_defeated.emit(self)
	if not _exit_controlled:
		queue_free()

func _drop_items() -> void:
	if not _current_phase: return
	if GameState.is_practice_mode: return  # 练习不掉落
	var pos := global_position
	var phase := _current_phase
	var scatter := 50.0
	
	var drops: Array[int] = []
	for _i in range(phase.item_power): drops.append(Item.Type.POWER)
	for _i in range(phase.item_point): drops.append(Item.Type.POINT)
	for _i in range(phase.item_life): drops.append(Item.Type.LIFE_FRAGMENT)
	for _i in range(phase.item_bomb): drops.append(Item.Type.BOMB_FRAGMENT)
	for _i in range(phase.item_life_full): drops.append(Item.Type.LIFE_FULL)
	for _i in range(phase.item_bomb_full): drops.append(Item.Type.BOMB_FULL)
	
	for t in drops:
		var offset := Vector2(RNG.randf_range(-scatter, scatter), RNG.randf_range(-scatter, scatter))
		if _ctx: _ctx.spawn_item(t, pos + offset)
