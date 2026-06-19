extends MoveScript
class_name MoveEntrance
## 入场动画 — 目标从当前位置平滑滑到指定 Y 坐标
##
## 使用方法：
##   1. 在关卡脚本里新建 MoveEntrance 节点
##   2. 设 target_y 和 duration
##   3. 调用 entrance.start_moving(api, target_node)
##
## 原理：
##   start_moving() 创建 Tween 驱动 global_position.y 插值，
##   协程等待 duration 秒后标记完成。
##   动画在 idle frame 运行（丝滑），协程在 physics frame 等待（近似同步）。

## 目标 Y 坐标（屏幕坐标, 像素）
var target_y: float = 200.0

## 动画持续时间（秒）
var duration: float = 2.0

var _wait: float = 0.0


## 启动入场动画
## @param api     StageAPI 实例
## @param p_target 要移动的节点
func start_moving(api: StageAPI, p_target: Node2D, p_ctx = null):
	ctx = p_ctx
	target = p_target

	# 目标位置：X 不变, Y 滑到 target_y
	var end_pos := Vector2(target.global_position.x, target_y)

	# EASE_OUT + QUINT: 快速起 → 柔和停, 有惯性感
	var tween := target.create_tween()
	tween.tween_property(target, "global_position", end_pos, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)

	# 协程等 duration 秒后结束
	_wait = duration
	run(_on_step.bind(api))


## 协程回调 — 返回等待秒数
func _on_step(_api: StageAPI) -> Variant:
	return ctx.clock.wait(_wait)
