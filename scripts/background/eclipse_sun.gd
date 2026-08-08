extends Node2D
class_name EclipseSun
## 伪日食太阳 —— 2D 自绘（CanvasLayer 叠在 3D 背景上，不受雾衰减）
## 黑圆 = 日食遮挡；金色亮环 = "周边露出较亮的太阳光芒"
## set_glow(v) 控制漏光强度：0=全食只剩轮廓 / 1=常态 / 2=回光

var radius: float = 34.0
var ring_width: float = 26.0
var glow: float = 1.0

func set_glow(v: float) -> void:
	glow = clampf(v, 0.0, 2.5)
	queue_redraw()

func _draw() -> void:
	var c := Vector2(radius + ring_width * 1.6, radius + ring_width * 1.6)
	# 外圈大气散射（两层，随漏光强度）
	draw_circle(c, radius + ring_width * 1.9, Color(1.0, 0.78, 0.42, 0.08 * glow))
	draw_circle(c, radius + ring_width * 1.3, Color(1.0, 0.80, 0.45, 0.16 * glow))
	# 亮环（边缘漏光——伪日食点睛）
	draw_arc(c, radius + ring_width * 0.5, 0, TAU, 96, Color(1.0, 0.85, 0.55, 0.85 * glow), ring_width)
	# 黑圆（不规则的日食遮挡）
	draw_circle(c, radius, Color(0.015, 0.015, 0.025))
	# 黑圆边缘一点微光晕（让黑圆在雾中显形）
	draw_circle(c, radius * 0.92, Color(0.05, 0.05, 0.08))
