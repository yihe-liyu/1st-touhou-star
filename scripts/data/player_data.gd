extends Resource
class_name PlayerData

@export_group("Speed")
@export var focus_speed: int
@export var normal_speed: int

@export_group("Animation")
@export var animation: SpriteFrames

@export_group("Weapon")
@export var main_weapon: WeaponData
@export var option_weapon: WeaponData
