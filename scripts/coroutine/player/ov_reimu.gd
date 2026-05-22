extends OptionVisual
class_name OptionVisualSimple

var texture: Texture2D
var rotation_speed: float = 3.0

var sprite: Sprite2D

func setup(option: Node2D) -> void:
	sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(2, 2)
	option.add_child(sprite)

	var rotator := CoroutineRunner.new()
	rotator.name = "Rotator"
	option.add_child(rotator)
	rotator.run(_rotate.bind(StageAPI.new(rotator)))

func _rotate(api: StageAPI):
	while api._active():
		sprite.rotation += deg_to_rad(rotation_speed)
		await api.frames(1)

func update_visual(_api: StageAPI, _leader: Node2D) -> void:
	pass
