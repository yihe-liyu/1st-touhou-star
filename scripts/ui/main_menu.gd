extends BaseMenu
class_name MainMenu

func _on_ready():
	GameManager.current_scene_path = "res://scenes/ui/main_menu.tscn"
	GameManager.push_menu(self)

func _on_item_selected(index: int):
	match index:
		0:
			GameManager.change_scene("res://scenes/game_scene.tscn")
		1:
			get_tree().quit()

func _on_back():
	get_tree().quit()
