class_name PlaybackBar
extends VBoxContainer
## 播放控制行：播放/暂停、重跑、静音、背景、命中框、速度档位
## 纯视图：只发信号不碰状态；状态由 Workbench 主控制器持有并同步回来

signal play_toggled
signal restart_requested
signal mute_toggled(on: bool)
signal bg_toggled(on: bool)
signal hitbox_toggled(on: bool)
signal speed_selected(idx: int)

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

var _play_btn: Button


func _init() -> void:
	add_theme_constant_override("separation", 4)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)

	grid.add_child(WorkbenchUI.label("播放"))
	_play_btn = Button.new()
	_play_btn.text = "⏸ 暂停"
	_play_btn.pressed.connect(func(): play_toggled.emit())
	grid.add_child(_play_btn)

	grid.add_child(WorkbenchUI.label("重跑"))
	var restart := Button.new()
	restart.text = "↺ 重跑"
	restart.pressed.connect(func(): restart_requested.emit())
	grid.add_child(restart)

	var mute := CheckButton.new()
	mute.text = "静音"
	mute.toggled.connect(func(on: bool): mute_toggled.emit(on))
	grid.add_child(mute)

	var bg := CheckButton.new()
	bg.text = "背景"
	bg.button_pressed = true
	bg.toggled.connect(func(on: bool): bg_toggled.emit(on))
	grid.add_child(bg)

	var hb := CheckButton.new()
	hb.text = "命中框"
	hb.toggled.connect(func(on: bool): hitbox_toggled.emit(on))
	grid.add_child(hb)

	var speed := OptionButton.new()
	for s in SPEEDS:
		speed.add_item("×" + str(s))
	speed.selected = 2
	speed.item_selected.connect(func(idx: int): speed_selected.emit(idx))
	grid.add_child(speed)


## 播放状态同步（主控制器调用：按钮文字跟随）
func set_playing(playing: bool) -> void:
	_play_btn.text = "⏸ 暂停" if playing else "▶ 播放"
