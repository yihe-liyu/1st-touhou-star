# PauseControl — 暂停/恢复管理
class_name PauseControl
extends RefCounted

const PAUSE_MENU_SCENE: String = "res://scenes/ui/pause_menu.tscn"

var _on_state_changed: Callable
var _instance = null


func setup(on_state_changed: Callable) -> void:
	_on_state_changed = on_state_changed


func pause() -> void:
	if not ResourceLoader.exists(PAUSE_MENU_SCENE):
		push_error("PauseControl: pause_menu.tscn 不存在: " + PAUSE_MENU_SCENE)
		return

	_on_state_changed.call(GameManager.AppState.PAUSED)

	var scene = load(PAUSE_MENU_SCENE)
	_instance = scene.instantiate()
	_instance.process_mode = Node.PROCESS_MODE_ALWAYS
	_instance.get_tree().root.add_child(_instance)
	_instance.get_tree().paused = true


func resume() -> void:
	if _instance:
		if _instance.has_method("_on_leave"):
			_instance._on_leave()
		else:
			_instance.queue_free()
		_instance = null

	_instance.get_tree().paused = false
	_on_state_changed.call(GameManager.AppState.PLAYING)


func has_instance() -> bool:
	return _instance != null


func cleanup() -> void:
	if _instance:
		if is_instance_valid(_instance):
			_instance.queue_free()
		_instance = null
