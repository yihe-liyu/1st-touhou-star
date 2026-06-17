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
	_on_leave()
	finished.emit(result)

## 弹栈：退场动画后 pop
func leave() -> void:
	_on_leave()
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


# ═══ 视觉：脉冲高亮 ═══

var _pulse_tween: Tween

func _highlight_items(items: Array, index: int) -> void:
	for i in items.size():
		var target := Color.WHITE if i == index else Color(0.4, 0.4, 0.4)
		var tw: Tween = items[i].create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(items[i], "modulate", target, 0.12)

func _start_pulse(item: Control) -> void:
	_stop_pulse()
	if item.modulate.a < 0.01: return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(item, "modulate", Color.WHITE, 0.3)
	_pulse_tween.tween_property(item, "modulate", Color(0.5, 0.5, 0.5), 0.3)

func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null

func _play_entrance(items: Array) -> void:
	for i in items.size():
		items[i].modulate.a = 0.0
		items[i].scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel(true)
	for i in items.size():
		var delay := i * 0.04
		tw.tween_property(items[i], "modulate:a", 1.0, 0.15).set_delay(delay)
		tw.tween_property(items[i], "scale", Vector2.ONE, 0.2).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
