extends Node2D
class_name MissEffectManager
# 全局 miss 特效管理器 —— 一个全屏 ColorRect + shader，支持多圈并存

const MAX_CIRCLES := 8

var _circles: Array[Dictionary] = []  # {pos, age, duration, start_r, max_r}
var _rect: ColorRect
var _mat: ShaderMaterial
var _half_size: float


func _ready() -> void:
	var vs := get_viewport().get_visible_rect().size
	_half_size = maxf(vs.x, vs.y) * 2.0 / 2.0  # 矩形半边长（UV: 0→1 = 0→half_size px）
	
	_rect = ColorRect.new()
	_rect.size = Vector2(_half_size * 2.0, _half_size * 2.0)
	_rect.position = -Vector2(_half_size, _half_size)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.z_index = 100
	
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://gdshader/miss_circle.gdshader")
	_mat.set_shader_parameter("edge_soft", 0.03)
	# 初始化空圈
	for i in MAX_CIRCLES:
		_mat.set_shader_parameter("c_pos", Vector2.ZERO, i)
		_mat.set_shader_parameter("c_radius", 0.0, i)
		_mat.set_shader_parameter("c_alpha", 0.0, i)
	
	_rect.material = _mat
	add_child(_rect)


func add_circle(pos: Vector2, duration: float = 0.6, max_radius: float = 500.0, start_radius: float = 30.0) -> void:
	_circles.append({
		world_pos = pos,
		age = 0.0,
		duration = duration,
		start_r = start_radius,
		max_r = max_radius,
	})


func _process(delta: float) -> void:
	var to_remove: Array[int] = []
	
	for i in _circles.size():
		_circles[i].age += delta
		if _circles[i].age >= _circles[i].duration:
			to_remove.append(i)
	
	# 从后往前删
	for idx in to_remove:
		_circles.remove_at(idx)
	
	_update_shader()


func _update_shader() -> void:
	for i in MAX_CIRCLES:
		if i < _circles.size():
			var c := _circles[i]
			var t := clampf(c.age / c.duration, 0.0, 1.0)
			var radius_px := lerpf(c.start_r, c.max_r, t)
			var radius_uv := radius_px / _half_size
			var alpha: float = 1.0 if t <= 0.5 else (1.0 - (t - 0.5) / 0.5)
			# 世界坐标 → UV（相对矩形）
			var uv_pos: Vector2 = (c.world_pos + Vector2(_half_size, _half_size)) / (_half_size * 2.0)
			_mat.set_shader_parameter("c_pos", uv_pos, i)
			_mat.set_shader_parameter("c_radius", radius_uv, i)
			_mat.set_shader_parameter("c_alpha", alpha, i)
		else:
			_mat.set_shader_parameter("c_pos", Vector2(-1, -1), i)
			_mat.set_shader_parameter("c_radius", 0.0, i)
			_mat.set_shader_parameter("c_alpha", 0.0, i)
