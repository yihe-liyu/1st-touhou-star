extends Node
class_name GameScene

const END_MENU = preload("res://scenes/ui/end_menu.tscn")

@onready var _sub_viewport: SubViewport = $Background/SubViewportContainer/SubViewport

@export var stage_data: StageData

var _blur_rect: ColorRect
var _background_instance: StageBackground

func _ready():
	# 直接运行此场景时确保状态正确（因没经过 change_scene）
	if GameManager.current_state != GameManager.AppState.PLAYING:
		GameManager._set_state(GameManager.AppState.PLAYING)

	_load_background()

	if stage_data:
		StageManager.load_stage(stage_data)

	if not GameEvents.player_death.is_connected(_on_player_death):
		GameEvents.player_death.connect(_on_player_death)
	
	# 暂停时给 SubViewport 加模糊，UI 层保持清晰
	if not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)

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


func _on_game_state_changed(_old: int, new: int) -> void:
	if new == GameManager.AppState.PAUSED:
		_add_blur()
	elif _old == GameManager.AppState.PAUSED:
		_remove_blur()


func _add_blur() -> void:
	if _blur_rect:
		return
	var svc := $Background/SubViewportContainer
	
	_blur_rect = ColorRect.new()
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_rect.position = svc.position
	_blur_rect.size = svc.size
	
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/pause_blur.gdshader")
	_blur_rect.material = mat
	
	$Background.add_child(_blur_rect)


func _remove_blur() -> void:
	if _blur_rect:
		_blur_rect.queue_free()
		_blur_rect = null

#func _on_stage_cleared():
	#await get_tree().create_timer(2.0).timeout
	#var menu = END_MENU.instantiate()
	#menu.title_text = "Stage Clear!"
	#GameManager.push_overlay_menu(menu)
