extends BaseMenu
class_name EndMenu

@export var title_label: Label
@export var title_text: String = "Stage Clear!"

func _on_ready():
	if title_label:
		title_label.text = title_text
	# Extra Stage 默认锁定
	$Panel/MenuContainer/ExtraStage.set_meta("locked", true)
	refresh_colors()

func _on_item_selected(index: int):
	match index:
		0:
			GameManager.pop_overlay_menu(self)
			GameManager.reload_current_scene()
		1:
			GameManager.pop_overlay_menu(self)
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		2:
			# Extra Stage（暂未实现）
			GameManager.pop_overlay_menu(self)
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)

func _on_back():
	_on_item_selected(1)
