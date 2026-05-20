# Bullet.gd
extends Node2D
class_name Bullet

const FACTION_PLAYER: int = 0
const FACTION_ENEMY: int = 1
const FACTION_BOMB: int = 2

# 基础属性
var damage: int = 10
var velocity: Vector2 = Vector2.UP
var faction: int = FACTION_PLAYER
var can_be_canceled: bool = false
var hit_effect: PackedScene

# 判定区域
var hitbox_shape: int = BulletData.HitboxShape.CIRCLE
var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_radius: float = 4.0
var hitbox_size: Vector2 = Vector2(8, 8)
var hitbox_rotation: float = 0.0

# 运行时状态
var movement = null
var coroutine_movement: BulletMoveScript

# 额外变量
var extra: Dictionary = {}

@onready var sprite: Sprite2D = $Sprite2D

func bind(data: BulletData, direction: Vector2, override: BulletOverride = null):
	z_index = 10

	var effective_dir = direction
	if override and override.angle_offset != 0.0:
		effective_dir = direction.rotated(override.angle_offset)

	sprite.texture = data.texture
	damage = override.damage if override and override.damage >= 0 else data.damage
	faction = data.faction
	can_be_canceled = override.can_be_canceled if override and override._override_cancel else data.can_be_canceled
	hit_effect = data.hit_effect

	hitbox_shape = data.hitbox_shape
	hitbox_offset = data.hitbox_offset
	hitbox_radius = data.hitbox_radius
	hitbox_size = data.hitbox_size
	hitbox_rotation = data.hitbox_rotation

	extra = data.extra.duplicate()

	var speed = data.velocity.length()
	if override and override.speed_mult > 0.0:
		speed *= override.speed_mult
	velocity = effective_dir.normalized() * speed
	self.rotation = effective_dir.angle()

	if coroutine_movement and is_instance_valid(coroutine_movement):
		coroutine_movement.stop()
		coroutine_movement.queue_free()
		coroutine_movement = null
	movement = null
	for child in get_children():
		if child is BulletMoveScript:
			child.stop()
			child.queue_free()

	if data.movement_script:
		movement = data.movement_script.new()
	else:
		movement = MoveLinear.new()

	if movement is BulletMovement:
		movement.bind(self)
	elif movement is CoroutineRunner:
		coroutine_movement = movement
		add_child(coroutine_movement)
		var api = StageAPI.new(coroutine_movement)
		coroutine_movement.start_moving(api, self)

func batch_texture() -> Texture2D:
	return sprite.texture
