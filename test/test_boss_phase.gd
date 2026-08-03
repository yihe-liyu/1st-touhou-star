extends GutTest
## Boss 符卡判定测试 —— 捕获/超时/时符/防双清/掉落表
## 策略：stub autoload 副作用，只测判定逻辑

const BOSS_CLASS = preload("res://scripts/enemy/boss.gd")

var _boss: Boss


## 覆写 spawn_item 记录调用的测试上下文
class CtxSpy:
	extends StageContext
	var calls: Array = []

	func _init(p_runner: CoroutineRunner) -> void:
		super(p_runner)

	func spawn_item(type: int, position: Vector2) -> void:
		calls.append([type, position])


func before_each():
	_boss = BOSS_CLASS.new()
	autofree(_boss)
	# 隔离所有 autoload 副作用
	stub("BulletManager", "start_death_clear").to_do_nothing()
	stub("GameState", "record_spell").to_do_nothing()
	stub("GameState", "record_practice").to_do_nothing()
	stub("GameState", "add_score").to_do_nothing()
	stub("GameState", "unlock_spell").to_do_nothing()


func _make_phase(hp: int = 100, time_limit: float = 10.0, timeout_only: bool = false, bonus: int = 10000) -> PhaseData:
	var p := PhaseData.new()
	p.name = "测试符卡" if not timeout_only else ""
	p.hp = hp
	p.time_limit = time_limit
	p.is_timeout_only = timeout_only
	p.bonus = bonus
	return p


## 辅助：跳过 HP 上涨 tween，直接进入可受击状态
func _skip_hp_tween() -> void:
	_boss._invincible = false


## 普通符卡：超时未击破 → captured=false
func test_normal_spell_timeout_is_not_captured():
	var phase := _make_phase(100, 5.0)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_boss._process(5.0 + 0.01)  # 超过时限
	assert_signal_emitted(_boss, "phase_cleared", "超时应触发 phase_cleared")
	var params = get_signal_parameters(_boss, "phase_cleared", 0)
	assert_eq(params[0], false, "普通符卡超时不应算捕获")


## 时符：超时撑过去 → captured=true
func test_timeout_spell_timeout_is_captured():
	var phase := _make_phase(100, 5.0, true)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_boss._process(5.0 + 0.01)
	assert_signal_emitted(_boss, "phase_cleared")
	var params = get_signal_parameters(_boss, "phase_cleared", 0)
	assert_eq(params[0], true, "时符撑到超时应算捕获")


## 击破捕获：HP 打空 → captured=true
func test_destroy_spell_is_captured():
	var phase := _make_phase(100)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_skip_hp_tween()
	_boss.take_damage(100)  # 打空
	assert_signal_emitted(_boss, "phase_cleared")
	var params = get_signal_parameters(_boss, "phase_cleared", 0)
	assert_eq(params[0], true, "击破应算捕获")


## 无敌期间：伤害无效
func test_damage_ignored_while_invincible():
	var phase := _make_phase(100)
	_boss.start_phase(phase)
	_boss.hp = 100
	_boss._invincible = true
	_boss.take_damage(100)
	assert_eq(_boss.hp, 100, "无敌期间不应扣血")


## 时符 hp 无限：伤害不触发清除（is_timeout_only 时 hp=999999）
func test_timeout_spell_immune_to_damage():
	var phase := _make_phase(100, 10.0, true)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_skip_hp_tween()
	_boss.take_damage(999999)
	assert_false(_boss._cleared, "时符不应因伤害清除")


## 双重清除保护：phase_cleared 只发一次
func test_no_double_clear():
	var phase := _make_phase(50, 5.0)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_skip_hp_tween()
	_boss.take_damage(50)     # 击破
	_boss.take_damage(50)     # 再来一下（应被 _cleared 保护挡住）
	_boss._process(5.0 + 0.01)  # 超时（也应被挡住）
	assert_signal_emit_count(_boss, "phase_cleared", 1, "phase_cleared 只能发出一次")


## bonus 随时间递减
func test_bonus_decreases_over_time():
	var phase := _make_phase(100, 10.0, false, 10000)
	_boss.start_phase(phase)
	_boss._process(5.0)  # 过 5 秒
	assert_lt(_boss._bonus, 10000, "bonus 应随时间递减")
	assert_gt(_boss._bonus, 0, "bonus 不应在时限内耗尽到负")


## 掉落表：按配置精确生成掉落（用 CtxSpy 记录）
func test_drop_items_matches_config():
	var phase := _make_phase()
	phase.item_power = 2
	phase.item_point = 1
	phase.item_life = 3
	phase.item_bomb = 4
	phase.item_life_full = 1
	phase.item_bomb_full = 2
	_boss._current_phase = phase
	_boss.global_position = Vector2(448, 240)

	var runner := CoroutineRunner.new()
	autofree(runner)
	var ctx := CtxSpy.new(runner)
	_boss._ctx = ctx

	_boss._drop_items()
	var calls: Array = ctx.calls
	assert_eq(calls.size(), 2 + 1 + 3 + 4 + 1 + 2, "掉落总数应为 13")
	# 分类验证
	var power := 0
	var point := 0
	var life := 0
	var bomb := 0
	var life_full := 0
	var bomb_full := 0
	for c in calls:
		match c[0]:
			Item.Type.POWER: power += 1
			Item.Type.POINT: point += 1
			Item.Type.LIFE_FRAGMENT: life += 1
			Item.Type.BOMB_FRAGMENT: bomb += 1
			Item.Type.LIFE_FULL: life_full += 1
			Item.Type.BOMB_FULL: bomb_full += 1
	assert_eq(power, 2, "POWER 应掉 2 个")
	assert_eq(point, 1, "POINT 应掉 1 个")
	assert_eq(life, 3, "LIFE_FRAGMENT 应掉 3 个")
	assert_eq(bomb, 4, "BOMB_FRAGMENT 应掉 4 个")
	assert_eq(life_full, 1, "LIFE_FULL 应掉 1 个")
	assert_eq(bomb_full, 2, "BOMB_FULL 应掉 2 个")


## 练习模式不掉落
func test_no_drops_in_practice_mode():
	var phase := _make_phase()
	phase.item_power = 2
	_boss._current_phase = phase
	var runner := CoroutineRunner.new()
	autofree(runner)
	var ctx := CtxSpy.new(runner)
	_boss._ctx = ctx

	var original := GameState.is_practice_mode
	GameState.is_practice_mode = true
	_boss._drop_items()
	GameState.is_practice_mode = original

	assert_eq(ctx.calls.size(), 0, "练习模式不应掉落")

## ── 难度差分 ──

func _mk_phase(p_name: String) -> PhaseData:
	var pd := PhaseData.new()
	pd.name = p_name
	pd.time_limit = 30.0
	pd.hp = 1000
	pd.shoot_script = load("res://scripts/coroutine/timeline/timeline.gd")
	return pd

func test_phases_for_difficulty_groups():
	var bd := BossData.new()
	bd.phase(_mk_phase("N1")).easy_phase(_mk_phase("E1")).hard_phase(_mk_phase("H1")).lunatic_phase(_mk_phase("L1"))
	assert_eq(bd.phases_for_difficulty(1)[0].name, "N1", "Normal 取 phases")
	assert_eq(bd.phases_for_difficulty(0)[0].name, "E1", "Easy 取 phases_easy")
	assert_eq(bd.phases_for_difficulty(2)[0].name, "H1", "Hard 取 phases_hard")
	assert_eq(bd.phases_for_difficulty(3)[0].name, "L1", "Lunatic 取 phases_lunatic")

func test_phases_for_difficulty_fallback():
	var bd := BossData.new()
	bd.phase(_mk_phase("N1"))
	# 其他难度未配置 → 回退 Normal/phases
	assert_eq(bd.phases_for_difficulty(0)[0].name, "N1", "Easy 空回退 Normal")
	assert_eq(bd.phases_for_difficulty(2)[0].name, "N1", "Hard 空回退 Normal")
	assert_eq(bd.phases_for_difficulty(3)[0].name, "N1", "Lunatic 空回退 Normal")
	assert_eq(bd.phases_for_difficulty(99)[0].name, "N1", "未知难度回退 Normal")

func test_validate_checks_all_difficulty_groups():
	var bd := BossData.new()
	bd.phase(_mk_phase("N1"))
	var bad := PhaseData.new()
	bad.name = "坏符"
	bad.time_limit = 0.0  # 非法时限 → 校验应报错
	bd.lunatic_phase(bad)
	var errs := bd.validate()
	assert_true(errs.size() >= 1, "Lunatic 组非法阶段应被校验捕获")

## ── 多 Boss ──

func test_all_bosses_merges_and_sorts():
	var sd := StageData.new()
	sd.create_script = load("res://scripts/coroutine/timeline/timeline.gd")
	# 旧字段（单 Boss）
	var b1 := BossData.new()
	b1.boss_name = "老Boss"
	sd.boss = b1
	sd.boss_time = 35.0
	# 多 Boss 数组（乱序 + 一个与旧字段重复）
	var b2 := BossData.new()
	b2.boss_name = "中Boss"
	var b3 := BossData.new()
	b3.boss_name = "最终Boss"
	sd.bosses = [
		{"boss": b3, "t": 90.0},
		{"boss": b1, "t": 35.0},   # 与旧字段重复 → 去重
		{"boss": b2, "t": 60.0},
	]
	var list := sd.all_bosses()
	assert_eq(list.size(), 3, "去重后 3 个 Boss")
	assert_eq(list[0]["boss"].boss_name, "老Boss", "按时间升序 1")
	assert_eq(list[1]["boss"].boss_name, "中Boss", "按时间升序 2")
	assert_eq(list[2]["boss"].boss_name, "最终Boss", "按时间升序 3")

func test_boss_index_in_phase_identity():
	var pid := PhaseIdentity.from_phase(PhaseData.new(), 1, 0, 0, 0, 2)
	assert_eq(pid.boss_index, 2, "boss_index 传入")
	var pid2 := PhaseIdentity.from_phase(PhaseData.new(), 1, 0, 0, 0)
	assert_eq(pid2.boss_index, 0, "默认 boss_index = 0")
