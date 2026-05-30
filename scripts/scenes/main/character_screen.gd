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
	
	_refresh()
	
	# 入场动画
	$Overlay.modulate.a = 0.0
	container.position.y += 40.0
	container.modulate.a = 0.0
	
	# 显示难度信息
	var diff_names := ["Easy", "Normal", "Hard", "Lunatic"]
	$DifficultyBadge.text = diff_names[GameState.selected_difficulty] + " 难度"
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property($Overlay, "modulate:a", 1.0, 0.3)
	tw.tween_property(container, "position:y", container.position.y - 40.0, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(container, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _ready_to_input = true).set_delay(0.3)


func _on_leave() -> void:
	_ready_to_input = false
	var container := $HBoxContainer
	var tw := create_tween().set_parallel(true)
	tw.tween_property($Overlay, "modulate:a", 0.0, 0.2)
	tw.tween_property(container, "position:y", container.position.y + 30.0, 0.2)
	tw.tween_property(container, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free).set_delay(0.25)


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].modulate = Color.WHITE if i == _index else Color(0.4, 0.4, 0.4, 1.0)


func _input(event: InputEvent) -> void:
	if not _ready_to_input:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				_index = wrapi(_index - 1, 0, _labels.size())
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_index = wrapi(_index + 1, 0, _labels.size())
				_refresh()
				get_viewport().set_input_as_handled()
			KEY_Z, KEY_ENTER, KEY_SPACE:
				done({"character": _index})
				get_viewport().set_input_as_handled()
			KEY_X, KEY_ESCAPE:
				leave()
				get_viewport().set_input_as_handled()
