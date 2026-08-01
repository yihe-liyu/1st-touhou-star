## 生命周期子弹模型 —— 工作台预览用（纯数学，不实例化真实 Bullet）
## 直线运动：position = origin + velocity * local_time
## 行为公式与游戏实体对齐（同一套领域逻辑 → 预览≈游戏）
class_name LifecycleBullet
extends LifecycleNode

var origin: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var radius: float = 4.0


func _init() -> void:
	fast_advance = true  # 子弹位置是纯函数：直接跳时间（性能）


func is_entity() -> bool:
	return true  # 子弹是运行时实体：编排树不显示


func position() -> Vector2:
	return position_at(local_time)


## 任意局部时刻的位置（轨迹绘制用）
func position_at(t: float) -> Vector2:
	return origin + velocity * t


func _should_die() -> bool:
	# 出东方框即死（用 GameConfig 常量值，不依赖 autoload）
	const LEFT := 64.0
	const RIGHT := 832.0
	const TOP := 32.0
	const BOTTOM := 928.0
	var p := position()
	return p.x < LEFT or p.x > RIGHT or p.y < TOP or p.y > BOTTOM
