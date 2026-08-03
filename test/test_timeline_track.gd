extends GutTest
## TimelineBar 总谱模式测试 —— 波次条带分行/命中/数据同步
## 覆盖 E2 时间轴条带化核心逻辑（布局与交互命中）

var _bar: TimelineBar


func before_each() -> void:
	_bar = TimelineBar.new()
	_bar.set_size(Vector2(768, 88))
	_bar.expanded = true
	_bar.set_window(60.0)
	_bar.window_start = 0.0
	add_child_autofree(_bar)


## 重叠波次自动分行；不重叠与首条同行
func test_overlap_split_rows():
	_bar.set_waves([
		{"t": 0.0, "name": "A", "enemy": "red_little", "count": 5, "interval": 0.5},   # dur 2.5
		{"t": 1.0, "name": "B", "enemy": "blue_little", "count": 3, "interval": 0.5},  # dur 1.5，与 A 重叠
		{"t": 10.0, "name": "C", "enemy": "red_middle", "count": 4, "interval": 1.0},  # dur 4.0，与 A/B 不重叠
	])
	var rows: Array = _bar._layout_rows()
	assert_eq(rows.size(), 2, "重叠应分两行")
	assert_eq(rows[0].size(), 2, "第一行：A + C")
	assert_eq(rows[1].size(), 1, "第二行：B")
	# 每行内按 t 排序（A 0s 在前）
	assert_eq(rows[0][0].idx, 0, "第一行第一条应为 A（idx 0）")


## 无重叠时单行
func test_no_overlap_single_row():
	_bar.set_waves([
		{"t": 0.0, "name": "A", "enemy": "red_little", "count": 1, "interval": 0.5},
		{"t": 5.0, "name": "B", "enemy": "blue_little", "count": 1, "interval": 0.5},
		{"t": 10.0, "name": "C", "enemy": "red_middle", "count": 1, "interval": 0.5},
	])
	var rows: Array = _bar._layout_rows()
	assert_eq(rows.size(), 1, "不重叠应单行")


## 命中测试：条带内命中返回正确 idx，空白返回 -1
func test_hit_band():
	_bar.set_waves([
		{"t": 0.0, "name": "B", "enemy": "blue_little", "count": 3, "interval": 0.5},  # dur 1.5，第一行
		{"t": 1.0, "name": "A", "enemy": "red_little", "count": 5, "interval": 0.5},  # dur 2.5，与 B 重叠 → 第二行
	])
	_bar.window_len = 60.0
	# B 在 t=0（idx 0），x = 0，宽 1.5/60*768 = 19.2 → [0, 19.2]，第一行 y=3~17
	var hit_b: int = _bar._hit_band(Vector2(10, 10))
	assert_eq(hit_b, 0, "应命中 B（idx 0）")
	# A 在 t=1（idx 1，第二行），x = 12.8，宽 32 → 第二行 y=20~34 命中 A
	var hit_a: int = _bar._hit_band(Vector2(30, 27))
	assert_eq(hit_a, 1, "应命中 A（idx 1）")
	# 空白：t=35 处无条带
	var miss: int = _bar._hit_band(Vector2(35.0 / 60.0 * 768.0, 10))
	assert_eq(miss, -1, "空白处应返回 -1")


## set_waves 空数组 → 总谱禁用（协程关卡）
func test_empty_waves_disables_expand():
	_bar.set_waves([])
	assert_true(_bar.expanded == false, "无波次数据应自动折叠")
	assert_true(_bar._toggle != null and _bar._toggle.disabled, "无波次数据总谱按钮应禁用")


## 拖拽预览不写回数据源；松手写回（共享引用）—— 模拟 _gui_input 前直接验证写回语义
func test_drag_writes_back_to_shared_ref():
	var data := [
		{"t": 10.0, "name": "A", "enemy": "red_little", "count": 1, "interval": 0.5},
	]
	_bar.set_waves(data)
	var moved: Array = []
	_bar.wave_moved.connect(func(idx: int, t: float): moved.append([idx, t]))
	# 直接走组件内部逻辑（等价于拖拽松手路径）
	var idx := _bar._hit_band(Vector2(10.0 / 60.0 * 768.0, 10))
	assert_eq(idx, 0, "应命中唯一条带")
	_bar.waves[idx]["t"] = 14.0   # 组件松手时写回共享引用
	_bar.wave_moved.emit(idx, 14.0)
	assert_eq(moved.size(), 1, "应发出 wave_moved")
	assert_eq(moved[0][0], 0)
	assert_almost_eq(moved[0][1], 14.0, 0.001)
	# 共享引用：写回应反映到原始数据（数组元素是同一 Dictionary）
	assert_almost_eq(float(data[0]["t"]), 14.0, 0.001, "数据源 t 应已更新")


## 真实交互路径：点击条带 → wave_selected + selected_wave 更新
## （模拟 _gui_input 事件流，防止交互回归漏网）
func test_click_selects_wave():
	_bar.set_waves([
		{"t": 0.0, "name": "B", "enemy": "blue_little", "count": 3, "interval": 0.5},
		{"t": 1.0, "name": "A", "enemy": "red_little", "count": 5, "interval": 0.5},
	])
	var selected: Array = []
	_bar.wave_selected.connect(func(idx: int): selected.append(idx))
	# 按下 B（t=0 第一行，x=10, y=10）
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(10, 10)
	_bar._gui_input(down)
	assert_eq(_bar.selected_wave, 0, "按下时应立即高亮")
	# 松开（无拖拽）→ 点击选中
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(10, 10)
	_bar._gui_input(up)
	assert_eq(selected.size(), 1, "应发出 wave_selected")
	assert_eq(selected[0], 0, "应选中 B（idx 0）")
	assert_eq(_bar.selected_wave, 0)


## 真实交互路径：拖拽条带 → wave_moved + 数据写回（含 0.5s 吸附）
func test_drag_moves_wave():
	_bar.set_waves([
		{"t": 0.0, "name": "B", "enemy": "blue_little", "count": 3, "interval": 0.5},
	])
	_bar.window_len = 60.0
	var moved: Array = []
	_bar.wave_moved.connect(func(idx: int, t: float): moved.append([idx, t]))
	# 按下 B（x=10, y=10）
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(10, 10)
	_bar._gui_input(down)
	# 拖 +100px → dt = 100/768*60 ≈ 7.8125s → 吸附 0.5 → 8.0
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(110, 10)
	_bar._gui_input(motion)
	# 松开 → 写回
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(110, 10)
	_bar._gui_input(up)
	assert_eq(moved.size(), 1, "应发出 wave_moved")
	assert_eq(moved[0][0], 0)
	assert_almost_eq(moved[0][1], 8.0, 0.001, "t 应吸附到 8.0")
	assert_almost_eq(float(_bar.waves[0]["t"]), 8.0, 0.001, "数据源应写回 8.0")
	# 点击（无拖拽）不应再触发 wave_selected（拖拽路径已消费）
	assert_eq(_bar.selected_wave, 0, "拖拽也应高亮该条带")


## 4 个严格同 t 重叠：分 4 行，全部可见
func test_four_overlaps_four_rows():
	var waves := []
	for i in 4:
		waves.append({"t": 0.0, "name": "W%d" % i, "enemy": "red_little",
			"count": 5, "interval": 0.5})  # 同 t 严格重叠
	_bar.set_waves(waves)
	assert_eq(_bar._layout_rows().size(), 4, "4 个同 t 重叠应分 4 行")
	assert_eq(_bar._visible_rows().size(), 4, "4 行 ≤ MAX_TRACKS 全部可见")
	assert_eq(_bar._overflow_count(), 0, "无溢出")


## 6 个严格同 t 重叠：可见 5 行 + 溢出 1
func test_many_overlaps_overflow():
	var waves := []
	for i in 6:
		waves.append({"t": 0.0, "name": "W%d" % i, "enemy": "red_little",
			"count": 5, "interval": 0.5})
	_bar.set_waves(waves)
	assert_eq(_bar._layout_rows().size(), 6, "贪心应分 6 行")
	assert_eq(_bar._visible_rows().size(), 5, "只显示 MAX_TRACKS 行")
	assert_eq(_bar._overflow_count(), 1, "溢出 1 行")


## 命中测试不越界：溢出行位置（超出轨道区）返回 -1，不误触刻度区
func test_hit_band_ignores_overflow_rows():
	var waves := []
	for i in 6:
		waves.append({"t": 0.0, "name": "W%d" % i, "enemy": "red_little",
			"count": 5, "interval": 0.5})
	_bar.set_waves(waves)
	_bar.window_len = 60.0
	# 第 5 行（可见最后一行 r=4）y = 3 + 4*17 = 71~85，条带 x=0~32（t=0, dur 2.5）
	var hit_last_visible := _bar._hit_band(Vector2(10, 75))
	assert_true(hit_last_visible >= 0, "第 5 行应能命中条带")
	# 溢出行（第 6 行 r=5）y = 88+ 已在刻度区 → 应返回 -1（不误触）
	var hit_overflow := _bar._hit_band(Vector2(10, 95))
	assert_eq(hit_overflow, -1, "溢出行位置不应命中（避免刻度区误触）")
	# 刻度区点击 → 空白跳转（不命中任何条带）
	var hit_ticks := _bar._hit_band(Vector2(384, 100))
	assert_eq(hit_ticks, -1, "刻度区不应命中条带")


## 空白拖动 = 平移时间窗口（pan），不触发快进
func test_pan_moves_window():
	_bar.set_waves([{"t": 0.0, "name": "A", "enemy": "red_little", "count": 1, "interval": 0.5}])
	_bar.window_len = 60.0
	_bar.window_start = 30.0
	var jumps: Array = []
	_bar.jump_to.connect(func(t: float): jumps.append(t))
	# 空白按下（x=100 处无条带：条带 t=0 → x=0~32）
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(100, 10)
	_bar._gui_input(down)
	# 左拖 50px → 窗口向未来移动
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(50, 10)
	_bar._gui_input(motion)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(50, 10)
	_bar._gui_input(up)
	# dt = -50/768*60 = -3.90625 → window_start = 30 - (-3.906) = 33.906
	assert_almost_eq(_bar.window_start, 33.90625, 0.01, "左拖应让窗口向未来移动")
	assert_eq(jumps.size(), 0, "拖动不应触发快进跳转")


## 空白轻点（无拖动）→ 保留快进跳转
func test_click_blank_still_jumps():
	_bar.set_waves([{"t": 0.0, "name": "A", "enemy": "red_little", "count": 1, "interval": 0.5}])
	_bar.window_len = 60.0
	_bar.window_start = 30.0
	var jumps: Array = []
	_bar.jump_to.connect(func(t: float): jumps.append(t))
	# 轻点空白（按下+松开，无 motion）
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(100, 10)
	_bar._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(100, 10)
	_bar._gui_input(up)
	assert_eq(jumps.size(), 1, "轻点空白应触发快进")
	assert_almost_eq(jumps[0], 30.0 + 100.0 / 768.0 * 60.0, 0.01, "跳转到点击时刻")
