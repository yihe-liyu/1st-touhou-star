extends GutTest
## 对话系统测试（阶段 0：重构前锁定现状）
## 覆盖：对话数据完整性 / DialogueBox 播放冒烟 / 行内 event 触发时机
## 注意：阶段 3（DialogueBox 步骤化）后，test_event_fires_on_line_show 会随语义迁移更新

# ═══════════ 数据完整性 ═══════════

func test_stage01_begin_data_valid():
	# 台词库格式：lines 是 { id: DialogueLine } 字典
	var data: DialogueData = load("res://data/dialogue/reimu/stage01_begin.tres")
	assert_not_null(data, "stage01_begin.tres 应存在且为 DialogueData")
	if data == null:
		return
	assert_gt(data.lines.size(), 0, "对话应有行")
	for line in data.lines.values():
		assert_gt(line.bubbles.size(), 0, "每行至少一个气泡")
		for b in line.bubbles:
			assert_not_null(b.speaker, "气泡应有 speaker")
			if b.speaker:
				assert_ne(b.speaker.char_name, "", "speaker 应有名字")


func test_profiles_valid():
	for path in [
		"res://data/dialogue/profile/reimu_profile.tres",
		"res://data/dialogue/profile/marisa_profile.tres",
		"res://data/dialogue/profile/ka_profile.tres",
	]:
		var p: CharacterProfile = load(path)
		assert_not_null(p, "%s 应存在" % path)
		if p:
			assert_ne(p.char_name, "", "%s 应有 char_name" % path)


# ═══════════ DialogueBox 播放冒烟 ═══════════

func _make_profile(name: String) -> CharacterProfile:
	var p := CharacterProfile.new()
	p.char_name = name
	return p


func _make_line(text: String, speaker_name: String = "测试") -> DialogueLine:
	var bubble := DialogueBubble.new()
	bubble.speaker = _make_profile(speaker_name)
	bubble.text = text
	var line := DialogueLine.new()
	line.bubbles = [bubble]
	return line


func test_play_steps_shows_first_line():
	# 步骤版冒烟：enter + line → 立绘出现
	var d := DialogueSteps.new()
	d.enter(_make_profile("测试"), Vector2(200, 200))
	d.line("l0")
	var box: CanvasLayer = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(box)
	box.play_steps(d.steps, {"l0": _make_line("测试台词")})
	await wait_seconds(0.6)  # 淡入 0.3s + runner 启动 + 显示
	assert_true(box.visible, "play 后应可见")
	assert_true(box._portrait_map.has("测试"), "第一句的立绘应出现")
	# 关闭 → finished → 等 queue_free 生效
	box._close()
	await box.finished
	await get_tree().process_frame
	assert_false(is_instance_valid(box), "关闭后应释放")


func test_event_fires_between_lines():
	# 新语义：event 是行与行之间的步骤（旧"显示瞬间"已废弃）
	var d := DialogueSteps.new()
	d.line("a")
	d.event("probe_event")
	d.line("b")
	var fired: Array[String] = []
	var cb := func(event_name: String): fired.append(event_name)
	GameEvents.dialogue_event.connect(cb)
	var box: CanvasLayer = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(box)
	box.play_steps(d.steps, {
		"a": _make_line("A"),
		"b": _make_line("B"),
	})
	await wait_seconds(0.6)
	assert_eq(fired, [], "第一句显示时还不该触发事件")
	box._advance()  # 说完 A → 进入 event 步骤
	assert_eq(fired, ["probe_event"], "行与行之间触发事件")
	box._close()
	await box.finished
	await get_tree().process_frame
	GameEvents.dialogue_event.disconnect(cb)


# ═══════════ 台词库内容抽查（防止重构迁移丢台词） ═══════════

func test_stage01_begin_lines_are_13():
	var data: DialogueData = load("res://data/dialogue/reimu/stage01_begin.tres")
	if data == null:
		return
	assert_eq(data.lines.size(), 13, "战前对话 13 句（迁移后应保持）")
	# id 完整性：r1~r7 / k1~k6
	var expected := ["r1", "r2", "r3", "r4", "r5", "r6", "r7", "k1", "k2", "k3", "k4", "k5", "k6"]
	for id in expected:
		assert_true(data.lines.has(id), "台词库应有 id %s" % id)
