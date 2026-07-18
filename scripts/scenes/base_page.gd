# BasePage — 统一菜单页面基类（替代 MenuScreen）
#
## 所有可被 MenuNav 管理的页面都应继承此类
##
## 生命周期:
##   push → _on_enter()     (首次进入)
##   push another → _on_deactivate()  (被覆盖)
##   pop another → _on_activate()     (重新激活)
##   pop self   → _on_leave()         (退场)
##
## 退场标准流程:
##   _on_leave() → 播放退场动画 → finished.emit({}) 或 queue_free()

class_name BasePage
extends Control

signal finished(result: Dictionary)
signal back()

# ═══ 内置遮罩（可选） ═══

const OVERLAY_FADE_IN: float = 0.2
const OVERLAY_FADE_OUT: float = 0.15

## 设为 true 则 _on_enter 时自动淡入暗色遮罩
@export var auto_overlay: bool = true
## 遮罩颜色
@export var overlay_color: Color = Color(0, 0, 0, 0.5)
## 遮罩淡入时长
@export var overlay_fade_in_dur: float = OVERLAY_FADE_IN
## 遮罩淡出时长
@export var overlay_fade_out_dur: float = OVERLAY_FADE_OUT

var _overlay: ColorRect = null


# ═══ 生命周期 ═══

func _init() -> void:
	pass

func _ready() -> void:
	_create_overlay()

func _create_overlay() -> void:
	if not auto_overlay:
		return
	# 检查场景中是否已有 Overlay 节点（复用）
	for child in get_children():
		if child.name == "Overlay" and child is ColorRect:
			_overlay = child
			_overlay.modulate.a = 0.0  # 初始透明
			_overlay.visible = true
			_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return
	# 创建新遮罩
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = overlay_color
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	move_child(_overlay, 0)

# ── 子类覆写 ──

## 首次进入（被 push 时调用一次）
func _on_enter() -> void:
	pass

## 被其他页面覆盖
func _on_deactivate() -> void:
	pass

## 覆盖的页面被移除，重新激活
func _on_activate() -> void:
	pass

## 被 pop 时调用 —— 应包含退场动画，动画结束后 queue_free()
func _on_leave() -> void:
	queue_free()


# ═══ 退场便捷方法 ═══

## 确认并返回结果（自动退场）
func done(result: Dictionary = {}) -> void:
	_on_leave()
	finished.emit(result)

## X 返回（无结果，触发 back 信号）
func go_back() -> void:
	_on_leave()
	back.emit()


# ═══ 遮罩动画 ═══

## 淡入遮罩
func _fade_overlay_in(duration: float = -1.0) -> void:
	if not _overlay:
		return
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	var dur := duration if duration >= 0 else overlay_fade_in_dur
	var tw := _overlay.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_overlay, "modulate:a", 1.0, dur)


## 淡出遮罩
func _fade_overlay_out(duration: float = -1.0) -> Tween:
	if not _overlay:
		return null
	var dur := duration if duration >= 0 else overlay_fade_out_dur
	var tw := _overlay.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_overlay, "modulate:a", 0.0, dur)
	return tw


## 内容淡入（从右侧滑入 + 透明 → 不透明）
func _fade_content_in(content: Control, duration: float = 0.2, slide: bool = true) -> void:
	content.modulate.a = 0.0
	if slide:
		content.position.x += 30

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(content, "modulate:a", 1.0, duration)
	if slide:
		tw.tween_property(content, "position:x", content.position.x - 30, duration)


## 内容 + 遮罩 一起淡出
func _fade_all_out(content: Control, content_dur: float = 0.15, overlay_dur: float = -1.0) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(content, "modulate:a", 0.0, content_dur)

	var ov_tw := _fade_overlay_out(overlay_dur)

	var cb := func():
		finished.emit({})
		queue_free()

	if ov_tw:
		ov_tw.tween_callback(cb)
	else:
		tw.tween_callback(cb)


## 覆盖层退场：遮罩淡出 + 内容缩小淡出 → queue_free
## 调用前需自行关闭导航（_nav_enabled=false, _stop_pulse()）
func _overlay_leave(content: Control) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_overlay_out(0.15)
	tw.tween_property(content, "modulate", Color(1, 1, 1, 0), 0.12)
	tw.tween_property(content, "scale", Vector2(0.95, 0.95), 0.12)
	tw.tween_callback(queue_free)


# ═══ 音效快捷 ═══

func sfx_nav() -> void:
	AudioManager.play_sfx(preload("res://assets/Sound/select.wav"))

func sfx_confirm() -> void:
	AudioManager.play_sfx(preload("res://assets/Sound/ok.wav"))

func sfx_back() -> void:
	AudioManager.play_sfx(preload("res://assets/Sound/cancel.wav"))
