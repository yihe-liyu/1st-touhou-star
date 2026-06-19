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
	set_process(true)

func _process(_delta):
	if get_tree().paused:
		return
	if not is_instance_valid(sprite):
		return
	sprite.rotation += deg_to_rad(rotation_speed)

func update_visual(_ctx: StageContext, _leader: Node2D) -> void:
	pass
