extends CanvasLayer

const MAX_CIRCLES := 8

var _circles: Array[Dictionary] = []
var _rect: ColorRect
var _mat: ShaderMaterial
var _prefixes := ["c0", "c1", "c2", "c3", "c4", "c5", "c6", "c7"]
var _view_size: Vector2


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_view_size = get_viewport().get_visible_rect().size
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://gdshader/miss_circle.gdshader")
	_mat.set_shader_parameter("vs", _view_size)
	_mat.set_shader_parameter("edge_soft", 0.005)
	for pf: String in _prefixes:
		_mat.set_shader_parameter("%s_pos" % pf, Vector2(-1, -1))
		_mat.set_shader_parameter("%s_radpx" % pf, 0.0)
		_mat.set_shader_parameter("%s_alpha" % pf, 0.0)
	
	_rect.material = _mat
	add_child(_rect)


## start_delay: 延迟秒数后才开始显示，负数 age 期间不渲染
func add_circle(world_pos: Vector2, duration: float = 0.8, max_radius: float = 1280.0, start_radius: float = 0.0, start_delay: float = 0.0) -> void:
	_circles.append({
		world_pos = world_pos,
		age = -start_delay,
		duration = duration,
		start_r = start_radius,
		max_r = max_radius,
	})


func _process(delta: float) -> void:
	for i in range(_circles.size() - 1, -1, -1):
		_circles[i].age += delta
	_update_shader()
	for i in range(_circles.size() - 1, -1, -1):
		if _circles[i].age >= _circles[i].duration:
			print("[Miss] remove age=", _circles[i].age, " dur=", _circles[i].duration)
			_circles.remove_at(i)


func _update_shader() -> void:
	var vs := _view_size
	var canvas := get_viewport().get_canvas_transform()
	
	for i in MAX_CIRCLES:
		var pf: String = _prefixes[i]
		if i < _circles.size():
			var c := _circles[i]
			if c.age < 0.0:  # 还在延迟中，不渲染
				_mat.set_shader_parameter("%s_pos" % pf, Vector2(-1, -1))
				_mat.set_shader_parameter("%s_radpx" % pf, 0.0)
				_mat.set_shader_parameter("%s_alpha" % pf, 0.0)
				continue
			var t := clampf(c.age / c.duration, 0.0, 1.0)
			var radius_px := lerpf(c.start_r, c.max_r, t)
			var screen_pos: Vector2 = canvas * c.world_pos
			var uv_pos := screen_pos / vs
			
			_mat.set_shader_parameter("%s_pos" % pf, uv_pos)
			_mat.set_shader_parameter("%s_radpx" % pf, radius_px)
			_mat.set_shader_parameter("%s_alpha" % pf, 1.0)
		else:
			_mat.set_shader_parameter("%s_pos" % pf, Vector2(-1, -1))
			_mat.set_shader_parameter("%s_radpx" % pf, 0.0)
			_mat.set_shader_parameter("%s_alpha" % pf, 0.0)
