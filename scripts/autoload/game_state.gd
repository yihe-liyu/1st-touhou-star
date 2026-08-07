# GameState.gd
extends Node
## 全局游戏数据唯一真源

const BossScript = preload("res://scripts/enemy/boss.gd")
const REGISTRY_PATH := "res://data/registry/stage_registry.tres"

# ══════════════════════════════════════════════
# 全局选择（持久化，不随着关卡重置）
# ══════════════════════════════════════════════

## 0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra
var selected_difficulty: int = 1
## 0=Reimu 1=Marisa
var selected_character: int = 0
## 当前打到第几面
var current_stage_id: int = 1

# ══════════════════════════════════════════════
# 运行时引用
# ══════════════════════════════════════════════

var player: Player = null
var active_enemies: Array = []
var stage_registry: StageRegistry

# ══════════════════════════════════════════════
# 符卡簿
# ══════════════════════════════════════════════

var spell_book: SpellRecordBook


## 子模块：符卡簿 / 存档（拆分职责，对外 API 不变）
var spell_book_mgr := SpellBookManager.new()
var save_mgr := SaveManager.new()


func _ready():
	spell_book_mgr.load()
	spell_book = spell_book_mgr.spell_book
	save_mgr.load()
	if ResourceLoader.exists(REGISTRY_PATH):
		stage_registry = ResourceLoader.load(REGISTRY_PATH)
	if not GameEvents.enemy_killed.is_connected(_on_enemy_killed):
		GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameManager.game_state_changed.connect(_on_state_changed)
	set_process(false)


# ══════════════════════════════════════════════
# 练习模式
# ══════════════════════════════════════════════

var is_practice_mode: bool = false
## 关卡练习模式（完整一面，不打下一关）
var is_stage_practice: bool = false
var practice_phase: PhaseData        ## 练习阶段配置（来自符卡记录）
var practice_boss_scene: PackedScene ## 练习 Boss 视觉（来自符卡记录）
var practice_name: String            ## 显示名
var practice_stage_id: int = 1
var practice_background: PackedScene
var restarting: bool = false  ## 练习模式重开标志（公开：菜单/场景需要读写）


func start_practice(phase: PhaseData, boss_scene: PackedScene, p_name: String, stage_id: int) -> void:
	is_practice_mode = true
	practice_phase = phase
	practice_boss_scene = boss_scene
	practice_name = p_name
	practice_stage_id = stage_id
	practice_background = _find_stage_background(stage_id)


func end_practice() -> void:
	if restarting:
		return
	is_practice_mode = false


func _find_stage_background(stage_id: int) -> PackedScene:
	var sd := _find_stage_data(stage_id)
	return sd.background_scene if sd else null

# ══════════════════════════════════════════════
# 关卡数据查找
# ══════════════════════════════════════════════

func _find_stage_data(stage_id: int) -> StageData:
	if stage_registry:
		return stage_registry.find(stage_id)
	# 回退：扫目录（stage_registry 未加载时用）
	return _scan_stage_dir(stage_id)


func _scan_stage_dir(stage_id: int) -> StageData:
	var dir := DirAccess.open("res://data/stages/")
	if not dir:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var sd: StageData = ResourceLoader.load("res://data/stages/" + file_name)
			if sd and sd.stage_id == stage_id:
				return sd
		file_name = dir.get_next()
	return null


## 获取所有 StageData（供练习菜单等界面遍历用）
func get_all_stages() -> Array[StageData]:
	if stage_registry and not stage_registry.stages.is_empty():
		return stage_registry.stages
	var result: Array[StageData] = []
	var dir := DirAccess.open("res://data/stages/")
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var sd: StageData = ResourceLoader.load("res://data/stages/" + file_name)
			if sd:
				result.append(sd)
		file_name = dir.get_next()
	return result

# ══════════════════════════════════════════════
# 符卡记录
# ══════════════════════════════════════════════

## 注册一张符卡（委托 SpellBookManager）
func unlock_spell(pid: PhaseIdentity) -> void:
	spell_book_mgr.unlock_spell(pid)


## 记录一次符卡尝试（委托）
func record_spell(pid: PhaseIdentity, captured: bool, score: int, elapsed: float) -> void:
	spell_book_mgr.record_spell(pid, captured, score, elapsed)


## 记录一次练习尝试（委托）
func record_practice(pid: PhaseIdentity, captured: bool) -> void:
	spell_book_mgr.record_practice(pid, captured)

# ══════════════════════════════════════════════
# 得分 & High Score
# ══════════════════════════════════════════════

## 高分表（委托 SaveManager）
var high_scores: Dictionary:
	get: return save_mgr.high_scores

var current_score: int = 0


func load_save_data():
	save_mgr.load()


func save_high_score(stage_id: int, score: int):
	save_mgr.save_high_score(stage_id, score)


func get_high_score(stage_id: int) -> int:
	return save_mgr.get_high_score(stage_id)


func add_score(amount: int):
	current_score += amount


func _on_enemy_killed(score: int, _position: Vector2):
	add_score(score)

# ══════════════════════════════════════════════
# 火力 (Power)
# ══════════════════════════════════════════════

## 火力值内部表示：0 = 1.00, 300 = 4.00，每 1 单位 = 0.01
var power_raw: int = 0


func get_power_display() -> String:
	return "%.2f" % get_power_float()


func get_power_float() -> float:
	return 1.00 + power_raw * 0.01


func add_power(amount: int) -> void:
	power_raw = clampi(power_raw + amount, 0, 300)


func on_miss_power_penalty() -> void:
	power_raw = clampi(power_raw - 50, 0, 300)

# ══════════════════════════════════════════════
# Max Point / Graze / Memory
# ══════════════════════════════════════════════

var max_point: int = 10000
var graze_count: int = 0
var memory_value: float = 50.0

# 记忆值每秒自然恢复量
const MEMORY_REGEN: float = 0.05
const MEMORY_GRAZE: float = 0.25
const MEMORY_HIT_BY_BULLET: float = -0.01
const MEMORY_MISS: float = 25.0


func add_max_point() -> int:
	var pts := max_point
	max_point += 10
	current_score += pts
	return pts


func add_memory(amount: float) -> void:
	memory_value = clampf(memory_value + amount, 0.0, 100.0)


func reduce_memory(amount: float) -> void:
	memory_value = clampf(memory_value - amount, 0.0, 100.0)

# ══════════════════════════════════════════════
# 残机 & Bomb
# ══════════════════════════════════════════════

var lives: int = 2          # 0~8
var life_fragments: int = 0 # 0~4
var bomb_count: int = 3      # 0~8
var bomb_fragments: int = 0 # 0~4


## 捡到残机碎片：集满 5 个合成一个完整残机
func collect_life_fragment() -> void:
	life_fragments += 1
	if life_fragments >= 5:
		life_fragments = 0
		_add_life()


func _add_life() -> void:
	if lives < 8:
		lives += 1


## 被弹扣除残机，返回本次是否存活（减之前有命即可）
func lose_life() -> bool:
	var had_life := lives > 0
	if had_life:
		lives -= 1
	return had_life


func collect_life_full() -> void:
	for _i in range(5):
		collect_life_fragment()


## 捡到 Bomb 碎片：集满 5 个合成一个完整 Bomb
func collect_bomb_fragment() -> void:
	bomb_fragments += 1
	if bomb_fragments >= 5:
		bomb_fragments = 0
		_add_bomb()


func _add_bomb() -> void:
	if bomb_count < 8:
		bomb_count += 1


func collect_bomb_full() -> void:
	for _i in range(5):
		collect_bomb_fragment()

# ══════════════════════════════════════════════
# 关卡生命周期
# ══════════════════════════════════════════════

func reset_all():
	current_score = 0
	max_point = 10000
	graze_count = 0
	power_raw = 0
	lives = 2
	life_fragments = 0
	bomb_count = 3
	bomb_fragments = 0
	memory_value = 50.0
	is_practice_mode = false


func reset_practice():
	current_score = 0
	max_point = 10000
	graze_count = 0
	power_raw = 300
	lives = 0
	life_fragments = 0
	bomb_count = 0
	bomb_fragments = 0
	memory_value = 50.0

# ══════════════════════════════════════════════
# Memory 自动恢复（仅在 PLAYING 时）
# ══════════════════════════════════════════════

func _on_state_changed(_old: int, new: int) -> void:
	set_process(new == GameManager.AppState.PLAYING)


func _process(delta: float) -> void:
	memory_value = clampf(memory_value + MEMORY_REGEN * delta, 0.0, 100.0)

# ══════════════════════════════════════════════
# 敌人列表
# ══════════════════════════════════════════════

func get_active_enemies() -> Array:
	return active_enemies


func get_boss():
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.get_script() == BossScript:
			return enemy
	return null


func clear_enemies():
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	active_enemies.clear()
