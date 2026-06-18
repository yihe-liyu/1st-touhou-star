extends BackgroundScript

@onready var bg: StageBackground = $".."
@onready var ground: BackgroundPlane = $"../Ground"

@export var tree_texture: Texture2D

func _on_init(api: StageAPI) -> void:
	if bg.world_environment:
		var env := bg.world_environment.environment
		env.fog_light_color = Color.BLACK
		env.fog_density = 0.5
	if bg.camera:
		bg.camera.fov = 55.0

	# 黑雾里预生成树, 雾散时已经在场
	for i in range(80):
		var x = RNG.randf_range(-50, 50)
		var z = RNG.randf_range(-180, 20)
		_spawn(api, tree_texture, Vector2(8, 8), 4.0, x, z)

func _on_step(_api: StageAPI) -> Variant:
	return true

func _spawn(api: StageAPI, tex: Texture2D, size: Vector2, y: float, x: float, z: float):
	api.spawn_decor_batched(tex, Vector3(x, y, z), size, ground)
