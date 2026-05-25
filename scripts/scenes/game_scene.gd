extends Node
class_name GameScene

const END_MENU = preload("res://scenes/ui/end_menu.tscn")

@onready var _sub_viewport: SubViewport = $Background/SubViewportContainer/SubViewport

@export var stage_data: StageData

var _background_instance: StageBackground

func _ready():
	_load_background()

	if stage_data:
		StageManager.load_stage(stage_data)

	if not GameEvents.player_death.is_connected(_on_player_death):
		GameEvents.player_death.connect(_on_player_death)

func _load_background():
	if not stage_data or not stage_data.background_scene:
		return
	_background_instance = stage_data.background_scene.instantiate()
	_sub_viewport.add_child(_background_instance)

func _exit_tree():
	if _background_instance and is_instance_valid(_background_instance):
		_background_instance.queue_free()
		_background_instance = null
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
