# CharacterProfile.gd
extends Resource
class_name CharacterProfile

## 角色名
@export var char_name: String = ""
## 表情集 { "通常": Texture2D, "笑": Texture2D, ... }
@export var portraits: Dictionary = {}
## 默认站位 0=左 1=右
@export var side: int = 0
