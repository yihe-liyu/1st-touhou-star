extends Node
class_name GameScene

const END_MENU = preload("res://scenes/ui/end_menu.tscn")
const GAME_OVER_MENU = preload("res://scenes/ui/game_over_menu.tscn")

@onready var _sub_viewport: SubViewport = $Background/SubViewportContainer/SubViewport

@export var stage_data: StageData

var _blur_rect: ColorRect
var _background_instance: StageBackground
var _practice_runner: CoroutineRunner

func _ready():
	# 尽早进入 PLAYING，入场动画期间也允许暂停
	GameManager._set_state(GameManager.AppState.PLAYING)
	
	# Item 池
	var item_pool: Node = load("res://scripts/item/item_pool.gd").new()
	item_pool.name = "ItemPool"
	$World.add_child(item_pool)
	
	_load_background()

	if not GameEvents.player_death.is_connected(_on_player_death):
		GameEvents.player_death.connect(_on_player_death)
	
	if not GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.connect(_on_game_state_changed)
	
	if not StageManager.stage_cleared.is_connected(_on_stage_cleared):
		StageManager.stage_cleared.connect(_on_stage_cleared)
	
	# 先重置数据再配自机
	if GameState.is_practice_mode:
		GameState.reset_practice()
	else:
		GameState.reset_all()
	
	_setup_player()
	
	# 等 UI 入场动画播完再开始关卡
	var ui := $"UI"
	if ui and ui.has_signal("entry_finished"):
		await ui.entry_finished
	
	if GameState.is_practice_mode:
		_start_practice_game()
	elif stage_data:
		StageManager.load_stage(stage_data)

func _load_background():
	if not stage_data or not stage_data.background_scene:
		return
	_background_instance = stage_data.background_scene.instantiate()
	StageManager.current_background = _background_instance  # 先设, add_child 触发 _ready 时可用
	_sub_viewport.add_child(_background_instance)

func _exit_tree():
	if _background_instance and is_instance_valid(_background_instance):
		_background_instance.queue_free()
		_background_instance = null
	if _practice_runner and is_instance_valid(_practice_runner):
		_practice_runner.stop()
		_practice_runner.queue_free()
		_practice_runner = null
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

func _on_stage_cleared():
	# TODO: 暂关闭, 调试完再启
	# if stage_data and stage_data.next_stage: ...
	pass


# ═══ 练习模式 ═══

func _start_practice_game() -> void:
	# 加载背景
	if GameState.practice_background:
		_background_instance = GameState.practice_background.instantiate()
		StageManager.current_background = _background_instance
		_sub_viewport.add_child(_background_instance)
	
	# 创建 Runner + API
	_practice_runner = CoroutineRunner.new()
	_practice_runner.name = "PracticeRunner"
	add_child(_practice_runner)
	_practice_runner.run(func(): return true)  # 保持 running
	
	var api := StageAPI.new(_practice_runner)
	
	# 拼单-phase BossData
	var full_data: BossData = GameState.practice_boss_data
	var single := BossData.new()
	single.boss_name = full_data.boss_name
	single.visual = full_data.visual
	single.score_value = full_data.score_value
	single.phases = [full_data.phases[GameState.practice_phase_index]]
	
	# 生成 Boss
	var pos := Vector2(448, 240)
	StageManager.spawn_boss(single, pos, api)
	
	if not GameEvents.boss_defeated.is_connected(_on_practice_cleared):
		GameEvents.boss_defeated.connect(_on_practice_cleared)

func _on_practice_cleared(_boss: Node) -> void:
	if _practice_runner:
		_practice_runner.stop()
		_practice_runner.queue_free()
		_practice_runner = null
	
	if GameEvents.boss_defeated.is_connected(_on_practice_cleared):
		GameEvents.boss_defeated.disconnect(_on_practice_cleared)
	
	GameState.end_practice()
	
	# 回 menu
	GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
