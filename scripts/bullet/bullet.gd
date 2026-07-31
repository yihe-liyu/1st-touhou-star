# Bullet.gd
extends Node2D
class_name Bullet

const FACTION_PLAYER: int = 0
const FACTION_ENEMY: int = 1
const FACTION_BOMB: int = 2

# 基础属性
var damage: float = 10.0
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
var coroutine_script: CoroutineScript
var is_ready: bool = false

# 额外变量
var extra: Dictionary = {}
var _grazed: bool = false
var tint_mode: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var fog: BulletFog = $Fog


## 彻底重置所有运行时状态（池回收 + bind 复用时调用）
func _reset_state() -> void:
	is_ready = false
	_grazed = false
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	# 停旧协程
	if coroutine_script and is_instance_valid(coroutine_script):
		coroutine_script.stop()
		coroutine_script.queue_free()
		coroutine_script = null
	for child in get_children():
		if child is CoroutineScript:
			child.stop()
			child.queue_free()
	# 清雾
	fog.visible = false
	fog.texture = null
	if fog.fog_finished.is_connected(_on_fog_ready):
		fog.fog_finished.disconnect(_on_fog_ready)


func bind(data: BulletData, direction: Vector2):
	is_ready = false
	_grazed = false
	# 清理上次残留的子协程
	for child in get_children():
		if child is CoroutineScript:
			child.stop()
			remove_child(child)
			child.queue_free()
	match data.faction:
		FACTION_ENEMY:
			z_index = LayerConfig.ENEMY_BULLET
		FACTION_BOMB:
			z_index = LayerConfig.BOMB
		FACTION_PLAYER:
			z_index = LayerConfig.PLAYER_BULLET
		_:
			z_index = LayerConfig.ENEMY_BULLET

	sprite.texture = data.texture
	faction = data.faction
	tint_mode = data.tint_mode
	damage = data.damage
	
	# 自机弹 2 倍大，敌弹 1 倍
	scale = Vector2.ONE
	
	# 自机子弹：记忆值越低越红
	sprite.modulate = data.tint
	if faction == FACTION_PLAYER:
		var mem: float = GameState.memory_value
		if mem < 50.0:
			var red := remap(mem, 0.0, 50.0, 1.0, 0.0)
			sprite.modulate = sprite.modulate.lerp(Color.RED, red * 0.5)
	can_be_canceled = data.can_be_canceled
	hit_effect = data.hit_effect

	hitbox_shape = data.hitbox_shape
	hitbox_offset = data.hitbox_offset
	hitbox_radius = data.hitbox_radius
	hitbox_size = data.hitbox_size
	hitbox_rotation = data.hitbox_rotation

	velocity = direction.normalized() * data.velocity.length()
	self.rotation = direction.angle()

	if data.spawn_fog:
		sprite.visible = false  # 雾消失前隐藏子弹
		if fog.fog_finished.is_connected(_on_fog_ready):
			fog.fog_finished.disconnect(_on_fog_ready)
		fog.fog_finished.connect(_on_fog_ready, CONNECT_ONE_SHOT)
		fog.play(data.fog_texture, data.tint)
	else:
		fog.visible = false
		is_ready = true
		sprite.visible = true

	# 挂载移动协程：只有自定义脚本才走协程
	if data.coroutine_script:
		_start_coroutine(data)
	# 纯直线弹：只用 _physics_process
	
	# 确保可以移动
	process_mode = Node.PROCESS_MODE_INHERIT
	is_ready = true

func _on_fog_ready():
	sprite.visible = true  # 雾结束，显示子弹
	is_ready = true

func _physics_process(_delta):
	if not is_ready or coroutine_script:
		return
	self.global_position += velocity / Engine.physics_ticks_per_second

func _start_coroutine(data: BulletData):
	coroutine_script = data.coroutine_script.new()
	assert(coroutine_script is CoroutineScript, "Bullet: coroutine must be a CoroutineScript")
	add_child(coroutine_script)
	coroutine_script.start(StageContext.new(coroutine_script), self)

func batch_texture() -> Texture2D:
	return sprite.texture
