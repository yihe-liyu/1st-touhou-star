extends BaseMenu
class_name MainMenu

@onready var _logo: TextureRect = $logo
@onready var _title_container: Control = $Container


func _on_ready():
	GameManager.current_scene_path = "res://scenes/ui/main_menu.tscn"
	GameManager.push_menu(self)

	$Container/Label1.set_meta("locked", true)

	# Logo 入场动画
	_logo.material.set_shader_parameter("progress", 0.0)
	var tw = create_tween()
	tw.tween_property(_logo.material, "shader_parameter/progress", 1.0, 4.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_play_entrance_animation)


func _on_item_selected(index: int):
	match index:
		0:
			_open_difficulty()
		8:
			get_tree().quit()


func _on_back():
	get_tree().quit()


# ═══ 标题菜单 停用/恢复 ═══

func _deactivate_title() -> void:
	input_enabled = false
	_stop_pulse()
	for i in menu_items.size():
		menu_items[i].modulate = highlight_color if i == current_index else normal_color
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title_container, "modulate:a", 0.0, 0.25)
	tw.tween_property(_logo.material, "shader_parameter/alpha_mult", 0.0, 0.25)
	tw.tween_callback(_title_container.hide).set_delay(0.25)
	tw.tween_callback(_logo.hide).set_delay(0.25)


func _activate_title() -> void:
	_title_container.show()
	_logo.show()
	_title_container.modulate.a = 0.0
	_logo.material.set_shader_parameter("alpha_mult", 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_title_container, "modulate:a", 1.0, 0.25)
	tw.tween_property(_logo.material, "shader_parameter/alpha_mult", 1.0, 0.25)
	tw.tween_callback(func():
		refresh_colors()
		input_enabled = true
		if current_index >= 0 and current_index < menu_items.size():
			_start_pulse(menu_items[current_index])
	).set_delay(0.25)


func _open_difficulty() -> void:
	_deactivate_title()
	var screen: Node = $MenuHost.push("res://scenes/ui/difficulty_screen.tscn")
	screen.finished.connect(_on_difficulty_finished)


func _on_difficulty_finished(result: Dictionary) -> void:
	GameState.selected_difficulty = result.get("difficulty", 1)
	# TODO: 打开角色选择
	# 等难度面板退场动画播完 + 同帧 X 键过期，再恢复标题菜单
	get_tree().create_timer(0.25).timeout.connect(func(): _activate_title())
