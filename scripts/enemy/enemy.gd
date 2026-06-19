# Enemy.gd
extends Area2D
class_name Enemy

## 敌人配置数据（生命、判定、弹幕模式等）
@export var enemy_data: EnemyData

var _visual: Node2D          # 外观实例（可能不是 AnimatedSprite2D）
var max_hp: int
var hitbox_radius: float
var score_value: int
var death_effect: PackedScene
var hp: int

var _create_script: CreateScript
var _ms: MoveScript
var move_script: MoveScript:
	get: return _ms
var _last_pos: Vector2


func _ready():
	z_index = LayerConfig.ENEMY
	z_as_relative = false
	if enemy_data: _apply_enemy_data(enemy_data)
	_last_pos = global_position
	
	GameState.active_enemies.append(self)
	if not tree_exited.is_connected(_on_tree_exited):
		tree_exited.connect(_on_tree_exited)


func _on_tree_exited():
	GameState.active_enemies.erase(self)


func _process(_delta: float) -> void:
	# 记录位置供子类或 visual_scene 使用
	_last_pos = global_position


func _apply_enemy_data(data: EnemyData):
	max_hp = data.max_hp
	hitbox_radius = data.hitbox_radius
	score_value = data.score_value
	death_effect = data.death_effect
	hp = max_hp
	
	# 外观：直接实例化 visual_scene
	if data.visual_scene:
		_visual = data.visual_scene.instantiate()
		add_child(_visual)
	
	# 碰撞形状
	var cs := $CollisionShape2D if has_node("CollisionShape2D") else CollisionShape2D.new()
	if not cs.get_parent():
		add_child(cs)
	if cs.shape is CircleShape2D:
		cs.shape.radius = hitbox_radius
	
	if data.create_script:
		_create_script = data.create_script.new()
		assert(_create_script is CreateScript, "Enemy: create_script must be a CreateScript")
		add_child(_create_script)
	
	if data.move_script:
		_ms = data.move_script.new()
		assert(_ms is MoveScript, "Enemy: move_script must be a MoveScript")
		add_child(_ms)


func start() -> void:
	if _create_script:
		var ctx := StageContext.new(_create_script)
		_create_script.start_creating(ctx)
	if _ms:
		var move_ctx := StageContext.new(_ms)
		_ms.start_moving(move_ctx, self)


func take_damage(damage: int):
	hp -= damage
	if hp <= 0: die()


func die():
	AudioManager.play_sfx(preload("res://assets/Sound/enemy_dead.wav"), -6.0)
	GameState.active_enemies.erase(self)
	
	# 掉落 item
	_drop_item()
	
	if death_effect:
		HitEffectPool.play(death_effect, global_position)
	
	GameEvents.enemy_killed.emit(score_value, global_position)
	
	if _create_script and is_instance_valid(_create_script):
		_create_script.stop()
	if _ms and is_instance_valid(_ms):
		_ms.stop()
	
	queue_free()

func _drop_item() -> void:
	if not enemy_data:
		return
	var pool := _find_item_pool()
	if not pool:
		return
	
	_spawn_items(pool, Item.Type.POWER, enemy_data.item_power)
	_spawn_items(pool, Item.Type.POINT, enemy_data.item_point)
	_spawn_items(pool, Item.Type.LIFE_FRAGMENT, enemy_data.item_life)
	_spawn_items(pool, Item.Type.BOMB_FRAGMENT, enemy_data.item_bomb)
	_spawn_items(pool, Item.Type.LIFE_FULL, enemy_data.item_life_full)
	_spawn_items(pool, Item.Type.BOMB_FULL, enemy_data.item_bomb_full)

func _spawn_items(pool: Node, type: int, count: int) -> void:
	for i in range(count):
		var offset := Vector2(
			RNG.randf_range(-enemy_data.item_scatter, enemy_data.item_scatter),
			RNG.randf_range(-enemy_data.item_scatter * 0.5, 0)
		)
		pool.spawn(global_position + offset, type)

func _find_item_pool() -> Node:
	var world := get_parent()
	if world:
		return world.get_node_or_null("ItemPool")
	return null
