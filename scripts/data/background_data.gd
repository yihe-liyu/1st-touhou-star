extends Resource
class_name BackgroundData

@export var background_id: int = 0
@export var background_name: String = ""
@export var quads: Array = []
@export var particles: Array = []
@export var front_texture: Texture2D
@export var fog_color: Color = Color(0.49, 0.42, 0.67, 1)
@export var fog_density: float = 1.0
@export var fog_depth_begin: float = 3.0
@export var fog_depth_end: float = 35.0
