extends CoroutineScript
## Logo 演出脚本（stage01 风格）：7s 处显示 logo 淡入 → 停留 → 淡出
## 挂到 StageTimeline.events（type=custom）；target 可选（无则挂舞台）

const LOGO_TEX = preload("res://assets/Textures/front/logo/logo1.png")

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	var layer := CanvasLayer.new()
	layer.layer = 32
	var logo := TextureRect.new()
	logo.texture = LOGO_TEX
	logo.global_position = Vector2(GameConfig.FIELD_CENTER_X - (logo.texture.get_size().x / 2), 250)
	logo.modulate.a = 0.0
	layer.add_child(logo)
	add_child(layer)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(logo, "modulate:a", 1.0, 2.0)
	tw.tween_interval(3.0)
	tw.tween_property(logo, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func():
		layer.queue_free()
		stop()
	)
