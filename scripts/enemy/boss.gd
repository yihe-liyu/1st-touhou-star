# Boss.gd
class_name Boss
extends Area2D

const HPRingClass = preload("res://scripts/scenes/boss_hp_ring.gd")

signal phase_cleared(captured: bool, bonus: int)

var boss_data: BossData
var hp: int = 0
var hitbox_radius: float

var _ctx: StageContext
var _phase_index: int = -1
var _current_phase: PhaseData
var _bonus: int = 0
var _elapsed: float = 0.0
var _invincible: bool = false
var _open_reduce_left: float = 0.0   # 开局减伤剩余时长（秒）
var _open_reduce_ratio: float = 0.0  # 开局减伤比例（0~1）
var _move: CoroutineRunner
var _shoot: CoroutineRunner
var _stage_id: int
var boss_index: int = 0   ## 第几个 Boss（多 Boss 关卡时设置；记录区分用）
var _spell_count: int = 0
var _non_count: int = 0
var _pid: PhaseIdentity
var _exit_controlled: bool = false
var _cleared: bool = false

func current_phase() -> PhaseData: return _current_phase
func current_bonus() -> int: return _bonus
func get_elapsed() -> float: return _elapsed
func get_phase_id() -> PhaseIdentity: return _pid
func is_in_gap() -> bool:
	return _cleared

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
	
	var ring := HPRingClass.new()
	ring.setup(self)
	add_child(ring)
	
	hitbox_radius = data.hitbox_radius
	var shape := CircleShape2D.new()
	shape.radius = hitbox_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	collision_layer = 0
	collision_mask = 0

	for child in get_children():
		if child.get_script() == HPRingClass:
			child.visible = false
			break

func start_boss() -> void:
	set_process(true)
	GameState.active_enemies.append(self)
	tree_exited.connect(func(): GameState.active_enemies.erase(self))
	GameEvents.boss_spawned.emit(self)
	collision_layer = 4
	collision_mask = 2


func start_phase(data: PhaseData) -> void:
	# 配置校验：time_limit<=0 会除零/立即超时，防御性拒绝
	for e in data.validate():
		push_error("Boss.start_phase 配置错误: " + e)
	_cleared = false
	_phase_index += 1
	_current_phase = data
	_elapsed = 0.0
	_bonus = data.bonus
	_invincible = true
	hp = 0
	# 开局减伤参数暂存，计时从"无敌解除"（涨血完，玩家能打伤）开始
	_open_reduce_ratio = data.open_reduce_ratio
	_open_reduce_left = 0.0
	
	# 显示血条
	for child in get_children():
		if child.get_script() == HPRingClass:
			child.visible = true
			break
	
	# 计数
	if data.uid != 0:
		_spell_count += 1
	else:
		_non_count += 1
	
	_pid = PhaseIdentity.from_phase(data, _stage_id, _phase_index, _spell_count, _non_count, boss_index)
	if boss_data:
		_pid.boss_scene = boss_data.visual  # 练习用 Boss 视觉（随解锁存入记录；测试直构无 setup 时跳过）
		_pid.boss_name = boss_data.boss_name  # Boss 名（左上角显示用）
	if not GameState.is_practice_mode:
		GameState.unlock_spell(_pid)
	
	if data.name != "":
		GameEvents.phase_start.emit(data)
	
	# HP 从 0 涨到满
	var twn := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	twn.tween_property(self, "hp", data.hp, 1.0)
	twn.tween_callback(func():
		if data.is_timeout_only:
			_invincible = true
			hp = 999999
		else:
			_invincible = false
			# 玩家能打伤时才开始减伤计时（完整 open_reduce_time 秒）
			_open_reduce_left = data.open_reduce_time if _open_reduce_ratio > 0.0 else 0.0
		
		if data.move_script:
			_move = data.move_script.new()
			add_child(_move)
			_apply_phase_params(_move, data.params)
			_move.start(_ctx, self)
		if data.shoot_script:
			_shoot = data.shoot_script.new()
			add_child(_shoot)
			_apply_phase_params(_shoot, data.params)
			_shoot.start(_ctx, self)
	)


func _process(delta: float) -> void:
	if not _current_phase: return
	_elapsed += delta
	
	if _bonus > 0:
		# maxf 防御：time_limit 非法为 0 时优雅降级（正常配置由 validate 拦截）
		var t := maxf(_current_phase.time_limit, 0.001)
		var tick := maxi(1, int(float(_current_phase.bonus) / t * delta))
		_bonus = maxi(0, _bonus - tick)
	
	GameEvents.phase_bonus_tick.emit(_bonus)

	if _open_reduce_left > 0.0:
		_open_reduce_left = maxf(_open_reduce_left - delta, 0.0)

	if _elapsed >= _current_phase.time_limit:
		_clear_phase(_current_phase.is_timeout_only)


## 小数伤害累积器（0.5×2 次 = 1 → 扣 1 血）
var _dmg_acc: float = 0.0

func take_damage(damage: float) -> void:
	if _invincible: return
	if not _current_phase: return
	if _open_reduce_left > 0.0 and _open_reduce_ratio > 0.0:
		damage *= 1.0 - _open_reduce_ratio  # 开局减伤
	_dmg_acc += damage
	var full: int = int(_dmg_acc)
	if full <= 0:
		return
	_dmg_acc -= full
	hp -= full
	if hp <= 0 and not _current_phase.is_timeout_only:
		_clear_phase(true)


func _clear_phase(captured: bool) -> void:
	if _cleared: return
	_cleared = true
	_invincible = true
	if _move: _move.stop(); _move.queue_free(); _move = null
	if _shoot: _shoot.stop(); _shoot.queue_free(); _shoot = null
	
	if _pid:
		# 阶段已开始（_pid 已生成）才记录；Ctrl+G 在阶段开始前触发时只跳阶段不落盘
		if GameState.is_practice_mode:
			GameState.record_practice(_pid, captured)
		else:
			GameState.record_spell(_pid, captured, _bonus, _elapsed)
	
	GameEvents.phase_end.emit(captured, _bonus)
	if captured and _bonus > 0:
		GameState.add_score(_bonus)
	
	_drop_items()
	if _ctx:
		_ctx.bullets.death_clear(global_position, 960, 0.75, 30)
	else:
		BulletManager.start_death_clear(global_position, 960, 0.75, 30)
	phase_cleared.emit(captured, _bonus)


## 外部受控死亡（练习模式等场景调用）
func die() -> void:
	_die()


func _die() -> void:
	set_process(false)
	_current_phase = null
	GameState.active_enemies.erase(self)
	GameEvents.boss_defeated.emit(self)
	if not _exit_controlled:
		queue_free()


func _drop_items() -> void:
	if not _current_phase: return
	if GameState.is_practice_mode: return
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


## 阶段脚本参数注入（工作台编辑的 PhaseData.params → 脚本同名属性）
## 注意：这里只有参数注入，掉落逻辑在 _drop_items（_clear_phase 击破时）——
## 曾经残留过一份掉落代码导致 start_phase 时误掉道具（已删，勿再贴回）
func _apply_phase_params(script: Node, params: Dictionary) -> void:
	for k in params:
		if k in script:  # 脚本有该属性才设置（避免乱设）
			script.set(k, params[k])
