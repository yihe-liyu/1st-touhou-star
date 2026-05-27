extends BaseMenu
class_name PauseMenu

func _on_ready():
	# ── 进入动画 ──
	# 所有选项初始不可见 + 略微缩小
	var labels = $Container.get_children()
	for label in labels:
		label.modulate = Color(1, 1, 1, 0)
		label.scale = Vector2(0.9, 0.9)

	# 模糊初始为 0
	$Overlay.material.set_shader_parameter("blur_strength", 0.0)
	$Overlay.material.set_shader_parameter("darken", 0.0)

	# 动画期间禁用输入
	input_enabled = false

	var tw = create_tween().set_parallel(true)
	# 模糊 + 暗化逐渐增强
	tw.tween_property($Overlay, "material:shader_parameter/blur_strength", 3.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($Overlay, "material:shader_parameter/darken", 0.5, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 每个选项依次弹出
	for i in labels.size():
		var label = labels[i]
		var delay = i * 0.08
		tw.tween_property(label, "modulate", Color(1, 1, 1, 1), 0.2).set_delay(delay)
		tw.tween_property(label, "scale", Vector2(1, 1), 0.25).set_delay(delay)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 动画完成后恢复输入
	var total = (labels.size() - 1) * 0.08 + 0.25
	tw.tween_callback(func(): input_enabled = true).set_delay(total)

func _on_leave():
	# ── 退出动画：模糊 + 暗化 + 菜单一起淡出 ──
	var tw = create_tween().set_parallel(true)
	tw.tween_property($Overlay, "material:shader_parameter/blur_strength", 0.0, 0.18)
	tw.tween_property($Overlay, "material:shader_parameter/darken", 0.0, 0.15)
	tw.tween_property($Container, "modulate", Color(1, 1, 1, 0), 0.12)
	tw.tween_property($Container, "scale", Vector2(0.95, 0.95), 0.12)
	# 动画结束后自己清理
	tw.tween_callback(queue_free)

func _on_item_selected(index: int):
	match index:
		0:
			GameManager.resume_game()
		1:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		2:
			get_tree().quit.call_deferred()

func _on_back():
	GameManager.resume_game()
