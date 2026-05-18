# BgSprite.gd
extends Sprite3D
class_name BgSprite

var self_velocity: Vector3 = Vector3.ZERO   # 自身初速度（由生成者设定）
var ground_speed_mult: float = 1.0          # 地面速度系数（由管理器每帧同步）
var life_timer: float = 0.0                 # 已经活了多久

func setup(texture: Texture2D, color: Color, velocity: Vector3):
	# 贴图
	material_override.set_shader_parameter("texture_albedo", texture)
	material_override.set_shader_parameter("tint", color)
	# 初速度（由你决定方向和大小）
	self_velocity = velocity
	# 计时器归零
	life_timer = 0.0

func update_movement(delta: float, speed_mult: float):
	# 同步全局地面速度系数
	ground_speed_mult = speed_mult
	# 实际移动 = 自身速度 + 地面滚动贡献
	# 地面滚动的世界表现为物体沿 Z 轴正向（向屏幕深处）移动
	var ground_contribution = Vector3(0.0, 0.0, ground_speed_mult)
	global_position += (self_velocity + ground_contribution) * delta
	life_timer += delta
