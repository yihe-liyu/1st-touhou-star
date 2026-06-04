extends Node
class_name GameScene

const END_MENU = preload("res://scenes/ui/end_menu.tscn")
const GAME_OVER_MENU = preload("res://scenes/ui/game_over_menu.tscn")

@onready var _sub_viewport: SubViewport = $Background/SubViewportContainer/SubViewport

@export var stage_data: StageData

var _blur_rect: ColorRect
var _background_instance: StageBackground

func _ready():
	# 尽早进入 PLAYING，入场动画期间也允许暂停
	GameManager._set_state(GameManager.AppState.PLAYING)
	
	_load_background()

	if not GameEvents.player_death.is_connected(_on_player_death):
		GameEvents.player_death.connect(_on_player_death)
	
	if not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)
	
	_setup_player()
	
	# 等 UI 入场动画播完再开始关卡（暂停时动画冻住，恢复后继续）
	var ui := $"UI"
	if ui and ui.has_signal("entry_finished"):
		await ui.entry_finished
	
	if stage_data:
		StageManager.load_stage(stage_data)

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
	var menu = GAME_OVER_MENU.instantiate()
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
	var vs := get_viewport().get_visible_rect().size
	
	_blur_rect = ColorRect.new()
	_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/pause_blur.gdshader")
	mat.set_shader_parameter("rect_min", Vector2(svc.position) / vs)
	mat.set_shader_parameter("rect_max", Vector2(svc.position + svc.size) / vs)
	_blur_rect.material = mat
	
	var blur_layer := CanvasLayer.new()
	blur_layer.layer = 15
	blur_layer.name = "BlurLayer"
	blur_layer.add_child(_blur_rect)
	add_child(blur_layer)


func _remove_blur() -> void:
	if _blur_rect:
		var layer := _blur_rect.get_parent()
		_blur_rect.queue_free()
		_blur_rect = null
		if layer and layer.name == "BlurLayer":
			layer.queue_free()


func _setup_player() -> void:
	var data_map := [
		preload("res://data/player_data/reimu_data.tres"),
		preload("res://data/player_data/marisa_data.tres"),
	]
	var player := $World/Player
	if player and GameState.selected_character < data_map.size():
		player.player_data = data_map[GameState.selected_character]
		player._apply_player_data()
		player._reinit_shoot()
