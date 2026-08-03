class_name StatusBar
extends VBoxContainer
## 实时状态：当前时间 + 子弹/敌人/Boss/FPS
## 纯显示：主控制器每帧调用 set_time / set_status

var _time_label: Label
var _status_label: Label


func _init() -> void:
	add_theme_constant_override("separation", 4)
	add_child(WorkbenchUI.section_title("── 状态 ──"))
	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 16)
	add_child(_time_label)
	_status_label = Label.new()
	add_child(_status_label)


func set_time(t: float, is_ff: bool) -> void:
	_time_label.text = "t = %.1f s%s" % [t, " ⏩" if is_ff else ""]


func set_status(bullets: int, enemies: int, boss_alive: bool, fps: int) -> void:
	_status_label.text = "子弹: %d\n敌人: %d\nBoss: %s\nFPS: %d" % [
		bullets, enemies, "存活" if boss_alive else "—", fps]
