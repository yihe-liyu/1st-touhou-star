extends AnimatedSprite2D
class_name EnemyVisual

## 自动根据父节点移动方向切换动画
## 状态机：idle ↔ righting(过渡) ↔ right(循环)
## 向左时 flip_h 翻转

const IDLE = "idle"
const RIGHTING = "righting"
const RIGHT = "right"

var anim_state: String = IDLE
var _last_pos: Vector2


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	var parent = get_parent()
	if parent:
		_last_pos = parent.global_position


func _process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if not parent:
		return
	var dx := parent.global_position.x - _last_pos.x
	var moving_left := dx < -1.0
	var moving_right := dx > 1.0
	
	if moving_left:
		flip_h = true
	elif moving_right:
		flip_h = false
	
	match anim_state:
		IDLE:
			if moving_left or moving_right:
				change_state(RIGHTING)
		RIGHTING:
			if not moving_left and not moving_right:
				change_state(IDLE)
		RIGHT:
			if not moving_left and not moving_right:
				change_state(IDLE)
	
	_last_pos = parent.global_position


func change_state(new_state: String) -> void:
	if anim_state == new_state:
		return
	anim_state = new_state
	play(anim_state)


func _on_animation_finished() -> void:
	match anim_state:
		RIGHTING:
			change_state(RIGHT)
