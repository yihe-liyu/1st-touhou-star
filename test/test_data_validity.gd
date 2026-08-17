extends GutTest
## 数据完整性测试 —— 关卡/Boss/符卡数据合法性与一致性

## 舞台注册表包含 Stage 1
func test_stage_registry_has_stage1():
	var reg: StageRegistry = load("res://data/registry/stage_registry.tres")
	assert_not_null(reg, "stage_registry.tres 应存在")
	if reg:
		var stages: Array = reg.stages
		assert_gt(stages.size(), 0, "注册表不应为空")
		var has_stage1 := false
		for s in stages:
			if s is StageData and s.stage_id == 1:
				has_stage1 = true
				assert_not_null(s.create_script, "Stage1 需要关卡脚本")
				assert_not_null(s.background_scene, "Stage1 需要背景")
		assert_true(has_stage1, "注册表应包含 Stage 1")


## 非符阶段数据：time_limit > 0, hp > 0（非符无 bonus 是设计模式）
## 注：non01 已改为无脚本非符（内容管线调整，move/shoot 脚本移除）
func test_non_spell_phase_valid():
	var phase: PhaseData = load("res://data/stages/stage01/phase/non01/non01.tres")
	assert_not_null(phase, "non01.tres 应存在")
	if phase:
		assert_eq(phase.uid, 0, "非符的 uid 应为 0")
		assert_gt(phase.hp, 0, "非符 hp 应 > 0")
		assert_gt(phase.time_limit, 0.0, "非符时限应 > 0")


## 符卡阶段（黄粱「不可测之梦」spell056）：uid 非 0, 有名字, 血量/时限合法, 挂移动/弹幕脚本
func test_spell_phase_valid():
	var phase: PhaseData = load("res://data/stages/stage03B/phase/spell03/spell056.tres")
	assert_not_null(phase, "spell056.tres 应存在")
	if phase:
		assert_ne(phase.uid, 0, "符卡 uid 不应为 0")
		assert_ne(phase.name, "", "符卡应有名字")
		assert_gt(phase.hp, 0, "符卡 hp 应 > 0")
		assert_gt(phase.time_limit, 0.0, "符卡时限应 > 0")
		assert_not_null(phase.move_script, "符卡需要移动脚本")
		assert_not_null(phase.shoot_script, "符卡需要弹幕脚本")


## 角色数据：灵梦/魔理沙都有射击脚本
func test_player_data_valid():
	for path in ["res://data/player_data/reimu_data.tres", "res://data/player_data/marisa_data.tres"]:
		var pd: PlayerData = load(path)
		assert_not_null(pd, "%s 应存在" % path)
		if pd:
			assert_not_null(pd.shoot_script, "%s 需要射击脚本" % path)
			assert_gt(pd.normal_speed, 0, "%s 常速应 > 0")
			assert_gt(pd.focus_speed, 0, "%s 低速应 > 0")


## 子弹配置（真实数据源 = AssetRegistry）：玩家主弹/子弹贴图与判定盒有效
func test_player_bullet_configs_valid():
	for key in ["reimu_main", "reimu_opt1", "reimu_opt2", "marisa_main", "marisa_opt2"]:
		var cfg: Dictionary = AssetRegistry.bullet_configs.get(key, {})
		assert_true(cfg.has("tex"), "%s 应有贴图配置" % key)
		assert_not_null(cfg.get("tex"), "%s 贴图应非空" % key)
		assert_true(cfg.has("hitbox"), "%s 应有判定配置" % key)
		var hb: Dictionary = cfg.get("hitbox", {})
		assert_true(hb.has("circle") or hb.has("rect"), "%s 判定应为 circle 或 rect" % key)
