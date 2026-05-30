extends Control
class_name MenuScreen
## 可被 MenuHost 推入栈的界面基类
## 子类覆写 _on_enter / _on_leave / _on_activate / _on_deactivate
##
## 退场标准流程:
##   _on_leave() → 播放动画 → finished.emit() (或 queue_free())

signal finished(result: Dictionary)

## 禁止：直接写结果（不弹栈）
func done(result: Dictionary = {}) -> void:
	finished.emit(result)

## 弹栈：退场动画后 pop
func leave() -> void:
	finished.emit({})


# ═══ 子类可覆写 ═══

## 首次进入（被 push 时调用一次）
func _on_enter() -> void:
	pass

## 被其他界面覆盖
func _on_deactivate() -> void:
	pass

## 覆盖的界面被移除，重新激活
func _on_activate() -> void:
	pass

## 被 pop 时调用 —— 应包含退场动画，动画结束后 queue_free()
func _on_leave() -> void:
	queue_free()


# ═══ 音效快捷 ═══

func sfx_nav() -> void:
	AudioManager.play_sfx(preload("res://assets/Sound/select.wav"))

func sfx_confirm() -> void:
	AudioManager.play_sfx(preload("res://assets/Sound/ok.wav"))

func sfx_back() -> void:
	AudioManager.play_sfx(preload("res://assets/Sound/cancel.wav"))
