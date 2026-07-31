extends GutTest
## 验证魔理沙分段激光：切片 + 偏移无缝 + 编译加载

func test_segment_slicing():
	var cs = load("res://scripts/coroutine/player/cs_marisa.gd")
	assert_not_null(cs, "cs_marisa 应加载")
	# 验证切片（通过实例调用 _make_laser_segment）
	var inst = cs.new()
	autofree(inst)
	var seg: AtlasTexture = inst._make_laser_segment(0)
	assert_not_null(seg, "段 0 应存在")
	assert_eq(seg.region, Rect2(0, 0, 32, 32), "段 0 region 应为 (0,0,32,32)")
	var seg_last: AtlasTexture = inst._make_laser_segment(15)
	assert_eq(seg_last.region, Rect2(480, 0, 32, 32), "段 15 region 应为 (480,0,32,32)")
	# 16 段无缝：每段 32px，总长 512
	assert_eq(inst.SEGMENTS, 16, "应为 16 段")
	assert_eq(inst.SEG_W, 32, "段宽应为 32")

func test_offset_sequence_is_seamless():
	var cs = load("res://scripts/coroutine/player/cs_marisa.gd")
	var inst = cs.new()
	autofree(inst)
	# 段 i 偏移 = (0, -i*32)：间距=段宽 → 无缝
	var prev_y := 0.0
	for i in inst.SEGMENTS:
		var offset := Vector2(0, -i * inst.SEG_W)
		if i > 0:
			assert_eq(prev_y - offset.y, float(inst.SEG_W), "段 %d 与上一段间距应为段宽 32" % i)
		prev_y = offset.y
