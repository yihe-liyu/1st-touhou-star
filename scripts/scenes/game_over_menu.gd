extends BaseMenu
class_name GameOverMenu

@export var title_label: Label
@export var title_text: String = "Game Over"


func _on_ready():
	# Overlay 淡入（和 pause_menu 一致）
	$Overlay.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property($Overlay, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if title_label:
		title_label.text = title_text


func _on_leave():
	var tw = create_tween().set_parallel(true)
	tw.tween_property($Overlay, "modulate:a", 0.0, 0.15)
	tw.tween_property($Container, "modulate", Color(1, 1, 1, 0), 0.12)
	tw.tween_property($Container, "scale", Vector2(0.95, 0.95), 0.12)
	tw.tween_callback(queue_free)


func _on_item_selected(index: int):
	match index:
		0:
			GameManager.pop_overlay_menu(self)
			GameManager.reload_current_scene()
		1:
			GameManager.pop_overlay_menu(self)
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_back():
	_on_item_selected(1)
