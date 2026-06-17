extends MenuScreen
class_name CharacterScreen
## 角色选择界面 —— ←→ 选角色，Z 确认，X 返回

@export var characters: Array[String] = ["Reimu", "Marisa"]
var _labels: Array[Label] = []
var _index: int = 0
var _ready_to_input: bool = false


func _on_enter() -> void:
	var container := $HBoxContainer
	_labels.clear()
	for child in container.get_children():
		if child is Label:
			_labels.append(child)
	
	# 恢复上次选择的角色
	_index = clampi(GameState.selected_character, 0, _labels.size() - 1)
	_highlight_items(_labels, _index)
	_start_pulse(_labels[_index])
	# 渐显
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	
	$Overlay.modulate.a = 1.0
	container.modulate.a = 1.0
	
	var diff_names := ["Easy", "Normal", "Hard", "Lunatic"]
	$DifficultyBadge.text = diff_names[GameState.selected_difficulty] + " 难度"
	
	_ready_to_input = true


func _on_leave() -> void:
	_ready_to_input = false
	_stop_pulse()
	queue_free()

func leave() -> void:
	_ready_to_input = false
	_stop_pulse()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func ():
		finished.emit({})
		queue_free()
	)


func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event.is_action_pressed("ui_left"):
		_index = wrapi(_index - 1, 0, _labels.size())
		_highlight_items(_labels, _index)
		_start_pulse(_labels[_index])
		sfx_nav()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_index = wrapi(_index + 1, 0, _labels.size())
		_highlight_items(_labels, _index)
		_start_pulse(_labels[_index])
		sfx_nav()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		sfx_confirm()
		done({"character": _index})
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		sfx_back()
		leave()
		get_viewport().set_input_as_handled()
