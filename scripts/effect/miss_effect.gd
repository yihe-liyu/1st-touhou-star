extends Node2D
class_name MissEffect
# miss 时在玩家位置生成的反色扩散圆

@export var max_radius: float = 300.0
@export var duration: float = 0.6
@export var start_radius: float = 30.0


func _ready() -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(max_radius * 2.0, max_radius * 2.0)
	rect.position = -Vector2(max_radius, max_radius)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 100
	
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/miss_circle.gdshader")
	mat.set_shader_parameter("circle_radius", start_radius / max_radius)
	mat.set_shader_parameter("alpha", 1.0)
	mat.set_shader_parameter("edge_soft", 0.03)
	rect.material = mat
	
	add_child(rect)
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_update_radius, 0.0, 1.0, duration)
	tween.finished.connect(queue_free)


func _update_radius(t: float) -> void:
	if not is_inside_tree():
		return
	var rect: ColorRect = get_child(0) as ColorRect
	if not rect or not rect.material:
		return
	var mat: ShaderMaterial = rect.material as ShaderMaterial
	var radius = lerpf(start_radius, max_radius, t)
	mat.set_shader_parameter("circle_radius", radius / max_radius)
	# 后半段淡出
	if t > 0.5:
		var fade: float = 1.0 - (t - 0.5) / 0.5
		mat.set_shader_parameter("alpha", fade)
