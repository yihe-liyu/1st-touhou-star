extends BaseMenu
class_name MainMenu

@onready var _menu_host: MenuHost = $MenuHost
@onready var _logo: TextureRect = $logo
@onready var _container: Control = $Container


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


# ═══ 打开子菜单 ═══

func _open_difficulty() -> void:
	_deactivate_title()
	var screen := _menu_host.push("res://scenes/ui/difficulty_screen.tscn")
	screen.finished.connect(_on_difficulty_finished)


func _on_difficulty_finished(result: Dictionary) -> void:
	var diff: int = result.get("difficulty", 1)
	GameState.selected_difficulty = diff
	# TODO: 打开角色选择
	_activate_title()


# ═══ 标题菜单 停用/恢复 ═══

func _deactivate_title() -> void:
	input_enabled = false
	_container.visible = false
	_stop_pulse()


func _activate_title() -> void:
	_container.visible = true
	input_enabled = true
	if current_index >= 0 and current_index < menu_items.size():
		_start_pulse(menu_items[current_index])
