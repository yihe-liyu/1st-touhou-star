class_name ClockService
extends RefCounted
## 时间服务 —— 替换 api.seconds / api.frames

var elapsed: float = 0.0
var delta: float = 0.0

func tick(dt: float) -> void:
	delta = dt
	elapsed += dt

func wait(seconds: float) -> float:
	return seconds

func wait_frames(count: int) -> float:
	return float(count) / Engine.physics_ticks_per_second
