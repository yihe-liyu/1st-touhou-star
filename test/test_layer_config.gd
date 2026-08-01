extends GutTest
## 图层配置测试：层级顺序正确 + 值唯一（防止日后改乱）

func test_layer_order():
	var L := LayerConfig
	assert_lt(L.PLAYER_BULLET, L.PLAYER, "玩家弹应在玩家之下")
	assert_lt(L.PLAYER, L.OPTION, "玩家应在子机之下")
	assert_lt(L.OPTION, L.ENEMY_BULLET, "子机应在敌弹之下")
	assert_lt(L.ENEMY, L.ENEMY_BULLET, "敌人应在敌弹之下")
	assert_lt(L.ENEMY_BULLET, L.BOSS, "敌弹应在 Boss 之下")
	assert_lt(L.BOSS, L.BOSS_HP_RING, "Boss 应在血量环之下")
	assert_lt(L.BOSS_HP_RING, L.EFFECT, "血量环应在特效之下")
	assert_lt(L.EFFECT, L.BOMB, "特效应在炸弹之下")
	assert_lt(L.BOMB, L.GAME_UI, "游戏物件应在 UI 之下")
	assert_lt(L.GAME_UI, L.OVERLAY, "UI 应在遮罩之下")

func test_layer_values_unique():
	var vals: Array = [
		LayerConfig.PLAYER_BULLET, LayerConfig.ITEM, LayerConfig.PLAYER,
		LayerConfig.OPTION, LayerConfig.ENEMY, LayerConfig.ENEMY_BULLET,
		LayerConfig.BOSS, LayerConfig.BOSS_HP_RING, LayerConfig.EFFECT,
		LayerConfig.BOMB, LayerConfig.GAME_UI, LayerConfig.UI_TOP,
		LayerConfig.OVERLAY, LayerConfig.DEBUG,
	]
	var seen: Dictionary = {}
	for v in vals:
		assert_false(seen.has(v), "图层值 %s 重复（两个图层撞在一起）" % v)
		seen[v] = true

func test_effect_above_enemy_bullets():
	assert_gt(LayerConfig.EFFECT, LayerConfig.ENEMY_BULLET,
		"击中/消弹特效必须显示在弹幕之上")

func test_ui_top_in_ui_range():
	assert_lt(LayerConfig.UI_TOP, LayerConfig.OVERLAY,
		"UI 内部置顶应低于遮罩层")
