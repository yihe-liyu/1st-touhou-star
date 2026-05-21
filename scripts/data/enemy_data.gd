# EnemyData.gd
extends Resource
class_name EnemyData

@export var sprite_frames: SpriteFrames
@export var max_hp: int = 100
@export var hitbox_radius: float = 8.0
@export var score_value: int = 100
@export var death_effect: PackedScene
@export var create_script: Script
@export var move_script: Script
