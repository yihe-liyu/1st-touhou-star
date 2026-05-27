extends BaseMenu
class_name MainMenu

func _on_ready():
	GameManager.current_scene_path = "res://scenes/ui/main_menu.tscn"
	GameManager.push_menu(self)

	# ── Logo 入场动画（shader 圆形展开 + 辉光）──
	# progress: 0 → 从中心圆形展开，1 → 完全显示
	$logo.material.set_shader_parameter("progress", 0.0)

	var tw = create_tween()
	tw.tween_property($logo.material, "shader_parameter/progress", 1.0, 4.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Logo 动画完成 → 开始选项依次弹出
	tw.tween_callback(_play_entrance_animation)

func _on_item_selected(index: int):
	match index:
		0:
			GameManager.change_scene("res://scenes/game_scene.tscn")
		8:
			get_tree().quit()

func _on_back():
	get_tree().quit()
