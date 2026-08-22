extends GutTest
## BGM 提示测试：曲名解析（AssetRegistry.get_bgm_title）+ 播放时提示显示（BgmHint）

func test_get_bgm_title_resolves():
	var stream: AudioStream = AssetRegistry.get_bgm("music_2")
	assert_not_null(stream, "music_2 应可加载")
	if stream == null:
		return
	assert_eq(AssetRegistry.get_bgm_title(stream), "夜间漫步", "music_2 → 夜间漫步")
	# 语义 key（stage1）指向同一文件 → 同一曲名
	var stream2: AudioStream = AssetRegistry.get_bgm("stage1")
	assert_eq(AssetRegistry.get_bgm_title(stream2), "夜间漫步", "stage1 → 同曲名（按路径关联）")


func test_get_bgm_title_unknown_returns_empty():
	var d := AudioStreamMP3.new()  # 任意无路径流
	assert_eq(AssetRegistry.get_bgm_title(d), "", "未知流返回空")


func test_bgm_hint_shows_title_on_bgm_started():
	var hint: CanvasLayer = load("res://scenes/ui/bgm_hint.tscn").instantiate()
	add_child(hint)
	await get_tree().process_frame  # 等 _ready 连接信号
	var stream := AssetRegistry.get_bgm("stage1")
	AudioManager.play_bgm(stream)
	await wait_seconds(0.1)
	var label: Label = hint.get_node("Root/Label")
	assert_eq(label.text, "BGM：夜间漫步", "播放 BGM 后提示显示曲名")
	# 清理：停止 BGM，释放 hint（_exit_tree 断开信号）
	AudioManager.stop_bgm()
	hint.queue_free()
	await get_tree().process_frame
