# GameManager.gd (Autoload) — 游戏状态机 + 模块门面
extends Node

enum AppState {MENU, PLAYING, PAUSED, TRANSITIONING}

signal game_state_changed(old_state: int, new_state: int)
signal scene_entered(scene_path: String)
signal scene_left(scene_path: String)

# ═══ 模块 ───
const TransClass = preload("res://scripts/autoload/game/scene_transition.gd")
const MenuClass = preload("res://scripts/autoload/game/menu_stack.gd")
const PauseClass = preload("res://scripts/autoload/game/pause_control.gd")

var _transition
var _menus
var _pause_control

# ═══ 状态 ═══
var current_scene_path: String = ""
var previous_scene_path: String = ""
var current_state: AppState = AppState.MENU


func _ready():
	_ensure_input_actions()
	process_mode = PROCESS_MODE_ALWAYS

	_transition = TransClass.new()
	_transition.setup(self)

	_menus = MenuClass.new()
	_menus.setup(self, _set_state)

	_pause_control = PauseClass.new()
	_pause_control.setup(self, _set_state)


func _process(_delta):
	if current_state == AppState.TRANSITIONING:
		return
	if _pause_control.has_instance() or _menus.is_overlay_open():
		return
	if current_state == AppState.PLAYING:
		if Input.is_action_just_pressed("ui_pause"):
			_pause_control.pause()


func _input(_event: InputEvent):
	if _pause_control.has_instance() or _menus.is_menu_open() or _menus.is_overlay_open():
		get_viewport().set_input_as_handled()


# ═══ 状态 ═══

func _set_state(new_state: AppState):
	var old = current_state
	if old == new_state:
		return
	current_state = new_state
	game_state_changed.emit(old, new_state)

func is_paused() -> bool:
	return current_state == AppState.PAUSED


# ═══ 场景切换 ═══

func change_scene(path: String, target_state: AppState = AppState.PLAYING):
	if current_state == AppState.TRANSITIONING:
		return

	_set_state(AppState.TRANSITIONING)

	_menus.clear()
	_pause_control.cleanup()

	var new_path = await _transition.change_scene(path, current_scene_path, scene_left.emit, scene_entered.emit)
	previous_scene_path = current_scene_path
	current_scene_path = new_path

	_set_state(target_state)
	scene_entered.emit(current_scene_path)


func reload_current_scene():
	if current_scene_path != "":
		change_scene(current_scene_path)


# ═══ 菜单栈 ═══

func push_menu(menu):
	_menus.push(menu)

func pop_menu():
	return _menus.pop()

func clear_menus():
	_menus.clear()

func push_overlay_menu(menu: CanvasLayer):
	_menus.push_overlay(menu)

func pop_overlay_menu(menu: CanvasLayer):
	_menus.pop_overlay(menu)


# ═══ 暂停 / 恢复 ═══

func pause_game():
	if current_state != AppState.PLAYING:
		return
	_pause_control.pause()

func resume_game():
	if current_state != AppState.PAUSED:
		return
	_pause_control.resume()

func toggle_pause():
	if current_state == AppState.PAUSED:
		resume_game()
	elif current_state == AppState.PLAYING:
		pause_game()


# ═══ 输入 ═══

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
