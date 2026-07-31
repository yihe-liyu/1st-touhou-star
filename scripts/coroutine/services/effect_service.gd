class_name EffectService
extends RefCounted
## 特效服务 —— ctx.effects 下的特效 API（Miss 圈 / 命中特效）

## 全屏圆形 Miss 特效圈（MissEffectManager 封装）
func add_miss_circle(world_pos: Vector2, duration: float, max_radius: float,
		start_radius: float = 0.0, start_delay: float = 0.0) -> void:
	MissEffectManager.add_circle(world_pos, duration, max_radius, start_radius, start_delay)

## 命中特效（对象池，HitEffectPool 封装）
func play_hit_effect(scene: PackedScene, pos: Vector2) -> void:
	HitEffectPool.play(scene, pos)
