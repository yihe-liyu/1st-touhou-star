extends Node
## 背景截图工具：独立渲染 stage01 背景到 PNG（视觉改前/改后对比用）
##
## 用法:
##   godot --path . res://tools/background_capture.tscn -- --out /home/cirno/Desktop
##   （--fixed-fps 60 保证帧节奏一致，两次跑同一帧数 → 可对比）

const BG_SCENE = preload("res://data/stages/stage01/background/stage01_background.tscn")

const SHOT_FRAMES := { 180: "t3s", 540: "t9s" }  # 3s（雾浓）/ 9s（相机移动+雾散）两档

var _frames: int = 0
var _vp: SubViewport
var _out_dir: String = "user://captures"


func _ready() -> void:
	var user_args := OS.get_cmdline_user_args()
	for i in range(0, user_args.size() - 1, 2):
		if user_args[i] == "--out":
			_out_dir = user_args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_vp = SubViewport.new()
	_vp.name = "CaptureViewport"
	_vp.size = Vector2i(768, 896)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var bg: StageBackground = BG_SCENE.instantiate()
	_vp.add_child(bg)
	StageManager.current_background = bg

	var runner := CoroutineRunner.new()
	runner.name = "CaptureRunner"
	add_child(runner)
	runner.run(func() -> bool: return true)

	# 直接启动背景演出协程（等价 load_stage 里对背景子节点的 start 循环）
	var decor := bg.get_node("Decor") as CoroutineScript
	var ctx := StageContext.new(runner)
	decor.start(ctx)

	print("capture started, out=", _out_dir)


func _process(_delta: float) -> void:
	_frames += 1
	if SHOT_FRAMES.has(_frames):
		var img := _vp.get_texture().get_image()
		img.linear_to_srgb()  # 视口纹理是线性空间，直接存 PNG 会偏暗 → 转 sRGB 再存
		var path := "%s/bg_%s.png" % [_out_dir, SHOT_FRAMES[_frames]]
		var err := img.save_png(path)
		print("saved %s (err=%d)" % [path, err])
	if _frames >= 600:
		get_tree().quit()
