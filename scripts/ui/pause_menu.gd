extends BaseMenu
class_name PauseMenu

func _on_ready():
	# ── 进入动画 ──
	# 初始状态：全透明 + 略微缩小
	$Overlay.modulate = Color(1, 1, 1, 0)
	$Container.modulate = Color(1, 1, 1, 0)
	$Container.scale = Vector2(0.92, 0.92)

	var tw = create_tween().set_parallel(true)
	# 背景模糊渐入
	tw.tween_property($Overlay, "modulate", Color(1, 1, 1, 1), 0.3)
	# 菜单文字淡入 + 弹性缩放弹出
	tw.tween_property($Container, "modulate", Color(1, 1, 1, 1), 0.25)
	tw.tween_property($Container, "scale", Vector2(1, 1), 0.35)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)

func _on_leave():
	# ── 退出动画：快速缩小淡出 ──
	var tw = create_tween().set_parallel(true)
	tw.tween_property($Overlay, "modulate", Color(1, 1, 1, 0), 0.15)
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
