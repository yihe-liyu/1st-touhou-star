extends MenuScreen
class_name DifficultyScreen
## 难度选择界面 —— ↑↓ 选难度，Z 确认，X 返回

@export var options: Array[String] = ["Easy", "Normal", "Hard", "Lunatic"]
var _labels: Array[Label] = []
var _index: int = 1  # 默认 Normal
var _ready_to_input: bool = false


func _on_enter() -> void:
	# 收集标签
	var oc := $Container as VBoxContainer
	_labels.clear()
	for child in oc.get_children():
		if child is Label:
			_labels.append(child)
	
	# 恢复上次选择的难度
	_index = clampi(GameState.selected_difficulty, 0, _labels.size() - 1)
	_refresh()
	
	# 入场动画：淡入
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _ready_to_input = true)


func _on_leave() -> void:
	_ready_to_input = false
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	tw.tween_callback(queue_free)


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].modulate = Color.WHITE if i == _index else Color(0.4, 0.4, 0.4, 1.0)


func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_index = wrapi(_index - 1, 0, _labels.size())
				_refresh()
				sfx_nav()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_index = wrapi(_index + 1, 0, _labels.size())
				_refresh()
				sfx_nav()
				get_viewport().set_input_as_handled()
			KEY_Z, KEY_ENTER, KEY_SPACE:
				sfx_confirm()
				done({"difficulty": _index})
				get_viewport().set_input_as_handled()
			KEY_X, KEY_ESCAPE:
				sfx_back()
				leave()
				get_viewport().set_input_as_handled()
