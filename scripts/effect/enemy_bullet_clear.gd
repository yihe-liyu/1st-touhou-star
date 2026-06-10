extends HitEffect
class_name EnemyBulletClear

@onready var sprite: Sprite2D = $Sprite2D

# 池里 instantiate 时还没进树，@onready 不会触发，用 get_node 兜底
func _get_sprite() -> Sprite2D:
	return sprite if sprite else $Sprite2D

const BLEND_SHADER = preload("res://gdshader/bullet_fog_blend.gdshader")

var _tween: Tween


func _ready() -> void:
	_ensure_material()


func _get_speed() -> float:
	return 0.0


func _setup() -> void:
	# 确保 _ready 跑过（池首次使用时可能还没进树）
	_ensure_material()
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	sprite.scale = Vector2.ONE
	
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("fog_tint:a", 1.0)
	
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.6)
	_tween.tween_method(_set_alpha.bind(mat), 1.0, 0.0, 0.6)
	_tween.tween_callback(_finish)


func set_tint(color: Color) -> void:
	_ensure_material()
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fog_tint", color)


func _ensure_material() -> void:
	if not sprite.material:
		var mat := ShaderMaterial.new()
		mat.shader = BLEND_SHADER
		sprite.material = mat
		sprite.modulate = Color.WHITE


func _set_alpha(a: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("fog_tint:a", a)


func _get_life_limit() -> float:
	return 1.5
