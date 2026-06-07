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
var coroutine_movement: MoveScript
var is_ready: bool = false

# 额外变量
var extra: Dictionary = {}
var _grazed: bool = false  # 擦过弹了

@onready var sprite: Sprite2D = $Sprite2D
@onready var fog: BulletFog = $Fog

func bind(data: BulletData, direction: Vector2, override: BulletOverride = null):
	is_ready = false
	_grazed = false
	match data.faction:
		FACTION_ENEMY:
			z_index = 10
		FACTION_BOMB:
			z_index = 100
		_:
			z_index = 5

	var effective_dir = direction
	if override and override.angle_offset != 0.0:
		effective_dir = direction.rotated(override.angle_offset)

	sprite.texture = data.texture
	faction = data.faction
	damage = override.damage if override and override.damage >= 0 else data.damage
	
	# 自机弹 2 倍大，敌弹 1 倍
	scale = Vector2(2, 2) if faction == FACTION_PLAYER else Vector2.ONE
	
	# 自机子弹：记忆值越低越红
	sprite.modulate = data.tint
	if faction == FACTION_PLAYER:
		var mem := GameState.memory_value
		if mem < 50.0:
			var red := remap(mem, 0.0, 50.0, 1.0, 0.0)
			sprite.modulate = sprite.modulate.lerp(Color.RED, red * 0.5)
	can_be_canceled = override.can_be_canceled if override and override._override_cancel else data.can_be_canceled
	hit_effect = data.hit_effect

	hitbox_shape = data.hitbox_shape
	hitbox_offset = data.hitbox_offset
	hitbox_radius = data.hitbox_radius
	hitbox_size = data.hitbox_size
	hitbox_rotation = data.hitbox_rotation

	var speed = data.velocity.length()
	if override and override.speed_mult > 0.0:
		speed *= override.speed_mult
	velocity = effective_dir.normalized() * speed
	self.rotation = effective_dir.angle()

	if coroutine_movement and is_instance_valid(coroutine_movement):
		coroutine_movement.stop()
		coroutine_movement.queue_free()
		coroutine_movement = null
	for child in get_children():
		if child is MoveScript:
			child.stop()
			child.queue_free()

	if data.spawn_fog:
		sprite.visible = false  # 雾消失前隐藏子弹
		if fog.fog_finished.is_connected(_on_fog_ready):
			fog.fog_finished.disconnect(_on_fog_ready)
		fog.fog_finished.connect(_on_fog_ready, CONNECT_ONE_SHOT)
		fog.play(data.fog_texture)
		fog.modulate = data.tint
	else:
		fog.visible = false
		is_ready = true
		sprite.visible = true

	# 只有自定义移动脚本才用协程；普通线性移动走 _physics_process
	if data.movement_script:
		_start_movement(data)

func _on_fog_ready():
	sprite.visible = true  # 雾结束，显示子弹
	is_ready = true

func _physics_process(_delta):
	if not is_ready or coroutine_movement:
		return
	self.global_position += velocity / Engine.physics_ticks_per_second

func _start_movement(data: BulletData):
	coroutine_movement = data.movement_script.new()
	assert(coroutine_movement is MoveScript, "Bullet: movement_script must be a MoveScript")
	add_child(coroutine_movement)
	var api = StageAPI.new(coroutine_movement)
	coroutine_movement.start_moving(api, self)

func batch_texture() -> Texture2D:
	return sprite.texture
