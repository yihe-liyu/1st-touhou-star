class_name ClockService
extends RefCounted
## 时间服务 —— 协程等待（返回秒数给 CoroutineRunner）

func wait(seconds: float) -> float:
	return seconds

func wait_frames(count: int) -> float:
	return float(count) / Engine.physics_ticks_per_second
