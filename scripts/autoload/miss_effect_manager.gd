extends Node2D
# 全局 miss 特效管理器

const MAX_CIRCLES := 8

var _circles: Array[Dictionary] = []
var _rect: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	# 直接在场景根下放全屏 ColorRect
	var vs := get_viewport().get_visible_rect().size
	_rect = ColorRect.new()
	_rect.size = vs
	_rect.position = Vector2.ZERO
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.z_index = 100
	
	_rect.color = Color.RED  # DEBUG
	
	# _mat = ShaderMaterial.new()
	# _mat.shader = preload("res://gdshader/miss_circle.gdshader")
	# ...
	# _rect.material = _mat
	
	add_child(_rect)
	print("[MissEffectManager] ready, rect pos=", _rect.position, " size=", _rect.size)


func add_circle(world_pos: Vector2, duration: float = 0.6, max_radius: float = 500.0, start_radius: float = 30.0) -> void:
	print("[MissEffectManager] add_circle at ", world_pos)
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
	# _update_shader()
