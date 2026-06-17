# EndMenu.gd — 通关覆盖层
extends NavPage

@export var title_label: Label
@export var title_text: String = "Stage Clear!"


func _on_enter() -> void:
	super._on_enter()
	if title_label:
		title_label.text = title_text


func _on_leave() -> void:
	_nav_enabled = false
	_stop_pulse()
	queue_free()


func _on_item_selected(index: int) -> void:
	match index:
		0:
			GameManager.reload_current_scene()
		1:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	_on_item_selected(1)
