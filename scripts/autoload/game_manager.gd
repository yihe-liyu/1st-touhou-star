extends Node

enum AppState {MENU, PLAYING, PAUSED, TRANSITIONING}

## 游戏状态变化信号 (old_state, new_state)
signal game_state_changed(old_state: int, new_state: int)
## 场景切换信号：进入新场景
signal scene_entered(scene_path: String)
## 场景切换信号：离开旧场景
signal scene_left(scene_path: String)

const FADE_DURATION: float = 0.4
const PAUSE_MENU_SCENE: String = "res://scenes/ui/pause_menu.tscn"

var current_scene_path: String = ""
var previous_scene_path: String = ""
var current_state: AppState = AppState.MENU
var _menu_stack: Array = []
var _transition_layer: CanvasLayer
var _transition_rect: ColorRect
var _pause_menu_instance = null
var _overlay_menu_stack: Array = []

func _ready():
	_ensure_input_actions()
	_setup_transition()
	process_mode = PROCESS_MODE_ALWAYS

func _process(_delta):
	if current_state == AppState.TRANSITIONING:
		return
	if _pause_menu_instance or not _overlay_menu_stack.is_empty():
		return
	if current_state == AppState.PLAYING:
		if Input.is_action_just_pressed("ui_pause"):
			pause_game()

func _ensure_input_actions():
	_add_keys_to_action("ui_accept", [KEY_Z, KEY_ENTER, KEY_SPACE])
	_add_keys_to_action("ui_cancel", [KEY_X, KEY_ESCAPE])
	_add_keys_to_action("ui_pause", [KEY_ESCAPE])
	_add_keys_to_action("ui_up", [KEY_UP, KEY_W])
	_add_keys_to_action("ui_down", [KEY_DOWN, KEY_S])
	_add_keys_to_action("ui_left", [KEY_LEFT, KEY_A])
	_add_keys_to_action("ui_right", [KEY_RIGHT, KEY_D])

func _add_keys_to_action(action_name: String, keycodes: Array):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keycodes:
		var already = false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey and (event.keycode == keycode or event.physical_keycode == keycode):
				already = true
				break
		if already:
			continue
		var event = InputEventKey.new()
		event.keycode = keycode
		InputMap.action_add_event(action_name, event)

func _setup_transition():
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 128
	_transition_layer.process_mode = PROCESS_MODE_ALWAYS
	add_child(_transition_layer)

	_transition_rect = ColorRect.new()
	_transition_rect.color = Color.BLACK
	_transition_rect.modulate.a = 0.0
	_transition_rect.visible = false
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_transition_layer.add_child(_transition_rect)

func _set_state(new_state: AppState):
	var old = current_state
	if old == new_state:
		return
	current_state = new_state
	game_state_changed.emit(old, new_state)

func _input(_event: InputEvent):
	if _pause_menu_instance or not _menu_stack.is_empty() or not _overlay_menu_stack.is_empty():
		get_viewport().set_input_as_handled()

func is_paused() -> bool:
	return current_state == AppState.PAUSED

# ── 场景切换 ──

func change_scene(path: String, target_state: AppState = AppState.PLAYING):
	if current_state == AppState.TRANSITIONING:
		return

	_set_state(AppState.TRANSITIONING)
	get_tree().paused = true

	clear_menus()
	_cleanup_pause()

	if current_scene_path != "":
		scene_left.emit(current_scene_path)

	await _fade_out()

	BulletManager.clear_all()
	GameState.clear_enemies()

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	previous_scene_path = current_scene_path
	current_scene_path = path

	await _fade_in()

	get_tree().paused = false
	_set_state(target_state)
	scene_entered.emit(current_scene_path)

func reload_current_scene():
	if current_scene_path != "":
		change_scene(current_scene_path)

# ── 菜单栈 ──

func push_menu(menu):
	_menu_stack.append(menu)
	if menu.has_method("_on_enter"):
		menu._on_enter()

func pop_menu():
	if _menu_stack.is_empty():
		return null
	var menu = _menu_stack.pop_back()
	if is_instance_valid(menu) and menu.has_method("_on_leave"):
		menu._on_leave()
	return menu

func clear_menus():
	while not _menu_stack.is_empty():
		pop_menu()

func push_overlay_menu(menu: CanvasLayer):
	_overlay_menu_stack.append(menu)
	_set_state(AppState.PAUSED)
	get_tree().paused = true
	menu.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(menu)

func pop_overlay_menu(menu: CanvasLayer):
	_overlay_menu_stack.erase(menu)
	if is_instance_valid(menu):
		menu.queue_free()
	if _overlay_menu_stack.is_empty():
		_set_state(AppState.PLAYING)
		get_tree().paused = false

# ── 暂停 / 恢复 ──

func pause_game():
	if current_state != AppState.PLAYING:
		return

	if not ResourceLoader.exists(PAUSE_MENU_SCENE):
		push_error("GameManager: pause_menu.tscn 不存在: " + PAUSE_MENU_SCENE)
		return

	_set_state(AppState.PAUSED)

	var scene = load(PAUSE_MENU_SCENE)
	_pause_menu_instance = scene.instantiate()
	_pause_menu_instance.process_mode = PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_pause_menu_instance)

	get_tree().paused = true

func resume_game():
	if current_state != AppState.PAUSED:
		return

	if _pause_menu_instance:
		if _pause_menu_instance.has_method("_on_leave"):
			_pause_menu_instance._on_leave()
		else:
			_pause_menu_instance.queue_free()
		_pause_menu_instance = null

	get_tree().paused = false
	_set_state(AppState.PLAYING)

func toggle_pause():
	if current_state == AppState.PAUSED:
		resume_game()
	elif current_state == AppState.PLAYING:
		pause_game()

func _cleanup_pause():
	if _pause_menu_instance:
		if is_instance_valid(_pause_menu_instance):
			_pause_menu_instance.queue_free()
		_pause_menu_instance = null
	if current_state == AppState.PAUSED:
		get_tree().paused = false
		_set_state(AppState.PLAYING)

# ── 黑场过渡 ──

func _fade_out(duration: float = FADE_DURATION):
	_transition_rect.modulate.a = 0.0
	_transition_rect.visible = true
	var tween = _transition_rect.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_transition_rect, "modulate:a", 1.0, duration)
	await tween.finished

func _fade_in(duration: float = FADE_DURATION):
	_transition_rect.modulate.a = 1.0
	var tween = _transition_rect.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_transition_rect, "modulate:a", 0.0, duration)
	await tween.finished
	_transition_rect.visible = false

