# CharacterScreen.gd — 角色选择子页面
extends NavPage


func _on_enter() -> void:
	_setup_nav()
	if GameState.selected_character < _nav_items.size():
		_nav_index = GameState.selected_character

	# 难度徽章
	var diff_names := ["Easy", "Normal", "Hard", "Lunatic", "Extra"]
	var badge: Label = $"DifficultyBadge"
	var diff_idx := clampi(GameState.selected_difficulty, 0, diff_names.size() - 1)
	badge.text = diff_names[diff_idx] + " 难度"

	# 黑底直接 50%
	$"Overlay".modulate.a = 1.0

	# 标题 + 徽章 + 选项同时开始
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	badge.modulate.a = 0.0
	var tw := tex.create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)
	tw.tween_property(badge, "modulate:a", 1.0, 0.5)
	_play_entrance()


func _on_leave() -> void:
	_nav_enabled = false
	_stop_pulse()
	queue_free()


func _on_item_selected(index: int) -> void:
	_nav_enabled = false
	_stop_pulse()
	finished.emit({"character": index})


func _on_cancel() -> void:
	_nav_enabled = false
	_stop_pulse()
	finished.emit({})
