# GameOverMenu.gd — Game Over 覆盖层
extends NavPage

@export var title_label: Label
@export var title_text: String = "Game Over"


func _on_enter() -> void:
	super._on_enter()
	_fade_overlay_in(0.3)
	if title_label:
		title_label.text = title_text


func _on_leave() -> void:
	_nav_enabled = false
	_stop_pulse()
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_overlay_out(0.15)
	tw.tween_property(_container, "modulate", Color(1, 1, 1, 0), 0.12)
	tw.tween_property(_container, "scale", Vector2(0.95, 0.95), 0.12)
	tw.tween_callback(queue_free)


func _on_item_selected(index: int) -> void:
	match index:
		0:
			GameManager.reload_current_scene()
		1:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	_on_item_selected(1)
