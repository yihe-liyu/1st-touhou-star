# Enemy.gd
extends Area2D
class_name Enemy

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

@export var enemy_data: EnemyData

var sprite_frames: SpriteFrames
var max_hp: int
var hitbox_radius: float
var score_value: int
var death_effect: PackedScene

var shoot_pattern: ShootPattern

var hp: int

func _ready():
	if enemy_data: _apply_enemy_data(enemy_data)
		
	GameState.active_enemies.append(self)

func _apply_enemy_data(data: EnemyData):
	sprite_frames = data.sprite_frames
	max_hp = data.max_hp
	hitbox_radius = data.hitbox_radius
	score_value = data.score_value
	death_effect = data.death_effect
	
	hp = max_hp
	
	# 设置碰撞形状半径
	var shape = $CollisionShape2D.shape
	if shape is CircleShape2D: shape.radius = hitbox_radius
		
	if sprite_frames: animation.sprite_frames = sprite_frames
	animation.play("idle")

	if data.shoot_pattern:
		shoot_pattern = data.shoot_pattern.duplicate()
		shoot_pattern.bind(self)
	else:
		shoot_pattern = null

func take_damage(damage: int):
	hp -= damage
	if hp <= 0: die()

func die():
	GameState.active_enemies.erase(self)
	
	# 死亡特效
	if death_effect:
		var effect = death_effect.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
	
	# 通知全局（加分、音效等）
	GameEvents.enemy_killed.emit(score_value, global_position)
	
	queue_free()

func _physics_process(delta):
	if shoot_pattern: shoot_pattern.update(delta)
