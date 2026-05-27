extends BaseMenu
class_name MainMenu

func _on_ready():
	GameManager.current_scene_path = "res://scenes/ui/main_menu.tscn"
	GameManager.push_menu(self)

	# ── Logo 入场动画 ──
	# 从上方向下滑入 + 淡入，结束后开始选项入场
	var logo = $logo
	var original_top = logo.offset_top

	logo.modulate = Color(1, 1, 1, 0)
	logo.offset_top = original_top - 60

	var tw = create_tween().set_parallel(true)
	tw.tween_property(logo, "modulate", Color(1, 1, 1, 1), 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "offset_top", original_top, 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Logo 动画完成 → 开始选项依次弹出
	tw.tween_callback(_play_entrance_animation).set_delay(0.6)

func _on_item_selected(index: int):
	match index:
		0:
			GameManager.change_scene("res://scenes/game_scene.tscn")
		8:
			get_tree().quit()

func _on_back():
	get_tree().quit()
