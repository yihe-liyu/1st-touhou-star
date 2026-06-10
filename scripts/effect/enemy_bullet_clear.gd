extends HitEffect
class_name EnemyBulletClear

@onready var sprite: Sprite2D = $Sprite2D

const BLEND_SHADER = preload("res://gdshader/bullet_fog_blend.gdshader")

var _tween: Tween


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = BLEND_SHADER
	sprite.material = mat
	sprite.modulate = Color.WHITE


func _get_speed() -> float:
	return 0.0


func _setup() -> void:
	# 杀旧 tween 防冲突
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# 从正常大小开始，只缩小+淡出
	sprite.scale = Vector2.ONE
	
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("fog_tint:a", 1.0)
	
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.4)
	_tween.tween_method(_set_alpha.bind(mat), 1.0, 0.0, 0.4)
	_tween.tween_callback(_finish)


func set_tint(color: Color) -> void:
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("fog_tint", color)


func _set_alpha(a: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("fog_tint:a", a)


func _get_life_limit() -> float:
	return 1.0
