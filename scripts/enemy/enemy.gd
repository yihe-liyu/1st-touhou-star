# Enemy.gd
extends Area2D
class_name Enemy

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## 敌人配置数据（生命、判定、弹幕模式等）
@export var enemy_data: EnemyData

var sprite_frames: SpriteFrames
var max_hp: int
var hitbox_radius: float
var score_value: int
var death_effect: PackedScene

var _create_script: CreateScript
var _move_script: MoveScript

var hp: int

func _ready():
	if enemy_data: _apply_enemy_data(enemy_data)
		
	GameState.active_enemies.append(self )
	if not tree_exited.is_connected(_on_tree_exited):
		tree_exited.connect(_on_tree_exited)

func _on_tree_exited():
	GameState.active_enemies.erase(self )

func _apply_enemy_data(data: EnemyData):
	sprite_frames = data.sprite_frames
	max_hp = data.max_hp
	hitbox_radius = data.hitbox_radius
	score_value = data.score_value
	death_effect = data.death_effect
	
	hp = max_hp
	
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = hitbox_radius
		
	if sprite_frames: animation.sprite_frames = sprite_frames
	animation.play("idle")

	if data.create_script:
		_create_script = data.create_script.new()
		add_child(_create_script)
		var api = StageAPI.new(_create_script)
		_create_script.start_creating(api)

	if data.move_script:
		_move_script = data.move_script.new()
		add_child(_move_script)
		var api = StageAPI.new(_move_script)
		_move_script.start_moving(api, self )

func take_damage(damage: int):
	hp -= damage
	if hp <= 0: die()

func die():
	GameState.active_enemies.erase(self )
	
	if death_effect:
		var effect = death_effect.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
	
	GameEvents.enemy_killed.emit(score_value, global_position)

	if _create_script and is_instance_valid(_create_script):
		_create_script.stop()
	if _move_script and is_instance_valid(_move_script):
		_move_script.stop()

	queue_free()
