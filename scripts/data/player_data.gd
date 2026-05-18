extends Resource
class_name PlayerData

@export_group("Speed")
## 按住 Focus（低速）时的移动速度（像素/秒）
@export var focus_speed: int
## 常规移动速度（像素/秒）
@export var normal_speed: int

@export_group("Animation")
## 角色动画帧（AnimatedSprite2D 用 SpriteFrames）
@export var animation: SpriteFrames

@export_group("Weapon")
## 主武器（普通射击）
@export var main_weapon: WeaponData
## 子武器（子机/僚机，预留）
@export var option_weapon: WeaponData
