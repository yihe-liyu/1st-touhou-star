extends Node
class_name GameScene

const END_MENU = preload("res://scenes/ui/end_menu.tscn")

@export var stage_data: StageData

func _ready():
	if stage_data:
		StageManager.load_stage(stage_data)
		if stage_data.background_data:
			$StageBackground.load_preset(stage_data.background_data)

	if not GameEvents.player_death.is_connected(_on_player_death):
		GameEvents.player_death.connect(_on_player_death)
	#if not StageManager.stage_cleared.is_connected(_on_stage_cleared):
		#StageManager.stage_cleared.connect(_on_stage_cleared)

func _exit_tree():
	StageManager.stop_stage()

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
