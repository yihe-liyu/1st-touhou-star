extends CanvasLayer
# 全局 miss 特效管理器 —— 独立渲染层，一个全屏 shader

const MAX_CIRCLES := 8

var _circles: Array[Dictionary] = []
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	# CanvasLayer 下直接创建全屏 ColorRect
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://gdshader/miss_circle.gdshader")
	_mat.set_shader_parameter("edge_soft", 0.03)
	for i in MAX_CIRCLES:
		_mat.set_shader_parameter("c_pos[%d]" % i, Vector2.ZERO)
		_mat.set_shader_parameter("c_radius[%d]" % i, 0.0)
		_mat.set_shader_parameter("c_alpha[%d]" % i, 0.0)
	
	_rect.material = _mat
	add_child(_rect)


func add_circle(world_pos: Vector2, duration: float = 0.6, max_radius: float = 500.0, start_radius: float = 30.0) -> void:
	_circles.append({
		world_pos = world_pos,
		age = 0.0,
		duration = duration,
		start_r = start_radius,
		max_r = max_radius,
	})


func _process(delta: float) -> void:
	for i in range(_circles.size() - 1, -1, -1):
		_circles[i].age += delta
		if _circles[i].age >= _circles[i].duration:
			_circles.remove_at(i)
	_update_shader()


func _update_shader() -> void:
	var vs := get_viewport().get_visible_rect().size
	var canvas := get_viewport().get_canvas_transform()
	
	for i in MAX_CIRCLES:
		if i < _circles.size():
			var c := _circles[i]
			var t := clampf(c.age / c.duration, 0.0, 1.0)
			var radius_px := lerpf(c.start_r, c.max_r, t)
			# 世界坐标 → 屏幕坐标
			var screen_pos := canvas * c.world_pos
			# 屏幕坐标 → UV (0~1)
			var uv_pos := screen_pos / vs
			var radius_uv := radius_px / maxf(vs.x, vs.y)
			var alpha: float = 1.0 if t <= 0.5 else (1.0 - (t - 0.5) / 0.5)
			
			_mat.set_shader_parameter("c_pos[%d]" % i, uv_pos)
			_mat.set_shader_parameter("c_radius[%d]" % i, radius_uv)
			_mat.set_shader_parameter("c_alpha[%d]" % i, alpha)
		else:
			_mat.set_shader_parameter("c_pos[%d]" % i, Vector2(-1, -1))
			_mat.set_shader_parameter("c_radius[%d]" % i, 0.0)
			_mat.set_shader_parameter("c_alpha[%d]" % i, 0.0)
