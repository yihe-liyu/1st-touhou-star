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
enum HitboxShape { CIRCLE, RECTANGLE }
var hitbox_shape: int = HitboxShape.CIRCLE
var hitbox_offset: Vector2 = Vector2.ZERO
var hitbox_radius: float = 4.0
var hitbox_size: Vector2 = Vector2(8, 8)
var hitbox_rotation: float = 0.0

# 运行时状态
var movement: RefCounted = null

# 额外变量
var extra: Dictionary = {}

func bind(data: BulletData, direction: Vector2):
	z_index = 10
	
	$Sprite2D.texture = data.texture
	damage = data.damage
	velocity = direction.normalized() * data.velocity.length()
	faction = data.faction
	can_be_canceled = data.can_be_canceled
	hit_effect = data.hit_effect
	
	hitbox_shape = data.hitbox_shape
	hitbox_offset = data.hitbox_offset
	hitbox_radius = data.hitbox_radius
	hitbox_size = data.hitbox_size
	hitbox_rotation = data.hitbox_rotation
	
	extra = data.extra.duplicate()
	
	self.rotation = direction.angle()
	
	# 如果配了自定义移动脚本，就创建脚本实例
	if data.movement_script:
		movement = data.movement_script.new()
	else:
		movement = MoveLinear.new()
	movement.bind(self)
