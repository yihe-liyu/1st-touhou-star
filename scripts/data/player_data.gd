extends Resource
class_name PlayerData

@export_group("Speed")
## 按住 Focus（低速）时的移动速度（像素/秒）
@export var focus_speed: int
## 常规移动速度（像素/秒）
@export var normal_speed: int

@export_group("", "")
## 角色动画帧（AnimatedSprite2D 用 SpriteFrames）
@export var animation: SpriteFrames

## 射击脚本（PlayerShootScript）
@export var shoot_script: Script
