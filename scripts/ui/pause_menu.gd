extends BaseMenu
class_name PauseMenu

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
