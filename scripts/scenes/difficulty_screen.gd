# DifficultyScreen.gd — 难度选择子页面
extends NavPage


func _on_enter() -> void:
	_setup_nav()
	if GameState.selected_difficulty < _nav_items.size():
		_nav_index = GameState.selected_difficulty

	# 黑底直接 50%
	$"Overlay".modulate.a = 1.0

	# 标题 + 选项同时开始
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := tex.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)
	_play_entrance()


func _on_leave() -> void:
	_nav_enabled = false
	_stop_pulse()
	queue_free()


func _on_item_selected(index: int) -> void:
	_nav_enabled = false
	_stop_pulse()
	finished.emit({"difficulty": index})


func _on_cancel() -> void:
	_nav_enabled = false
	_stop_pulse()
	finished.emit({})
