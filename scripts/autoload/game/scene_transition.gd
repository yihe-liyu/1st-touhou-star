# SceneTransition — 场景切换 + 黑场过渡
class_name SceneTransition
extends RefCounted

const FADE_DURATION: float = 0.4

var _parent: Node
var _transition_rect: ColorRect


func setup(parent: Node) -> void:
	_parent = parent
	_setup_transition()


func _setup_transition() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_parent.add_child(layer)

	_transition_rect = ColorRect.new()
	_transition_rect.color = Color.BLACK
	_transition_rect.modulate.a = 0.0
	_transition_rect.visible = false
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_transition_rect)


func change_scene(path: String, current_scene_path: String, on_scene_left: Callable, on_scene_entered: Callable) -> String:
	BulletManager.pause_processing()
	_parent.get_tree().paused = true

	if current_scene_path != "":
		on_scene_left.call(current_scene_path)

	await _fade_out()

	BulletManager.clear_all()
	GameState.clear_enemies()

	_parent.get_tree().change_scene_to_file(path)
	await _parent.get_tree().process_frame

	await _fade_in()

	_parent.get_tree().paused = false
	BulletManager.resume_processing()

	return path


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
