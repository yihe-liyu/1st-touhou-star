extends Resource
class_name BackgroundParticleConfig

@export var texture: Texture2D
@export var amount: int = 50
@export var lifetime: float = 5.0
@export var speed_min: float = 20.0
@export var speed_max: float = 60.0
@export var direction: Vector2 = Vector2(0, -1)
@export var spread: float = 180.0
@export var scale_min: float = 0.5
@export var scale_max: float = 1.5
@export var gravity: Vector2 = Vector2(0, 5)
@export var modulate: Color = Color(1, 1, 1, 0.5)
@export var spawn_rect: Rect2 = Rect2(0, 0, 1, 1)
@export var one_shot: bool = false
@export var explosiveness: float = 1.0
@export var position: Vector3 = Vector3(0, 2, 4)
