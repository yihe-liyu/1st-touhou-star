extends MoveScript
class_name OptionFollow

var leader: Node2D
var offset: Vector2

## 追赶速度（单位：1/秒），值越大跟随越紧
## 13.39 ≈ 原来 lerp(goal, 0.2) 在 60 FPS 下的效果
const FOLLOW_SPEED: float = 13.39

func _on_run(api: StageAPI):
	var delta := 1.0 / Engine.physics_ticks_per_second
	var lerp_factor := 1.0 - exp(-FOLLOW_SPEED * delta)
	while api.active() and is_instance_valid(leader) and is_instance_valid(target):
		var goal := leader.global_position + offset
		target.global_position = target.global_position.lerp(goal, lerp_factor)
		await api.frames(1)
