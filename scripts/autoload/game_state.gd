# GameState.gd
extends Node

const BossScript = preload("res://scripts/enemy/boss.gd")
const SpellBookClass = preload("res://scripts/data/spell_record_book.gd")

const SPELL_BOOK_PATH := "res://data/spell_records.tres"

# 0=Easy 1=Normal 2=Hard 3=Lunatic
var selected_difficulty: int = 1
# 0=Reimu 1=Marisa
var selected_character: int = 0
var player: Player = null
var spell_book

func _load_spell_book() -> void:
	if ResourceLoader.exists(SPELL_BOOK_PATH):
		spell_book = ResourceLoader.load(SPELL_BOOK_PATH)
	else:
		spell_book = SpellBookClass.new()

func _save_spell_book() -> void:
	ResourceSaver.save(spell_book, SPELL_BOOK_PATH)

func record_spell(ch: int, st: int, pt: int, pn: int, diff: int, captured: bool, score: int, elapsed: float, order: int = 1, uid: int = 0) -> void:
	spell_book.record_attempt(ch, st, pt, pn, diff, captured, score, elapsed, order, uid)
	_save_spell_book()

func record_practice(ch: int, st: int, pt: int, pn: int, diff: int, captured: bool) -> void:
	spell_book.record_practice(ch, st, pt, pn, diff, captured)
	_save_spell_book()

var active_enemies: Array = []

var high_scores: Dictionary = {}
var current_score: int = 0
# 火力值内部表示：0 = 1.00, 300 = 4.00，每 1 单位 = 0.01
var power_raw: int = 0
var max_point: int = 10000
var graze_count: int = 0  # 擦弹数

var lives: int = 2           # 完整残机数（0~8）
var life_fragments: int = 0  # 残机碎片数（0~4）
var bomb_count: int = 3      # 完整 Bomb 数（0~8）
var bomb_fragments: int = 0  # Bomb 碎片数（0~4）

var memory_value: float = 50.0  # 0~100=正常, -100=黑白冻结, 200=狂乱

var _config: ConfigFile
# 记忆值每秒自然恢复量
const MEMORY_REGEN: float = 0.05

const SAVE_PATH: String = "user://save_data.cfg"

func _ready():
	_load_spell_book()
	load_save_data()
	if not GameEvents.enemy_killed.is_connected(_on_enemy_killed):
		GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameManager.game_state_changed.connect(_on_state_changed)
	# 非游戏状态下不跑 _process
	set_process(false)

func load_save_data():
	_config = ConfigFile.new()
	if _config.load(SAVE_PATH) != OK:
		return
	for key in _config.get_section_keys("high_scores"):
		high_scores[int(key)] = _config.get_value("high_scores", key)

func save_high_score(stage_id: int, score: int):
	var prev = get_high_score(stage_id)
	if score <= prev:
		return
	high_scores[stage_id] = score
	_config.set_value("high_scores", str(stage_id), score)
	_config.save(SAVE_PATH)

func get_high_score(stage_id: int) -> int:
	return high_scores.get(stage_id, 0)

func add_score(amount: int):
	current_score += amount

func add_max_point() -> int:
	var pts := max_point
	max_point += 10
	current_score += pts
	return pts

func reset_all():
	current_score = 0
	graze_count = 0
	power_raw = 0
	lives = 2
	life_fragments = 0
	bomb_count = 3
	bomb_fragments = 0
	memory_value = 50.0



func _on_enemy_killed(score: int, _position: Vector2):
	add_score(score)

func get_power_display() -> String:
	var value := 1.00 + power_raw * 0.01
	return "%.2f" % value

func get_power_float() -> float:
	return 1.00 + power_raw * 0.01

func add_power(amount: int) -> void:
	power_raw = clampi(power_raw + amount, 0, 300)

func on_miss_power_penalty() -> void:
	power_raw = clampi(power_raw - 50, 0, 300)

## 捡到残机碎片：集满 5 个合成一个完整残机
func collect_life_fragment() -> void:
	life_fragments += 1
	if life_fragments >= 5:
		life_fragments = 0
		_add_life()

func _add_life() -> void:
	if lives < 8:
		lives += 1

func collect_life_full() -> void:
	for i in range(5):
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
	for i in range(5):
		collect_bomb_fragment()


func _on_state_changed(_old: int, new: int) -> void:
	set_process(new == GameManager.AppState.PLAYING)

func _process(delta: float) -> void:
	memory_value = clampf(memory_value + MEMORY_REGEN * delta, 0.0, 100.0)

func add_memory(amount: float) -> void:
	memory_value = clampf(memory_value + amount, 0.0, 100.0)

func reduce_memory(amount: float) -> void:
	memory_value = clampf(memory_value - amount, 0.0, 100.0)

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
