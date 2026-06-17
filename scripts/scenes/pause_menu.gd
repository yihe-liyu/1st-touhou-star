# PauseMenu.gd — 暂停菜单覆盖层
extends NavPage

## true 表示 GameOver 模式（禁用「继续」）
var game_over_mode: bool = false


func _on_enter() -> void:
	super._on_enter()  # NavPage 入场动画

	# 暗色遮罩淡入
	_fade_overlay_in(0.3)

	if game_over_mode:
		var resume := _container.get_node_or_null("ResumeLabel")
		if resume:
			resume.set_meta("locked", true)
			refresh_colors()

	AudioManager.play_sfx(preload("res://assets/Sound/pause.wav"))


func _on_leave() -> void:
	_nav_enabled = false
	_stop_pulse()

	# 遮罩淡出 + 内容消隐 + 缩放
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_overlay_out(0.15)
	tw.tween_property(_container, "modulate", Color(1, 1, 1, 0), 0.12)
	tw.tween_property(_container, "scale", Vector2(0.95, 0.95), 0.12)
	tw.tween_callback(queue_free)


func _on_item_selected(index: int) -> void:
	match index:
		0:
			if not game_over_mode:
				GameManager.resume_game()
		1:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		2:
			get_tree().quit.call_deferred()


func _on_cancel() -> void:
	if not game_over_mode:
		GameManager.resume_game()
