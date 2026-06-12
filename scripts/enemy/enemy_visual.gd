extends AnimatedSprite2D
class_name EnemyVisual

const IDLE = "idle"
const RIGHTING = "righting"
const RIGHT = "right"

var anim_state: String = IDLE
var _moving: bool = false


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)


func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if moving:
		change_state(RIGHTING)
	else:
		change_state(IDLE)


func change_state(new_state: String) -> void:
	if anim_state == new_state:
		return
	anim_state = new_state
	play(anim_state)


func _on_animation_finished() -> void:
	match anim_state:
		RIGHTING:
			change_state(RIGHT)
