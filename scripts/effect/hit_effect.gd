extends Node2D
class_name HitEffect
## 命中特效基类 — 子类只需覆写少量方法

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0


func _ready() -> void:
	_setup()


# ── 公共接口 ──

func set_velocity(vel: Vector2) -> void:
	velocity = vel.normalized() * _get_speed()
	_on_velocity_set()


func set_tint(_color: Color) -> void:
	pass


# ── 子类覆写 ──

func _get_speed() -> float:
	return 300.0


## 存活上限（秒），超时强制 queue_free
func _get_life_limit() -> float:
	return 2.0


## _ready 时调用一次，播放动画、创建 tween 等
func _setup() -> void:
	pass


## set_velocity 注入速度后调用，用于设置 rotation 等
func _on_velocity_set() -> void:
	pass


## 每物理帧额外逻辑（缩放等）
func _process_extra(_delta: float) -> void:
	pass


# ── 内部 ──

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_process_extra(delta)
	_age += delta
	if _age > _get_life_limit():
		queue_free()
