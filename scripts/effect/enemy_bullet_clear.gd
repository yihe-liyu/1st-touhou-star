extends HitEffect
class_name EnemyBulletClear

@onready var s: Sprite2D = $Sprite2D

func _sprite() -> Sprite2D:
	return s if s else $Sprite2D

const BLEND_SHADER = preload("res://gdshader/bullet_fog_blend.gdshader")

var _tween: Tween


func _ready() -> void:
	_ensure_material()


func _get_speed() -> float:
	return 0.0


func _setup() -> void:
	_ensure_material()
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	var sp := _sprite()
	sp.scale = Vector2.ONE
	
	var mat := sp.material as ShaderMaterial
	mat.set_shader_parameter("fog_tint:a", 1.0)
	
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(sp, "scale", Vector2(0.2, 0.2), 0.6)
	_tween.tween_method(_set_alpha.bind(mat), 1.0, 0.0, 0.6)
	# callback 不能 parallel，否则 0 时刻就触发
	_tween.chain().tween_callback(_finish)


func set_tint(color: Color) -> void:
	_ensure_material()
	var sp := _sprite()
	var mat := sp.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fog_tint", color)


func _ensure_material() -> void:
	var sp := _sprite()
	if not sp.material:
		var mat := ShaderMaterial.new()
		mat.shader = BLEND_SHADER
		sp.material = mat
		sp.modulate = Color.WHITE


func _set_alpha(a: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("fog_tint:a", a)


func _get_life_limit() -> float:
	return 1.5
