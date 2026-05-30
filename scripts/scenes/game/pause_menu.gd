extends BaseMenu
class_name PauseMenu

func _on_ready():
	# 入场：暗色遮罩淡入
	$Overlay.modulate.a = 0.0
	
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
			GameManager.resume_game()
		1:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		2:
			get_tree().quit.call_deferred()

func _on_back():
	GameManager.resume_game()
