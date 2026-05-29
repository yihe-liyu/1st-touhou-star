extends BaseMenu
class_name MainMenu

enum MenuState { TITLE, DIFFICULTY }
var _state: MenuState = MenuState.TITLE
var _diff_index: int = 1  # 默认 Normal
var _diff_options: Array[Label] = []


func _on_ready():
	GameManager.current_scene_path = "res://scenes/ui/main_menu.tscn"
	GameManager.push_menu(self)

	# Extra Start 默认锁定（入口动画会自动用 locked_color）
	$Container/Label1.set_meta("locked", true)

	# 收集难度选项
	var oc = $DifficultyPanel/OptionContainer
	for child in oc.get_children():
		if child is Label:
			_diff_options.append(child)
	_refresh_diff_highlight()

	# Logo 入场动画
	$logo.material.set_shader_parameter("progress", 0.0)

	var tw = create_tween()
	tw.tween_property($logo.material, "shader_parameter/progress", 1.0, 4.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tw.tween_callback(_play_entrance_animation)


# ═══ 标题菜单 ═══

func _on_item_selected(index: int):
	if _state != MenuState.TITLE:
		return
	match index:
		0:
			_show_difficulty_panel()
		8:
			get_tree().quit()

func _on_back():
	if _state == MenuState.DIFFICULTY:
		_hide_difficulty_panel()
		return
	get_tree().quit()


# ═══ 难度面板 ═══

func _process(delta: float) -> void:
	# 难度/角色面板打开时，屏蔽 BaseMenu 的标题菜单导航
	if _state != MenuState.TITLE:
		return
	super(delta)

func _show_difficulty_panel() -> void:
	_state = MenuState.DIFFICULTY
	input_enabled = false
	
	# 标题菜单项淡出
	var tw := create_tween().set_parallel(true)
	for item in menu_items:
		tw.tween_property(item, "modulate:a", 0.0, 0.25)
	tw.tween_property($logo, "modulate:a", 0.3, 0.25)
	
	# 难度面板淡入
	var panel := $DifficultyPanel
	panel.modulate.a = 0.0
	panel.visible = true
	tw.tween_property(panel, "modulate:a", 1.0, 0.3).set_delay(0.2)
	
	tw.tween_callback(func(): input_enabled = true).set_delay(0.3)


func _hide_difficulty_panel() -> void:
	input_enabled = false
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property($DifficultyPanel, "modulate:a", 0.0, 0.2)
	
	# 标题菜单项淡回
	for item in menu_items:
		tw.tween_property(item, "modulate:a", 1.0, 0.25).set_delay(0.15)
	tw.tween_property($logo, "modulate:a", 1.0, 0.25).set_delay(0.15)
	
	tw.tween_callback(func():
		$DifficultyPanel.visible = false
		_state = MenuState.TITLE
		input_enabled = true
	).set_delay(0.3)


func _refresh_diff_highlight() -> void:
	var bright := Color(1.0, 1.0, 1.0, 1.0)
	var dim := Color(0.4, 0.4, 0.4, 1.0)
	for i in _diff_options.size():
		_diff_options[i].modulate = bright if i == _diff_index else dim


func _diff_navigate(dir: int) -> void:
	if _diff_options.is_empty():
		return
	_diff_index = wrapi(_diff_index + dir, 0, _diff_options.size())
	_refresh_diff_highlight()


func _diff_confirm() -> void:
	GameState.selected_difficulty = _diff_index
	print("难度: ", _diff_options[_diff_index].text)
	# TODO: 过渡到角色选择
	_hide_difficulty_panel()


# ═══ 全局输入（难度模式） ═══

func _input(event: InputEvent) -> void:
	if _state != MenuState.DIFFICULTY:
		return
	if not input_enabled:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP:
				_diff_navigate(-1)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_diff_navigate(1)
				get_viewport().set_input_as_handled()
			KEY_Z, KEY_ENTER, KEY_SPACE:
				_diff_confirm()
				get_viewport().set_input_as_handled()
			KEY_X, KEY_ESCAPE:
				_hide_difficulty_panel()
				get_viewport().set_input_as_handled()
