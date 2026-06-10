extends HitEffect
class_name EnemyBulletClear

@onready var sprite: Sprite2D = $Sprite2D

const BLEND_SHADER = preload("res://gdshader/bullet_fog_blend.gdshader")


func _ready() -> void:
	# 挂 BLEND shader，后续 activate → _setup() 会用到
	var mat := ShaderMaterial.new()
	mat.shader = BLEND_SHADER
	sprite.material = mat


func _get_speed() -> float:
	return 0.0


func _setup() -> void:
	sprite.scale = Vector2(0.3, 0.3)
	
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("fog_tint:a", 1.0)
	
	# 弹开 → 缩小 → 淡出
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", Vector2(1.2, 1.2), 0.15)
	tw.tween_method(_set_alpha.bind(mat), 1.0, 0.3, 0.15)
	tw.tween_callback(func():
		var tw2: Tween = create_tween()
		tw2.set_parallel(true)
		tw2.set_trans(Tween.TRANS_CUBIC)
		tw2.set_ease(Tween.EASE_IN)
		tw2.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.25)
		tw2.tween_method(_set_alpha.bind(mat), 0.3, 0.0, 0.25)
		tw2.tween_callback(_finish)
	)


func set_tint(color: Color) -> void:
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("fog_tint", color)


func _set_alpha(a: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("fog_tint:a", a)


func _get_life_limit() -> float:
	return 1.0
