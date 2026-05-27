extends BaseMenu
class_name PauseMenu

func _on_ready():
	# ── 进入动画 ──
	# 初始状态：blur 和 darken 都为 0（无模糊效果）
	$Overlay.material.set_shader_parameter("blur_strength", 0.0)
	$Overlay.material.set_shader_parameter("darken", 0.0)
	$Container.modulate = Color(1, 1, 1, 0)
	$Container.scale = Vector2(0.92, 0.92)

	var tw = create_tween().set_parallel(true)
	# 模糊 + 暗化逐渐增强
	tw.tween_property($Overlay, "material:shader_parameter/blur_strength", 3.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($Overlay, "material:shader_parameter/darken", 0.5, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 菜单文字淡入 + 弹性缩放弹出
	tw.tween_property($Container, "modulate", Color(1, 1, 1, 1), 0.25)
	tw.tween_property($Container, "scale", Vector2(1, 1), 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

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
