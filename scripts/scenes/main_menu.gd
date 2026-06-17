extends BaseMenu
class_name MainMenu

@onready var _logo: TextureRect = $logo


func _on_ready():
	GameManager.current_scene_path = "res://scenes/ui/main_menu.tscn"

	$Container/Label1.set_meta("locked", true)
	if GameState.spell_book.records.is_empty():
		$Container/Label3.set_meta("locked", true)
	
	AudioManager.play_bgm(preload("res://assets/Music/THq01_01.无缘故之回.mp3"), 1.0)

	_logo.material.set_shader_parameter("progress", 0.0)
	_logo.material.set_shader_parameter("alpha_mult", 1.0)
	var tw = create_tween()
	tw.tween_property(_logo.material, "shader_parameter/progress", 1.0, 4.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_play_entrance_animation)


func _on_item_selected(index: int):
	match index:
		0: _open_difficulty()
		2: _open_sub("res://scenes/ui/stage_practice_menu.tscn")
		3: _open_sub("res://scenes/ui/spell_practice_menu.tscn")
		4: _open_sub("res://scenes/ui/replay_menu.tscn")
		5: _open_sub("res://scenes/ui/player_data_menu.tscn")
		6: _open_sub("res://scenes/ui/music_room_menu.tscn")
		7: _open_sub("res://scenes/ui/option_menu.tscn")
		8: _open_sub("res://scenes/ui/manual_menu.tscn")
		9: get_tree().quit()


# ═══ 子页面（统一模式：推入 → 等结果 → 页面自动清理） ═══

## 简单子页：推入，等用户按 X 返回（页面自动清理自身）
func _open_sub(path: String) -> void:
	input_enabled = false
	GameManager.push_page(path)
	await GameManager.page_result  # 页面调 leave() → 自动清理
	input_enabled = true
	refresh_colors()
	if current_index >= 0: _start_pulse(menu_items[current_index])


# ═══ 难度 → 角色 ═══

func _open_difficulty() -> void:
	input_enabled = false
	GameManager.push_page("res://scenes/ui/difficulty_screen.tscn")
	var r: Dictionary = await GameManager.page_result
	if not r.has("difficulty"):
		_restore()
		return
	GameState.selected_difficulty = r.difficulty
	_go_character()


func _go_character() -> void:
	GameManager.push_page("res://scenes/ui/character_screen.tscn")
	var r: Dictionary = await GameManager.page_result
	if not r.has("character"):
		_open_difficulty()
		return
	GameState.selected_character = r.character
	AudioManager.stop_bgm()
	# 子页面在 change_scene 时被 clear_pages 清理
	GameManager.change_scene("res://scenes/game_scene.tscn")


func _restore() -> void:
	input_enabled = true
	refresh_colors()
	if current_index >= 0: _start_pulse(menu_items[current_index])
