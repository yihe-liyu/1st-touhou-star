extends BaseMenu
class_name PauseMenu

func _on_ready():
	# ── 模糊背景进入动画 ──
	# 选项依次弹出由 BaseMenu 自动处理
	$Overlay.material.set_shader_parameter("blur_strength", 0.0)
	$Overlay.material.set_shader_parameter("darken", 0.0)
	
	AudioManager.play_sfx(preload("res://assets/Sound/pause.wav"))

	var tw = create_tween().set_parallel(true)
	tw.tween_property($Overlay, "material:shader_parameter/blur_strength", 3.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($Overlay, "material:shader_parameter/darken", 0.5, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

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
