extends MenuScreen
class_name DifficultyScreen

@export var options: Array[String] = ["Easy", "Normal", "Hard", "Lunatic"]
var _labels: Array[Label] = []
var _index: int = 1
var _ready_to_input: bool = false


func _on_enter() -> void:
	var oc := $Container as VBoxContainer
	if not oc:
		return
	_labels.clear()
	for child in oc.get_children():
		if child is Label:
			_labels.append(child)
	_index = clampi(GameState.selected_difficulty, 0, _labels.size() - 1)
	_refresh()
	# 全不透明，无入口动画（黑幕淡出过渡已提供视觉平滑）
	modulate.a = 1.0
	_ready_to_input = true


func _on_leave() -> void:
	_ready_to_input = false
	queue_free()


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].modulate = Color.WHITE if i == _index else Color(0.4, 0.4, 0.4, 1.0)


func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event.is_action_pressed("ui_up"):
		_index = wrapi(_index - 1, 0, _labels.size())
		_refresh()
		sfx_nav()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_index = wrapi(_index + 1, 0, _labels.size())
		_refresh()
		sfx_nav()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		sfx_confirm()
		done({"difficulty": _index})
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		sfx_back()
		leave()
		get_viewport().set_input_as_handled()
