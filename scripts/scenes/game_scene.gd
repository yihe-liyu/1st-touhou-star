extends Node
class_name GameScene

const END_MENU = preload("res://scenes/ui/end_menu.tscn")

@export var level_data: LevelData

func _ready():
	if level_data:
		LevelManager.load_stage(level_data)

	if not GameEvents.player_death.is_connected(_on_player_death):
		GameEvents.player_death.connect(_on_player_death)
	#if not LevelManager.stage_cleared.is_connected(_on_stage_cleared):
		#LevelManager.stage_cleared.connect(_on_stage_cleared)

func _exit_tree():
	LevelManager.stop_stage()

func _on_player_death():
	await get_tree().create_timer(2.0).timeout
	var menu = END_MENU.instantiate()
	menu.title_text = "Game Over"
	GameManager.push_overlay_menu(menu)

#func _on_stage_cleared():
	#await get_tree().create_timer(2.0).timeout
	#var menu = END_MENU.instantiate()
	#menu.title_text = "Stage Clear!"
	#GameManager.push_overlay_menu(menu)
