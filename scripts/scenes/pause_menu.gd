extends BaseMenu
class_name PauseMenu

## 如果为 true，禁用「返回游戏」选项，只能返回标题或退出
var game_over_mode: bool = false


func _on_ready():
	# 入场：暗色遮罩淡入
	$Overlay.modulate.a = 0.0
	
	if game_over_mode:
		var resume := $"Container/ResumeLabel"
		if resume:
			resume.set_meta("locked", true)
			# 重新刷新颜色，让 locked 立即生效
			refresh_colors(true)
	
	AudioManager.play_sfx(preload("res://assets/Sound/pause.wav"))

	var tw = create_tween()
	tw.tween_property($Overlay, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_leave():
	var tw = create_tween().set_parallel(true)
	tw.tween_property($Overlay, "modulate:a", 0.0, 0.15)
	tw.tween_property($Container, "modulate", Color(1, 1, 1, 0), 0.12)
	tw.tween_property($Container, "scale", Vector2(0.95, 0.95), 0.12)
	tw.tween_callback(queue_free)


func _on_item_selected(index: int):
	match index:
		0:
			if not game_over_mode:
				GameManager.resume_game()
		1:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		2:
			get_tree().quit.call_deferred()


func _on_back():
	if not game_over_mode:
		GameManager.resume_game()
