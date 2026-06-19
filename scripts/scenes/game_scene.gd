extends Node
class_name GameScene

const GAME_OVER_MENU = preload("res://scenes/ui/game_over_menu.tscn")

@onready var _sub_viewport: SubViewport = $Background/SubViewportContainer/SubViewport

var _blur_rect: ColorRect
var _background_instance: Node  # StageBackground 或测试 Node3D
var _practice_runner: CoroutineRunner


func _ready():
	GameManager._set_state(GameManager.AppState.PLAYING)

	var item_pool: Node = load("res://scripts/item/item_pool.gd").new()
	item_pool.name = "ItemPool"
	$World.add_child(item_pool)

	GameEvents.player_death.connect(_on_player_death)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	StageManager.stage_cleared.connect(_on_stage_cleared)

	if GameState.is_practice_mode:
		GameState.reset_practice()
		_setup_player()
		_start_practice_game()
	else:
		GameState.reset_all()
		_setup_player()
		_start_normal_game()


func _start_normal_game() -> void:
	var data := _resolve_stage_data()
	if not data:
		push_error("GameScene: 找不到关卡 stage_id=%d difficulty=%d" % [GameState.current_stage_id, GameState.selected_difficulty])
		return
	_load_background(data.background_scene)
	StageManager.load_stage(data)


func _start_practice_game() -> void:
	_load_background(GameState.practice_background)

	_practice_runner = CoroutineRunner.new()
	add_child(_practice_runner)
	_practice_runner.run(func(): return true)
	var ctx := StageContext.new(_practice_runner)

	var full_data: BossData = GameState.practice_boss_data
	var single := BossData.new()
	single.boss_name = full_data.boss_name
	single.visual = full_data.visual
	single.score_value = full_data.score_value
	single.phases = [full_data.phases[GameState.practice_phase_index]]

	StageManager.spawn_boss(single, Vector2(448, 240), false, ctx)
	GameEvents.boss_defeated.connect(_on_practice_cleared)


func _resolve_stage_data() -> StageData:
	if GameState.stage_registry:
		return GameState.stage_registry.find(GameState.current_stage_id, GameState.selected_difficulty)
	push_error("GameScene: stage_registry 未设置")
	return null


func _load_background(scene: PackedScene) -> void:
	if not scene: return
	if _background_instance:
		_background_instance.queue_free()
	_background_instance = scene.instantiate()
	if _background_instance is StageBackground:
		StageManager.current_background = _background_instance
	_sub_viewport.add_child(_background_instance)


func _exit_tree():
	BulletManager.clear_all()
	HitEffectPool.clear_all_pool()
	if _background_instance and is_instance_valid(_background_instance):
		_background_instance.queue_free()
		_background_instance = null
	if _practice_runner and is_instance_valid(_practice_runner):
		_practice_runner.stop()
		_practice_runner.queue_free()
		_practice_runner = null
	StageManager.stop_stage()


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


func _on_stage_cleared():
	if GameState.is_stage_practice:
		GameState.is_stage_practice = false
		GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
	elif not GameState.is_practice_mode:
		GameState.current_stage_id += 1
		GameManager.reload_current_scene()


func _on_practice_cleared(_boss: Node) -> void:
	if _practice_runner:
		_practice_runner.stop()
		_practice_runner.queue_free()
		_practice_runner = null
	GameEvents.boss_defeated.disconnect(_on_practice_cleared)
	GameState.end_practice()
	GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _add_blur() -> void:
	if _blur_rect: return
	var container := $Background/SubViewportContainer
	var vs := get_viewport().get_visible_rect().size
	_blur_rect = ColorRect.new()
	_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/pause_blur.gdshader")
	mat.set_shader_parameter("rect_min", Vector2(container.position) / vs)
	mat.set_shader_parameter("rect_max", Vector2(container.position + container.size) / vs)
	_blur_rect.material = mat
	var blur_layer := CanvasLayer.new()
	blur_layer.layer = 15
	blur_layer.name = "BlurLayer"
	blur_layer.add_child(_blur_rect)
	add_child(blur_layer)


func _remove_blur() -> void:
	if not _blur_rect: return
	var layer := _blur_rect.get_parent()
	_blur_rect.queue_free()
	_blur_rect = null
	if layer and layer.name == "BlurLayer":
		layer.queue_free()
